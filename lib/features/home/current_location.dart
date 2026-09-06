/// 홈 상단 현재 위치 표시 (step 5.2).
///
/// **기본은 새 측위도, 새 권한 조회도 만들지 않는 것.** `lib/location/CLAUDE.md`
/// 가 5.2 에 남긴 지침대로, 위치 권한 상태와 측위 경로는 4.1 이 이미 세운
/// 것을 그대로 쓴다 — 이 파일이 기본으로 읽는 신호는
/// `lib/features/badges/stadium_visit.dart` 의 [stadiumVisitProvider] 다.
/// 그 provider 는 앱을 열 때·포그라운드로 돌아올 때 이미
/// [StadiumVisitTrigger] 가 돌리고 있고, 판정 자체가 "판정할 후보가 없으면
/// 권한도 좌표도 묻지 않는다"([judgeStadiumVisit] 문서 참조)는 계약으로 이미
/// 위치 I/O 를 최소화해 두었다.
///
/// **판정이 권한을 대신 말해 주지 못하는 두 갈래에서만 예외를 둔다.**
/// [judgeStadiumVisit] 이 후보 게이트를 권한보다 먼저 보므로, 오늘(KST) 그
/// 어느 구장에도 경기가 없는 날은 권한을 아예 묻지 않은 채 `noGameToday` 로
/// 끝난다 — KBO 정규 시즌의 월요일과 비시즌 전체가 그 날이다. 그리고 콘텐츠
/// 문서를 못 얻은 실행에서는 [StadiumVisitCheck.run] 이 판정을 아예 돌리지
/// 못해 결과가 null 로 남는다(통합 검증 탐침 E 가 잰 자리). 그 둘을
/// [StadiumVisitReason.permissionMissing] 과 같이 접으면, **권한을 허용한
/// 사람이 월요일·비시즌에, 또는 콘텐츠를 못 받은 날에 홈을 열 때도 위치
/// 자리가 통째로 사라져 acceptance 첫 문장("권한이 있으면 현재 위치가 상단에
/// 뜬다")을 어긴다** — 그 화면이 권한을 거부한 사람의 화면과 구분되지 않는다.
/// 그래서 [currentLocationPermissionProvider] 가 그 둘에서만
/// [LocationPermissionGateway.status] 를 다시 물어 "권한이 있는가"를
/// 알아낸다. **[LocationPermissionGateway.request] 는 절대 부르지 않는다** —
/// 새 OS 다이얼로그를 띄우는 것은 이 화면의 일이 아니다(그 진입점은 이미
/// 배지 탭의 `VisitStatusNotice` 에 있다).
///
/// **판정을 "지금"으로 읽어도 되는지는 따로 잰다.** 4.2 는 새 도장이 나올 수
/// 없는 구간에서 측위를 건너뛰므로([StampAward.judgingAddsNothing]), 손에 든
/// 판정은 몇 시간 전 것일 수 있다. 그래서 이 파일은 판정 결과와 함께
/// [stadiumVisitRunProvider] 의 기록(마지막 시도가 언제였고 판정까지 갔는지)을
/// 읽어 [kCurrentLocationFreshness] 안의 판정만 구장 이름으로 쓴다. 그 밖은
/// 자리를 접는 대신 [kCurrentLocationGenericLabel] 로 내려간다 — 모르는 것을
/// 아는 척하지 않으면서, 권한이 있는 사람의 화면은 그대로 남긴다.
///
/// **왜 이 재조회가 4.1 이 세운 절제를 깨지 않는가.** `lib/features/badges/visit_status_notice.dart`
/// 의 `_permissionMissingStatusProvider` 가 이미 같은 일을 한다 — 그 파일
/// 머리말이 `lib/location/CLAUDE.md` 를 인용해 "다시 물을 수 있는지를 갈라야
/// 하는 자리는 그때 `status()` 를 그 자리에서 물으면 된다"고 근거를 적어
/// 두었다. 이 provider 도 [FutureProvider.autoDispose] 라 아무도 구독하지
/// 않는 동안(그 밖의 다섯 갈래 — 시즌 중 대부분의 날)은 인스턴스화조차 되지
/// 않는다.
///
/// **실측으로 확인한 대가 — 처음 시도와 다른 자리.** 처음에는
/// [LocationPermissionGateway.status] 를 홈이 **모든 갈래에서 매 빌드마다**
/// 새로 묻는 자리를 만들었는데, 그러면 위치 게이트웨이를 override 하지 않는
/// 전체 앱 부팅 시험들(`test/phase2_journey_probe_test.dart` 등)이 실 플랫폼
/// 채널을 만지며 타이머가 위젯 트리 해제 뒤까지 남아 깨졌다(전체 스위트에서
/// 23개 파일·33개 시험이 함께 흔들렸다, `.wellbegun/decisions.md` 2026-09-06
/// 참조). 지금 이 갈래는 그와 다르다 — 재조회가 서는 것은 `noGameToday`
/// 판정을 받은 빌드뿐이고, 그 값을 실제로 만드는 것은 `stadiumVisitProvider`
/// 를 직접 돌리는 실행(`StadiumVisitTrigger` 를 씌운 화면)뿐이다. 저장소를
/// 훑어 그 조건을 만드는 시험들을 모두 확인했다 — `stadiumVisitProvider`
/// 를 고정값으로 갈아 끼우거나(`_FixedStadiumVisitCheck` 류) `scheduleProvider`
/// 를 못 얻은 것으로 두어 `StadiumVisitCheck.run` 이 일찍 반환하는 시험은 이
/// 갈래에 닿지 않고, 실제로 `noGameToday` 를 만드는 시험(`test/phase3_seam_audit_probe_test.dart`
/// 등)은 스케줄 문서 자체를 못 얻은 것으로 두어 판정이 아예 돌지 않거나
/// [stadiumVisitCheckerProvider] 를 통째로 갈아 껴 권한 게이트웨이를 거치지
/// 않는다. `test/features/home/home_screen_test.dart` 는 [stadiumVisit] 을
/// 직접 주입해 `noGameToday` 를 실제로 만드므로, 그 파일에는
/// [locationPermissionGatewayProvider] override 를 새로 더했다.
///
/// **표기 형태는 "구장 근접 표시"를 고른다** (plan.md step 5.2 discretion).
/// [StadiumVisitResult] 는 방문이 확정된 갈래에만 구장 id 를 담으므로
/// (`lib/location/visit_check.dart` 겹 5), 이 계층이 아는 "지금 위치"는
/// "어느 구장 근처에 있는가, 아니면 모른다" 둘뿐이다. "구·동 단위" 표기
/// (역지오코딩)는 `lib/location/` 의 허용 import 목록에 없는 외부 지도
/// 서비스를 새로 들여야 해서 고르지 않았다. `noGameToday` + 권한 있음
/// 갈래에서도 구장을 특정할 수 없으므로 [kCurrentLocationGenericLabel] 이
/// 뜬다 — `outsideRadius` 등 다른 세 이유와 같은 문구다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/models.dart';
import '../../location/location.dart';
import '../../location/visit_check.dart';

