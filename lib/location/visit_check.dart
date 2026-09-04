/// 구장 방문 판정 (step 4.1) — **좌표가 사는 유일한 자리.**
///
/// `.wellbegun/decisions.md` 2026-09-01 `[L]` 이 정한 판정을 그대로 실현한다:
/// 앱이 열려 있을 때만 하는 포그라운드 판정이고, (1) 그 구장에 그날 경기가
/// 있고 (2) 기기 위치가 구장 좌표 반경 안이며 (3) 경기 시각 기준 시간 창 안일
/// 때 도장이다. 홈·원정은 구분하지 않는다 — 후보([StadiumVisitCandidate])에
/// 팀 id 가 아예 없는 것이 그 계약이다.
///
/// ## 좌표가 서버로 나갈 길이 없다는 것을 무엇이 지키는가
///
/// XL 결정("기기가 어디에 있었는지는 서버로 올리지 않는다")은 훅 하나로
/// 지킬 수 있는 종류가 아니라서, 이 파일의 **구조**가 세 겹으로 막는다.
///
/// 1. **좌표를 얻는 유일한 통로가 이 라이브러리 안에서만 보인다.**
///    기기의 좌표를 실제로 읽는 자리는 아래 [_readDeviceFix] 하나이고 이름이
///    `_` 로 시작해 다른 라이브러리에서 부를 수 없다. 그 통로를 들고 도는
///    [StadiumVisitChecker] 도 그것을 **private 필드**로만 쥔다 — 생성자로
///    넣을 수는 있어도(시험이 갈아 끼우는 이음매) 밖에서 다시 꺼내 부를 수는
///    없어서, `stadiumVisitCheckerProvider` 를 읽은 쪽이 손에 넣는 것은
///    "판정을 한 번 돌린다"는 능력뿐이다. 그 밖의 통로는 위치
///    플러그인(`package:geolocator`) 직접 호출뿐인데 그 import 는
///    `scripts/hooks/check-firebase-import-boundary.sh` 가 이 **파일**로
///    못 박는다. 그래서 `lib/features/`·`lib/backend/` 어디에서도 기기의
///    좌표를 손에 넣을 방법이 없다. (이 필드가 public 이던 동안에는 어느
///    feature 든 `ref.read(stadiumVisitCheckerProvider).readFix()` 로 실제
///    좌표를 얻을 수 있었고 훅 넷과 `flutter analyze` 가 전부 초록불이었다 —
///    `.wellbegun/decisions.md` 2026-09-04 `[M]`.)
/// 2. **이 계층은 업로드 계층에 닿지 않는다.** `lib/location/` 은
///    `lib/backend/` 를 import 하지 않고(`check-no-location-upload.sh`),
///    그래서 이 파일 안에서 좌표를 가지고 있어도 보낼 곳이 없다.
/// 3. **경계를 넘는 값에 좌표가 없다.** 이 파일이 밖으로 내보내는 판정 결과
///    [StadiumVisitResult] 는 이유·구장 id·경기 id 세 가지뿐이고, 그 **필드
///    집합 자체**를 `test/features/badges/visit_check_test.dart` 의 파수꾼이
///    이 파일의 소스를 읽어 표와 대조한다(`test/cross_layer_seams_test.dart`
///    가 `firestore.rules` 를 읽어 대조하는 것과 같은 방식이다) — 그 타입에
///    좌표 필드를 하나 더하면 빨간불이다. [DeviceFix]
///    는 타입 자체는 공개(시험이 판정 함수에 좌표를 넣어야 한다)지만, 위 1번
///    때문에 **실제 기기 좌표가 담긴 값**은 이 라이브러리 밖으로 나가지
///    않는다. 어디에도 적지 않는다 — 캐시·`shared_preferences`·로그 어느
///    쪽으로도 흐르지 않고, 판정이 끝나면 그대로 버려진다.
///
/// ## 계층
///
/// 순수 판정([judgeStadiumVisit])과 좌표를 읽는 자리([StadiumVisitChecker])를
/// 나눠 두었다. 앞엣것은 좌표 in / 결과 out 인 순수 함수라 다섯 갈래를 전부
/// 값으로 잴 수 있고, 뒤엣것은 "언제 OS 에 물을 것인가"만 정한다 — 권한이
/// 없거나 판정할 후보가 없으면 **좌표를 아예 읽지 않는다**(계약의 "판정을
/// 시도하지 않는다").
///
/// 경기 일정·구장 좌표를 이 계층의 후보 목록으로 옮기는 자리는 부르는
/// 쪽(`lib/features/badges/stadium_visit.dart`)이다 — `lib/location/` 이
/// 콘텐츠 문서의 모양까지 알 이유가 없고, 백엔드로 넘길 결과가 있으면 두
/// 계층을 잇는 자리는 feature 라는 `lib/location/CLAUDE.md` 의 규칙과 같은
/// 방향이다.
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;

