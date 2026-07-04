/// 스탬프 발급 컨트롤러 — 상태머신 + 실패 분기 + 연타/중복 방지 (R3·R4·R5·R13·R14).
///
/// 순수 도메인([stamp_domain.dart])과 seam(위치 provider·repository)만 조합한다.
/// 실 Supabase·실기기 시계·플러그인 의존 없음 — 전부 provider override 로 주입 가능:
///  - `currentLocationProvider.overrideWith(...)` (위치 4분기)
///  - `stadiumRepositoryProvider` / `stampRepositoryProvider` / `gamesRepositoryProvider`
///  - `stampClockProvider.overrideWithValue(() => 기준시각)` (R13 KST 달력일)
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'location_provider.dart';
import 'stamp_domain.dart';
import 'stamp_models.dart';
import 'stamp_repository.dart';
import 'stadium_repository.dart';

part 'stamp_controller.g.dart';

/// 위치·네트워크 실패 원인 — 전부 "재시도 가능" 이지만 안내 문구가 다르다 (R5).
enum StampFailureReason {
  /// 기기 위치 서비스(GPS) 꺼짐.
  serviceDisabled,

  /// GPS fix 미획득(타임아웃).
  locationTimeout,

  /// 네트워크·서버 오류(구장/경기/스탬프 계층 어디서든).
  network,
}

/// 발급 상태머신 — UI 는 이 sealed 타입만 보고 화면을 그린다.
sealed class StampIssueState {
  const StampIssueState();

  /// 발급 진행 중이면 "도장 찍기" 버튼을 비활성화한다 (R14).
  /// 그 외(성공·실패·중복·유휴) 상태에서는 재활성화되어 다시 시도할 수 있다 (R5).
  bool get isBusy => this is StampIssuing;
}

/// 초기/유휴 — 아직 시도 없음.
class StampIdle extends StampIssueState {
  const StampIdle();
}

/// 발급 진행 중 — 위치 조회~insert 사이. 이 동안 재진입(연타)은 무시된다 (R14).
class StampIssuing extends StampIssueState {
  const StampIssuing();
}

/// 발급 성공 — 대상 칸 전부(또는 단일)에 도장이 찍혔다 (R1·R13).
class StampIssued extends StampIssueState {
  const StampIssued({required this.stamps, required this.slots});

  /// 새로 insert 된 스탬프(칸별 애니 재생 재료).
  final List<Stamp> stamps;

  /// 대상 칸(팀 컬러 도장용).
  final List<StampStadium> slots;
}

/// 부분 성공 — 잠실 복수 칸 중 일부만 성공. 성공 칸 애니는 재생, 실패 칸은 재시도 (R13).
class StampPartiallyIssued extends StampIssueState {
  const StampPartiallyIssued({
    required this.stamps,
    required this.issuedSlots,
    required this.failedSlots,
  });

  final List<Stamp> stamps;
  final List<StampStadium> issuedSlots;
  final List<StampStadium> failedSlots;
}

/// 중복 — 대상 칸이 이미 전부 발급됨. 선판정·UNIQUE 위반 양쪽이 여기로 수렴한다 (R3).
class StampDuplicated extends StampIssueState {
  const StampDuplicated();
}

/// 반경 밖 — 최근접 구장까지 남은 거리 안내 (R2). 저장은 발생하지 않는다.
class StampOutOfRangeState extends StampIssueState {
  const StampOutOfRangeState({required this.nearest});

  final NearestStadium nearest;

  /// "구장까지 N.Nkm".
  String get message => '구장까지 ${nearest.distanceText}';
}

/// 위치 권한 거부 — 설정 유도 안내 (R4). 예외를 던지지 않는다(crash 없음).
class StampPermissionRequired extends StampIssueState {
  const StampPermissionRequired({required this.permanently});

  /// true 면 앱 재요청 불가 → 설정 앱으로 유도.
  final bool permanently;

  String get message => '위치 권한이 필요해요. 설정에서 위치 접근을 허용해 주세요.';
}

/// 위치 서비스 꺼짐·타임아웃·네트워크 오류 — 원인 안내 + 재시도 가능 (R5).
class StampFailed extends StampIssueState {
  const StampFailed({required this.reason});

  final StampFailureReason reason;

  String get message => switch (reason) {
        StampFailureReason.serviceDisabled =>
          '위치 서비스가 꺼져 있어요. 켜고 다시 시도해 주세요.',
        StampFailureReason.locationTimeout =>
          '위치를 확인하지 못했어요. 다시 시도해 주세요.',
        StampFailureReason.network =>
          '네트워크 오류로 발급하지 못했어요. 다시 시도해 주세요.',
      };
}

/// 기준 시각 seam — R13 잠실 칸 배정의 KST 달력일 계산에 쓴다.
/// 테스트에서 `stampClockProvider.overrideWithValue(() => 고정시각)` 로 주입한다.
@riverpod
DateTime Function() stampClock(Ref ref) => DateTime.now;

/// 발급 컨트롤러.
@riverpod
class StampController extends _$StampController {
  @override
  StampIssueState build() => const StampIdle();