/// 판정이 권한을 말해 주지 못하는 갈래에서만 권한 상태를 다시 묻는 자리
/// ([currentLocationNeedsPermissionAnswer] 가 그 갈래를 가른다) — 위 문서의
/// "왜 이 재조회가 4.1 이 세운 절제를 깨지 않는가" 참조.
/// [resolveLocationPermission] 을 그대로 통과시켜 실패 계약(상한 안에 반드시
/// 답한다)을 새로 만들지 않는다.
final currentLocationPermissionProvider =
    FutureProvider.autoDispose<LocationPermissionStatus>(
      (ref) => resolveLocationPermission(
        () => ref.read(locationPermissionGatewayProvider).status(),
      ),
    );

/// 판정 하나가 **"지금 위치"로 통하는 시간** (plan.md step 5.2 의 discretion
/// "갱신 주기").
///
/// 이 앱은 판정을 앱을 열 때와 포그라운드로 돌아올 때만 돌리고, 도장을 이미
/// 받은 뒤에는 시간 창이 닫힐 때까지 그마저 건너뛴다(4.2 의 절제). 그래서
/// 손에 든 판정은 **얼마든지 오래된 것일 수 있고**, 그것을 그대로 "현재
/// 위치"라고 말하면 사람이 이미 떠난 구장을 홈이 계속 가리킨다(phase 5 통합
/// 검증의 REJECT 사유). 재량은 "얼마나 자주 갱신할지"를 고르는 것이지 앱이
/// 모르는 것을 아는 척하는 것까지 덮지 않으므로, 이 길이를 넘긴 판정은
/// 구장을 특정하는 문구로 쓰지 않고 [kCurrentLocationGenericLabel] 로
/// 내려간다.
///
/// 15분으로 잡은 것은 두 대가 사이의 자리다: 너무 짧으면 구장에 서 있는
/// 사람의 문구가 잠깐 사이에 내려가고, 너무 길면 경기가 끝나고 나온 사람이
/// 한참 동안 틀린 문구를 본다. 도장을 받은 뒤에는 게이트가 닫혀 있어 이
/// 길이가 지나면 그 구장 문구가 내려가는데, 그 사람에게는 판에 찍힌 도장이
/// 이미 남아 있으므로 잃는 것이 없다.
const Duration kCurrentLocationFreshness = Duration(minutes: 15);