import '../content/kst.dart';
import 'location.dart';

/// 구장 좌표에서 이만큼 안이면 "그 구장에 있다"로 본다.
///
/// **초기값이고 실측으로 조정할 값이다** (`plan.md` step 4.1 의 discretion).
/// 300m 로 잡은 근거는 세 가지다. (1) KBO 9개 구장의 구조물 반경이 110~150m
/// 라 구장과 그 바로 바깥의 광장·주차장까지 덮는다. (2) 관중석은 콘크리트
/// 그릇 안이라 위성 신호가 반사되어 오차가 커지는데, 그 오차를 삼킬 여유가
/// 필요하다. (3) 그런데도 더 넓히지 않는 것은 이 판정에 자기 신고가 없어서
/// **구장 근처에 사는 사람**이 경기일에 앱을 열기만 해도 도장을 받는 쪽이
/// 유일한 오탐 경로이기 때문이다 — 반경을 키우면 그 오탐이 정비례로 는다.
/// 실제 구장에서 재 보고 "안에 있는데 못 받는" 쪽이 나오면 키운다.
const double kStadiumVisitRadiusMeters = 300;

/// 경기 시작 **전** 이만큼부터 판정을 받는다.
///
/// 초기값. 게이트 오픈이 보통 경기 2시간 전이고 원정 팬은 그보다 일찍 도착해
/// 구장 앞에서 시간을 보내므로 3시간으로 잡았다.
const Duration kVisitWindowBeforeStart = Duration(hours: 3);

/// 경기 시작 **후** 이만큼까지 판정을 받는다.
///
/// 초기값. KBO 경기는 평균 3시간 20분 안팎이고 경기 뒤 구장에 남아 있는
/// 시간까지 덮으려면 그보다 넉넉해야 해서 5시간으로 잡았다. 창을 더 넓히면
/// [kStadiumVisitRadiusMeters] 주석이 적은 오탐 경로가 그만큼 길어진다.
const Duration kVisitWindowAfterStart = Duration(hours: 5);

/// 위성 측위를 기다리는 상한.
///
/// `lib/location/CLAUDE.md` 의 "기다림에는 상한이 있다"를 이 자리에서도
/// 지킨다. 다만 길이는 저장소의 다른 네 상한(5초)보다 길다 — 그 넷은 **사람이
/// 보는 화면**을 붙잡고 있어서 넘으면 나갈 길이 없지만, 이 기다림은 아무
/// 화면도 붙잡지 않는다(판정은 배경에서 한 번 돌고, 못 얻으면
/// [StadiumVisitReason.locationUnavailable] 로 조용히 끝난 뒤 다음 트리거에서
/// 다시 시도한다). 반면 콜드 스타트의 첫 측위는 5초를 넘기는 일이 흔해서,
/// 5초로 맞추면 "구장에 있는데 좌표를 못 얻어 도장이 없다"가 일상이 된다.
const Duration kLocationFixTimeout = Duration(seconds: 10);