  /// "도장 찍기" — 위치 1회 조회 → 근접 판정 → (잠실이면) 칸 배정 → insert.
  ///
  /// R14: 진행 중 재진입(연타)은 즉시 무시 → 저장 호출이 대상 칸 수를 넘지 않는다.
  Future<void> issue() async {
    // 연타 방지 (R14): 첫 await 이전에 동기적으로 진행 중 상태를 세워
    // 같은 시도 안의 재호출을 걸러낸다.
    if (state is StampIssuing) return;
    state = const StampIssuing();

    // 1. 위치 1회 조회 (포그라운드 온리, 발급 순간). 매 시도 fresh fix.
    final LocationResult location;
    try {
      location = await ref.refresh(currentLocationProvider.future);
    } catch (_) {
      state = const StampFailed(reason: StampFailureReason.network);
      return;
    }

    final double lat;
    final double lng;
    switch (location) {
      case LocationPermissionDenied(:final permanently):
        state = StampPermissionRequired(permanently: permanently);
        return;
      case LocationServiceDisabled():
        state = const StampFailed(reason: StampFailureReason.serviceDisabled);
        return;
      case LocationTimeout():
        state = const StampFailed(reason: StampFailureReason.locationTimeout);
        return;
      case LocationAcquired(lat: final la, lng: final ln):
        lat = la;
        lng = ln;
    }

    // 2. 구장 목록 로드.
    final List<StampStadium> stadiums;
    try {
      stadiums = await ref.read(stadiumRepositoryProvider).listStadiums();
    } catch (_) {
      state = const StampFailed(reason: StampFailureReason.network);
      return;
    }
    if (stadiums.isEmpty) {
      state = const StampFailed(reason: StampFailureReason.network);
      return;
    }

    // 3. 근접 판정 (순수). 반경 밖이면 거리 안내로 종료.
    final proximity =
        evaluateStampProximity(stadiums: stadiums, lat: lat, lng: lng);
    final List<StampStadium> inRadius;
    switch (proximity) {
      case StampOutOfRange(:final nearest):
        state = StampOutOfRangeState(nearest: nearest);
        return;
      case StampInRange(:final stadiumsInRadius):
        inRadius = stadiumsInRadius;
    }

    // 4. 잠실이면(두 칸 함께 반경 내) 당일 경기로 칸을 좁힌다 (R13).
    var gameAbbrs = <String>{};
    final isJamsil =
        inRadius.map((s) => s.teamAbbr).toSet().containsAll(kJamsilSlotAbbrs);
    if (isJamsil) {
      // 크롤러가 "잠실야구장" 정식명 행으로 매핑하므로 그 행 id 로 경기를 조회한다.
      final canonical = inRadius.firstWhere(
        (s) => s.name == kJamsilCanonicalName,
        orElse: () => inRadius.first,
      );
      try {
        gameAbbrs = await ref.read(gamesRepositoryProvider).teamAbbrsInGamesOn(
              stadiumId: canonical.id,
              kstDay: kstDayOf(ref.read(stampClockProvider)()),
            );
      } catch (_) {
        state = const StampFailed(reason: StampFailureReason.network);
        return;
      }
    }
    final targets = resolveTargetSlots(
      stadiumsInRadius: inRadius,
      jamsilGameTeamAbbrs: gameAbbrs,
    );

    // 5. 선판정: 이미 찍힌 칸은 건너뛴다 (R3·R13).
    final repository = ref.read(stampRepositoryProvider);
    final List<Stamp> existing;
    try {
      existing = await repository.myStamps();
    } catch (_) {
      state = const StampFailed(reason: StampFailureReason.network);
      return;
    }
    final stampedIds = existing.map((s) => s.stadiumId).toSet();
    final toIssue =
        targets.where((s) => !stampedIds.contains(s.id)).toList();
    if (toIssue.isEmpty) {
      // 대상 칸 전부 기발급 → 중복 안내 (선판정 경로) (R3).
      state = const StampDuplicated();
      return;
    }

    // 6. insert — 대상 칸별 1회. 부분 실패는 성공/실패로 분리 (R13·R14).
    final issued = <Stamp>[];
    final issuedSlots = <StampStadium>[];
    final failedSlots = <StampStadium>[];
    for (final slot in toIssue) {
      try {
        final stamp = await repository.insertStamp(
          stadiumId: slot.id,
          lat: lat,
          lng: lng,
        );
        issued.add(stamp);
        issuedSlots.add(slot);
      } on DuplicateStampException {
        // UNIQUE 위반 = 그 칸은 이미 찍혀 있음 → 건너뛴다 (재시도 자연 수렴) (R3).
        // 성공도 실패도 아니게 흡수: 남은 칸 성공이 있으면 성공, 없으면 중복 안내로 수렴.
      } on StampNetworkException {
        failedSlots.add(slot);
      }
    }

    // 7. 결과 수렴.
    if (issued.isEmpty) {
      // 성공 0: 전부 실패거나 전부 중복.
      state = failedSlots.isNotEmpty
          ? const StampFailed(reason: StampFailureReason.network)
          : const StampDuplicated();
      return;
    }
    if (failedSlots.isNotEmpty) {
      state = StampPartiallyIssued(
        stamps: issued,
        issuedSlots: issuedSlots,
        failedSlots: failedSlots,
      );
      return;
    }
    // 성공(중복 건너뛴 칸은 재발급 없이 성공으로 흡수).
    state = StampIssued(stamps: issued, slots: issuedSlots);
  }
}