/// 구장을 특정하지 못하는 모든 갈래의 문구.
///
/// **이 문구는 앱이 한 일을 말하지 않는다.** 예전 문구("현재 위치를 사용하고
/// 있어요")는 [StadiumVisitReason.noGameToday] 갈래(월요일·비시즌 전체)에도
/// 떴는데, 그 갈래는 [judgeStadiumVisit] 이 권한도 좌표도 묻기 전에 끝내는
/// 자리라 앱이 위치를 **쓴 적이 없다**. 개인정보 결정을 어기는 것은 아니지만
/// 하지 않은 일을 했다고 말하는 문구였다(phase 5 통합 검증의 계약 밖 발견).
/// 검사를 넓히는 대신 문구를 사실에 맞게 좁힌다 — 이 문구가 뜨는 네 자리
/// (측위했지만 구장이 아님 · 좌표를 못 얻음 · 판정할 후보가 없었음 · 판정이
/// 오래됨) 어디에서도 참인 문장 하나다.
const String kCurrentLocationGenericLabel = '구장 근처에 있으면 여기에 표시돼요';

/// 홈 상단 위치 자리를 그릴지.
///
/// 자리를 접는 것은 **권한이 없다는 것을 아는 실행**뿐이다
/// ([StadiumVisitReason.permissionMissing], 또는 권한을 다시 물어 `denied`·
/// `permanentlyDenied` 를 받은 실행). 그 밖에는 권한이 있는 사람의 화면이
/// 권한을 거부한 사람의 화면과 구분되지 않으면 안 된다(acceptance 첫 문장).
///
/// 갈래별 근거:
/// - **[visit] 이 null** — 판정이 아직 없거나(첫 프레임) 콘텐츠 문서를 못
///   얻어 판정이 아예 돌지 못한 실행이다([StadiumVisitCheck.run]). 뒤엣것은
///   권한이 있어도 자리가 통째로 접히던 자리라(통합 검증 탐침 E), 트리거가
///   한 번이라도 돌았으면([judgmentAttempted]) 권한을 따로 물어 가른다.
/// - **[StadiumVisitReason.permissionMissing]** — 권한이 없어 판정을
///   시도하지 않은 갈래다. 접는다.
/// - **[StadiumVisitReason.noGameToday]** — 판정할 후보가 없어
///   [judgeStadiumVisit] 이 권한조차 묻지 않은 갈래라, 이 함수 혼자서는
///   권한을 알 수 없다. 그 답을 [askedPermission] 으로 밖에서 받는다.
/// - **나머지 넷** — [StadiumVisitChecker.check] 가 권한을
///   [LocationPermissionStatus.granted] 로 이미 확인한 뒤에만 나오는
///   갈래라 권한이 있다는 뜻이고, [askedPermission] 은 쓰이지 않는다.
///
/// [askedPermission] 이 아직 null 이면(조회가 로딩 중) 접는다 — "권한이 없는
/// 사람과 구분되지 않는다"는 위반을 반대 방향(아직 모르는데 그린다)으로
/// 되풀이하지 않기 위해서다.
bool currentLocationVisible(
  StadiumVisitResult? visit, {
  bool judgmentAttempted = false,
  LocationPermissionStatus? askedPermission,
}) {
  if (visit == null) {
    return judgmentAttempted &&
        askedPermission == LocationPermissionStatus.granted;
  }
  return switch (visit.reason) {
    StadiumVisitReason.permissionMissing => false,
    StadiumVisitReason.noGameToday =>
      askedPermission == LocationPermissionStatus.granted,
    StadiumVisitReason.visited ||
    StadiumVisitReason.locationUnavailable ||
    StadiumVisitReason.outsideRadius ||
    StadiumVisitReason.outsideTimeWindow => true,
  };
}