/// 판정에 넣을 기기의 한 지점.
///
/// 이 타입의 값이 담긴 채로 이 라이브러리를 벗어나는 경로는 없다 — 파일 첫
/// 문단의 세 겹 참조. 타입 자체가 공개인 것은 순수 판정 함수에 좌표를 넣어
/// 다섯 갈래를 재는 시험 때문이다.
class DeviceFix {
  const DeviceFix({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

/// 판정 후보 한 건 — "그날 그 구장에 있는 경기" 하나와 그 구장의 좌표.
///
/// **팀 id 가 없다.** 홈·원정을 구분하지 않는다는 계약이 타입에 그대로 박혀
/// 있어서, 뒤에 누가 "내 팀 경기일 때만"을 넣으려면 이 타입을 고쳐야 한다.
class StadiumVisitCandidate {
  const StadiumVisitCandidate({
    required this.gameId,
    required this.stadiumId,
    required this.startsAt,
    required this.lat,
    required this.lng,
  });

  /// schedule.json 의 경기 id — 4.2 의 도장 문서 id 절반이다.
  final String gameId;

  /// common.defs stadiumId — 4.2 가 칸을 가르는 값이다.
  final String stadiumId;

  /// 경기 시작의 **절대 시각** (`gameStartsAt` 이 KST 계약에서 옮긴 값).
  final DateTime startsAt;

  final double lat;
  final double lng;
}

/// 판정이 끝난 이유 — 방문 하나와 방문이 아닌 다섯 갈래.
enum StadiumVisitReason {
  /// 세 조건이 전부 맞았다.
  visited,

  /// 위치 권한이 없어 **판정을 시도하지 않았다.**
  ///
  /// 2.5 의 세 갈래 중 `granted` 가 아닌 둘(`denied`·`permanentlyDenied`)을
  /// 하나로 접는다 — 이 계층이 그 둘로 다르게 할 일이 없기 때문이다. 다시
  /// 물을 수 있는지를 갈라야 하는 자리(재요청 진입점)는 그때
  /// `LocationPermissionGateway.status()` 를 그 자리에서 물으면 된다.
  permissionMissing,

  /// 지금 판정할 경기가 없었다 — 좌표를 읽지 않았다.
  ///
  /// 오늘(KST) 열리는 경기도, 시간 창이 지금을 덮는 경기도 없다는 뜻이다
  /// ([candidatesToJudge]). 자정을 갓 넘긴 시각에 어젯밤 경기의 창이 아직
  /// 열려 있으면 이 이유가 아니다 — 창이 달력 날짜에 잘리지 않는다.
  noGameToday,

  /// 경기는 있었지만 좌표를 얻지 못했다 (측위 실패·상한 초과·위치 서비스 꺼짐).
  locationUnavailable,

  /// 그날 경기가 있는 어느 구장에서도 반경 밖이었다.
  outsideRadius,

  /// 반경 안이었지만 그 구장 경기의 시간 창 밖이었다.
  outsideTimeWindow,
}

/// 판정 결과 — **좌표를 담지 않는다.**
///
/// 방문일 때 [stadiumId]·[gameId] 를 함께 내는 것은 4.2 가 칸을 가르기
/// 위해서다(잠실은 홈팀에 따라 칸이 둘로 갈린다 — 그 경기의 홈팀은 [gameId]
/// 로 일정에서 다시 찾는다). 방문이 아니면 둘 다 null 이다.
class StadiumVisitResult {
  const StadiumVisitResult.visited({
    required String this.stadiumId,
    required String this.gameId,
  }) : reason = StadiumVisitReason.visited;

  const StadiumVisitResult.rejected(this.reason)
    : stadiumId = null,
      gameId = null,
      assert(
        reason != StadiumVisitReason.visited,
        '방문은 구장·경기와 함께 나온다 — StadiumVisitResult.visited 를 쓴다',
      );

  final StadiumVisitReason reason;
  final String? stadiumId;
  final String? gameId;

  bool get isVisit => reason == StadiumVisitReason.visited;

  @override
  String toString() => isVisit
      ? 'StadiumVisitResult(visited, $stadiumId, $gameId)'
      : 'StadiumVisitResult(${reason.name})';
}

/// [candidates] 중 **지금 판정에 넣을** 후보들 — 오늘(KST) 열리는 경기이거나,
/// 시간 창이 [now] 를 덮는 경기.
///
/// 계약의 첫 조건("그 구장에 그날 경기가 있고")을 재는 자리이자,
/// [StadiumVisitChecker] 가 "좌표를 물을 이유가 있는가"를 정하는 자리다.
///
/// **왜 팔이 둘인가.** `[L]` 결정의 세 번째 조건은 **경기 시각 기준** 창이지
/// 달력 날짜가 아니다. 날짜로만 거르면 창의 뒤끝이 KST 자정에서 잘려서,
/// 20:00 경기의 창(다음 날 01:00 까지) 안에 서 있는 사람이 자정을 넘긴 뒤
/// [StadiumVisitReason.noGameToday] 를 받는다 — 늦은 시작·연장·더블헤더
/// 2차전이 그 자리이고, 이유까지 틀리면 4.5("못 받는 날")나 뒤에 설 권한
/// 재요청 진입점이 "그날 경기가 없었다"로 잘못 읽는다. 반대로 창으로만
/// 거르면 [StadiumVisitReason.outsideTimeWindow] 가 영영 설 수 없다(그날
/// 낮에 구장에 들른 사람을 재는 갈래인데, 그 사람의 후보가 게이트에서 이미
/// 사라진다). 그래서 둘의 합집합이다.
List<StadiumVisitCandidate> candidatesToJudge(
  List<StadiumVisitCandidate> candidates,
  DateTime now,
) {
  final today = kstDateOf(now);
  return [
    for (final candidate in candidates)
      if (kstDateOf(candidate.startsAt) == today ||
          visitWindowCovers(candidate, now))
        candidate,
  ];
}

/// 경기 시각 기준 시간 창이 [now] 를 덮는가 — **양 끝은 포함이다**(창의
/// 경계에 선 사람을 밖으로 밀지 않는다).
bool visitWindowCovers(StadiumVisitCandidate candidate, DateTime now) {
  final opens = candidate.startsAt.subtract(kVisitWindowBeforeStart);
  final closes = candidate.startsAt.add(kVisitWindowAfterStart);
  return !now.isBefore(opens) && !now.isAfter(closes);
}

/// 세 조건의 **순수 판정** — 좌표 in, 결과 out.
///
/// 갈래를 보는 순서가 곧 이유의 우선순위다: 후보 게이트([candidatesToJudge])
/// → 권한 → 좌표 → 반경 → 시간 창.
///
/// **왜 후보 게이트가 권한보다 앞인가.** 판정할 후보가 없는 실행에는 판정할
/// 것 자체가 없으므로 위치 계층을 아예 건드릴 이유가 없다 —
/// [StadiumVisitChecker] 가 그 순서를 그대로 따라 권한도 좌표도 묻지 않는다. 한 해의 절반쯤은 어느
/// 구장에도 경기가 없고, 경기가 있는 날에도 대부분의 사람은 구장 근처에
/// 있지 않다. 그 대가로 "권한이 없다"는 이유는 **경기가 있는 날에만** 남는데,
/// 뒤에 재요청 진입점을 세우는 사람에게는 그쪽이 오히려 맞는 시점이다(권한을
/// 켜 달라고 말할 이유가 실제로 있는 날이다).
///
/// [fix] 가 null 이면 좌표를 얻지 못했거나 애초에 읽지 않은 실행이다.
///
/// [radiusMeters] 는 **경계 자체를 재기 위한 이음매**다. 앱 경로는 넘기지
/// 않고 기본값([kStadiumVisitRadiusMeters])을 쓴다 — 시험이 이것을 넘기는
/// 까닭은 하버사인 거리가 부동소수라 "정확히 300m 인 좌표"를 만들 수 없기
/// 때문이다(거리 값들의 간격이 위도 한 ulp 가 만드는 변화보다 훨씬 촘촘하다).
/// 반경을 거리와 같은 값으로 주면 비교가 정확히 경계에서 일어나서,
/// `<=` 를 `<` 로 바꾸는 변이가 빨간불이 된다.
StadiumVisitResult judgeStadiumVisit({
  required LocationPermissionStatus permission,
  required List<StadiumVisitCandidate> candidates,
  required DateTime now,
  required DeviceFix? fix,
  double radiusMeters = kStadiumVisitRadiusMeters,
}) {
  final inPlay = candidatesToJudge(candidates, now);
  if (inPlay.isEmpty) {
    return const StadiumVisitResult.rejected(StadiumVisitReason.noGameToday);
  }

  if (permission != LocationPermissionStatus.granted) {
    return const StadiumVisitResult.rejected(
      StadiumVisitReason.permissionMissing,
    );
  }

  if (fix == null) {
    return const StadiumVisitResult.rejected(
      StadiumVisitReason.locationUnavailable,
    );
  }

  final near = [
    for (final candidate in inPlay)
      if (_metersBetween(fix.lat, fix.lng, candidate.lat, candidate.lng) <=
          radiusMeters)
        candidate,
  ];
  if (near.isEmpty) {
    return const StadiumVisitResult.rejected(StadiumVisitReason.outsideRadius);
  }

  for (final candidate in near) {
    if (visitWindowCovers(candidate, now)) {
      return StadiumVisitResult.visited(
        stadiumId: candidate.stadiumId,
        gameId: candidate.gameId,
      );
    }
  }
  return const StadiumVisitResult.rejected(
    StadiumVisitReason.outsideTimeWindow,
  );
}

/// 두 좌표 사이의 거리(m) — 하버사인.
///
/// 위치 플러그인의 거리 함수를 쓰지 않는 것은 순수 판정이 플러그인에 기대지
/// 않게 하기 위해서다(시험이 채널 없이 다섯 갈래를 전부 돌린다). 구장 반경
/// 수백 m 규모에서 지구를 구로 보는 오차는 1m 미만이라 판정에 영향이 없다.
double _metersBetween(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusMeters = 6371008.8;
  final phi1 = _radians(lat1);
  final phi2 = _radians(lat2);
  final deltaPhi = _radians(lat2 - lat1);
  final deltaLambda = _radians(lng2 - lng1);
  final a =
      math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
      math.cos(phi1) *
          math.cos(phi2) *
          math.sin(deltaLambda / 2) *
          math.sin(deltaLambda / 2);
  return 2 * earthRadiusMeters * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;

/// 기기의 지금 좌표를 읽는 함수 — 시험이 갈아 끼우는 이음매.
///
/// 실패 계약은 `lib/location/` 의 나머지와 같다: **던지지 않고**, 알아내지
/// 못한 실행은 null 로 답한다.
typedef DeviceFixReader = Future<DeviceFix?> Function();

/// 판정을 실제로 돌리는 자리 — 권한을 묻고, 필요할 때만 좌표를 읽고,
/// [judgeStadiumVisit] 에 넣는다.
class StadiumVisitChecker {
  const StadiumVisitChecker({
    required this.readPermission,
    required DeviceFixReader readFix,
    // 이름 있는 인자는 `this._readFix` 로 쓸 수 없다(Dart 는 이름 있는
    // 인자가 `_` 로 시작하는 것을 금한다). 필드를 private 으로 두는 것이 이
    // 계층의 계약이므로 lint 쪽을 끈다.
    // ignore: prefer_initializing_formals
  }) : _readFix = readFix;

  /// 지금 권한 상태 — OS 다이얼로그를 띄우지 않는 쪽
  /// ([LocationPermissionGateway.status]) 이다. 이 단계는 권한을 **요청하지
  /// 않는다**: 2.5 가 온보딩에서 한 번 물었고, 거절한 사람에게 다시 묻는
  /// 진입점은 아직 저장소에 없다(4.1 의 범위 밖).
  final Future<LocationPermissionStatus> Function() readPermission;

  /// 기기의 좌표를 읽는 이음매 — **밖에서 꺼낼 수 없다.**
  ///
  /// 생성자로 넣는 것은 시험이 갈아 끼우기 위해서지만, private 이라 이 값을
  /// 다시 꺼내 부르는 길은 이 라이브러리 밖에 없다. 이것이 public 이면
  /// `stadiumVisitCheckerProvider` 가 실 리더를 그대로 실어 내보내는 셈이라
  /// 어느 feature 든 기기의 실제 좌표를 손에 넣는다(파일 첫 문단 1번).
  final DeviceFixReader _readFix;

  /// 한 번의 판정. 좌표는 이 메서드 안에서 태어나 이 메서드 안에서 죽는다.
  ///
  /// 위치 계층을 건드리는 순서는 [judgeStadiumVisit] 의 갈래 순서와 같다 —
  /// 판정할 후보가 없으면([candidatesToJudge] 가 비면) 권한도 좌표도 묻지
  /// 않고, 권한이 없으면 좌표를 묻지 않는다(계약: "위치 권한이 없으면 판정을
  /// 시도하지 않는다").
  Future<StadiumVisitResult> check({
    required List<StadiumVisitCandidate> candidates,
    required DateTime now,
  }) async {
    // 이 갈래만 판정 함수를 거치지 않고 답한다 — 권한을 아직 묻지 않았으므로
    // 판정 함수에 넣을 값이 없기 때문이다. 두 자리가 같은 답을 낸다는 것은
    // `test/features/badges/visit_check_test.dart` 가 잰다.
    if (candidatesToJudge(candidates, now).isEmpty) {
      return const StadiumVisitResult.rejected(StadiumVisitReason.noGameToday);
    }

    final permission = await readPermission();
    if (permission != LocationPermissionStatus.granted) {
      return judgeStadiumVisit(
        permission: permission,
        candidates: candidates,
        now: now,
        fix: null,
      );
    }

    return judgeStadiumVisit(
      permission: permission,
      candidates: candidates,
      now: now,
      fix: await _readFix(),
    );
  }
}

/// 실제 측위 — 이 라이브러리 밖에서 부를 수 없는 **유일한 좌표 통로**.
///
/// `package:geolocator` 를 만지는 자리가 여기 하나이므로, 이 함수가 private
/// 이고 이것을 들고 도는 [StadiumVisitChecker._readFix] 도 private 인 한 다른
/// 계층은 기기의 좌표를 손에 넣을 방법이 없다(파일 첫 문단 1번).
/// SDK 예외를 밖으로 내보내지 않는다 — 무엇이 오든(권한 예외·위치 서비스
/// 꺼짐·상한 초과·플랫폼 오류) null 하나로 접는다.
Future<DeviceFix?> _readDeviceFix() async {
  try {
    final position = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        timeLimit: kLocationFixTimeout,
      ),
    ).timeout(kLocationFixTimeout);
    return DeviceFix(lat: position.latitude, lng: position.longitude);
  } catch (_) {
    // 플러그인 자신의 timeLimit 이 답하지 않는 실행까지 바깥 timeout 이
    // 받는다 — `resolveLocationPermission` 이 게이트웨이에 두른 것과 같은
    // 두 겹이고 같은 까닭이다(구현이 계약을 지키는지 부르는 쪽은 모른다).
    return null;
  }
}

/// 화면·상태 계층이 소비하는 판정기 — 시험은 override 로 갈아끼운다.
final stadiumVisitCheckerProvider = Provider<StadiumVisitChecker>((ref) {
  final gateway = ref.watch(locationPermissionGatewayProvider);
  return StadiumVisitChecker(
    readPermission: gateway.status,
    readFix: _readDeviceFix,
  );
});