/// 권한을 따로 물어야 답할 수 있는 갈래인가 — 부르는 쪽이 이 물음이 참일
/// 때만 [LocationPermissionGateway.status] 조회를 구독한다.
///
/// 이 갈래를 좁게 두는 데는 실측 근거가 있다(파일 첫머리 참조): 홈이 모든
/// 빌드에서 권한을 새로 묻던 첫 판은 위치 게이트웨이를 override 하지 않는
/// 부팅 시험들을 무더기로 깨뜨렸다.
bool currentLocationNeedsPermissionAnswer(
  StadiumVisitResult? visit, {
  required bool judgmentAttempted,
}) {
  if (visit == null) return judgmentAttempted;
  return visit.reason == StadiumVisitReason.noGameToday;
}

/// 손에 든 판정을 **"지금"** 이라고 말해도 되는가.
///
/// [judgedAt] 은 마지막 판정 시도가 **실제로 판정까지 갔을 때**의 그 시각이다
/// (`stadiumVisitRunProvider` 의 `judged` 가 거짓인 실행 뒤에는 null 을
/// 넘긴다 — 그 실행 이후로 앱은 사람이 어디 있는지 알지 못한다).
///
/// [now] 가 [judgedAt] 보다 앞서는 실행(기기 시계가 뒤로 뛴 경우)도 참으로
/// 보지 않는다 — 잴 수 없는 나이는 "모른다" 쪽으로 접는다.
bool currentLocationIsFresh({
  required DateTime? judgedAt,
  required DateTime now,
}) {
  if (judgedAt == null) return false;
  final age = now.difference(judgedAt);
  return !age.isNegative && age <= kCurrentLocationFreshness;
}

/// 홈 상단에 보일 문구 — [visit] 이 방문을 확정했고 그 판정이 아직
/// [fresh] 하면 그 구장 이름, 아니면 [kCurrentLocationGenericLabel].
///
/// **[fresh] 가 거짓이면 구장 이름을 쓰지 않는다.** 그 값은 4.2 의 재판정
/// 게이트가 닫혀 있는 동안(도장을 받은 뒤 시간 창이 닫힐 때까지) 사람이
/// 구장을 떠나도 판정이 갱신되지 않는다는 사실에서 온다 — 그때 이 자리가
/// 옛 구장 이름을 계속 세워 두는 것이 phase 5 통합 검증의 REJECT 사유였다.
/// 고치는 방향은 측위를 다시 켜는 쪽이 아니라(4.1·4.2 의 절제를 되돌리게
/// 된다) **모르면 모른다고 말하는 쪽**이다.
///
/// [currentLocationVisible] 이 false 인 [visit] 으로 불러도 던지지 않고
/// 일반 문구를 돌려준다(부르는 쪽이 항상 먼저 가시성을 본다는 계약에
/// 기대지 않기 위한 방어).
///
/// [stadiums] 문서를 못 얻었거나 그 안에 없는 구장 id 면(계약이 어긋난
/// 실행) 이름 대신 id 를 그대로 보여준다 — 홈의 다른 자리
/// (`_matchLabel`·`_RecentGameRow`)가 이미 쓰는 것과 같은 저하 규칙이다.
String currentLocationLabel({
  required StadiumVisitResult? visit,
  required StadiumsDocument? stadiums,
  bool fresh = false,
}) {
  final stadiumId = visit?.stadiumId;
  if (visit == null || !visit.isVisit || stadiumId == null || !fresh) {
    return kCurrentLocationGenericLabel;
  }
  final name = stadiums?.byId(stadiumId)?.name ?? stadiumId;
  return '$name 근처예요';
}
