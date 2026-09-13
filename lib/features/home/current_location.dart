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
/// **판정이 권한을 대신 말해 주지 못하는 갈래에서만 예외를 둔다.**
/// [judgeStadiumVisit] 이 후보 게이트를 권한보다 먼저 보므로, 오늘(KST) 그
/// 어느 구장에도 경기가 없는 날은 권한을 아예 묻지 않은 채 `noGameToday` 로
/// 끝난다 — KBO 정규 시즌의 월요일과 비시즌 전체가 그 날이다. 그리고 콘텐츠
/// 문서를 못 얻은 실행에서는 [StadiumVisitCheck.run] 이 판정을 아예 돌리지
/// 못해 결과가 null 로 남는다(통합 검증 탐침 E 가 잰 자리). 그 둘을
/// [StadiumVisitReason.permissionMissing] 과 같이 접으면, **권한을 허용한
/// 사람이 월요일·비시즌에, 또는 콘텐츠를 못 받은 날에 홈을 열 때도 위치
/// 자리가 통째로 사라져 acceptance 첫 문장("권한이 있으면 현재 위치가 상단에
/// 뜬다")을 어긴다** — 그 화면이 권한을 거부한 사람의 화면과 구분되지 않는다.
/// 그래서 [locationPermissionStatusProvider] 가 그 둘에서만
/// [LocationPermissionGateway.status] 를 다시 물어 "권한이 있는가"를
/// 알아낸다. **[LocationPermissionGateway.request] 는 절대 부르지 않는다** —
/// 새 OS 다이얼로그를 띄우는 것은 이 화면의 일이 아니다(그 진입점은 이미
/// 배지 탭의 `VisitStatusNotice` 에 있다).
///
/// **셋째 갈래는 "판정까지 가지 못한 실행"이다.** 4.2 의 게이트가 닫힌 뒤
/// (도장을 받고 시간 창이 닫힐 때까지) 또는 콘텐츠를 못 얻은 실행 뒤에는
/// 손에 든 판정이 옛 사실이라, 그 안의 "권한이 있었다"도 함께 옛 것이다 —
/// 그 구간에서 권한을 끄고 돌아온 사람의 홈 상단이 그대로 서 있던 것이
/// phase 5 통합 검증 round 3 의 REJECT 사유다. [currentLocationVisible] 과
/// [currentLocationNeedsPermissionAnswer] 가 같은 잣대
/// (`stadiumVisitRunProvider` 의 `judged`)로 그 갈래를 가른다. 여기서도
/// 새로 만드는 것은 **다이얼로그 없는 `status()` 하나**이고 측위는 하나도
/// 늘지 않는다.
///
/// **판정을 "지금"으로 읽어도 되는지는 따로 잰다.** 4.2 는 새 도장이 나올 수
/// 없는 구간에서 측위를 건너뛰므로([StampAward.judgingAddsNothing]), 손에 든
/// 판정은 몇 시간 전 것일 수 있다. 그래서 이 파일은 판정 결과와 함께
/// [stadiumVisitRunProvider] 의 기록(마지막 시도가 언제였고 판정까지 갔는지)을
/// 읽어 [kCurrentLocationFreshness] 안의 판정만 구장 이름으로 쓴다. 그 밖은
/// 자리를 접는 대신 [kCurrentLocationGenericLabel] 로 내려간다 — 모르는 것을
/// 아는 척하지 않으면서, 권한이 있는 사람의 화면은 그대로 남긴다.
/// **그 나이를 실제로 다시 재는 계기를 두는 자리가 [CurrentLocationRow] 다** —
/// 성질만 세우고 계기를 두지 않으면 홈이 다시 설 때에만 재어져서, 앱을
/// 포그라운드에 둔 채 구장을 떠난 사람의 화면이 그대로 멈춘다(round 2 의
/// REJECT 사유. 그 위젯 문서에 계기 둘을 적었다).
///
/// **왜 이 재조회가 4.1 이 세운 절제를 깨지 않는가.** `lib/location/CLAUDE.md`
/// 가 "다시 물을 수 있는지를 갈라야 하는 자리는 그때 `status()` 를 그 자리에서
/// 물으면 된다"고 근거를 적어 두었고, 4.5 의 배지 탭 안내가 이미 같은 일을
/// 한다 — 그래서 그 물음은 화면마다 짓지 않고 위치 계층의
/// [locationPermissionStatusProvider] 하나를 함께 쓴다. 그 provider 는
/// [FutureProvider.autoDispose] 라 아무도 구독하지 않는 동안(권한을 물을
/// 까닭이 없는 갈래 — 시즌 중 대부분의 날)은 인스턴스화조차 되지 않는다.
///
/// **실측으로 확인한 대가 — 처음 시도와 다른 자리.** 처음에는
/// [LocationPermissionGateway.status] 를 홈이 **모든 갈래에서 매 빌드마다**
/// 새로 묻는 자리를 만들었는데, 그러면 위치 게이트웨이를 override 하지 않는
/// 전체 앱 부팅 시험들(`test/phase2_journey_probe_test.dart` 등)이 실 플랫폼
/// 채널을 만지며 타이머가 위젯 트리 해제 뒤까지 남아 깨졌다(전체 스위트에서
/// 23개 파일·33개 시험이 함께 흔들렸다, `.wellbegun/decisions.md` 2026-09-06
/// 참조). 지금은 그와 다르다 — 재조회가 서는 것은 매 빌드가 아니라
/// [currentLocationNeedsPermissionAnswer] 가 참인 두 갈래뿐이고, 그 값을
/// 만드는 것은 판정을 실제로 돌리는 실행(`StadiumVisitTrigger` 를 씌운
/// 화면)뿐이다.
///
/// **그래도 대가는 남았고, 실측해서 닫았다.** 갈래를 "판정이 아예 없는
/// 실행"까지 넓히자(탐침 E) 콘텐츠를 못 얻은 채 앱을 띄우는 부팅 시험들이
/// 실 플랫폼 채널을 물어 같은 모양으로 깨졌다 — 8개 파일·24개 시험, 전부
/// "A Timer is still pending"이다. 산출물이 아니라 그 시험들에
/// [locationPermissionGatewayProvider] 대역을 더해 닫았다(단언은 그대로).
/// **앱을 통째로 띄우는 시험을 새로 쓰면 그 대역을 함께 두십시오** — 이
/// 화면은 판정이 없는 실행에서 권한을 한 번 묻는다.
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/models.dart';
import '../../design/app_theme.dart';
import '../../design/tokens.dart';
import '../../location/location.dart' show LocationPermissionStatus;
import '../../location/visit_check.dart'
    show StadiumVisitResult, StadiumVisitReason;
import 'next_away_game.dart' show clockProvider;

/// 홈 목록에서 위치 자리를 가리키는 표지 — **"상단"을 자리로 재기 위한
/// 것이다** (5.2 acceptance 의 "권한이 있으면 현재 위치가 **상단에** 뜬다").
///
/// 이 표지가 없던 동안에는 그 조각을 홈 `ListView` 의 맨 아래로 옮겨도
/// 저장소 전체가 초록불이었다(phase 5 통합 검증의 실측). 문구를 찾는 시험은
/// 순서를 재지 못하고, 화면 밖으로 밀려나 우연히 안 잡히는 것에 기대는 것도
/// 순서를 재는 것이 아니다 — 그래서 목록의 **몇 번째 자식인지**를 그대로
/// 보는 시험을 `home_screen_test.dart` 에 두었다.
const Key kCurrentLocationRowKey = ValueKey('home-current-location');

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
/// **판정이 "권한이 있다"를 말해 주는 것은 그 판정이 난 순간까지다.**
/// [lastRunJudged] 가 거짓인 실행 — 마지막 시도가 게이트에서 멈췄거나
/// ([StampAward.judgingAddsNothing]) 콘텐츠를 못 얻어 판정까지 가지 못한
/// 실행 — 뒤에는 손에 든 [visit] 이 **옛 사실**이다. 도장을 받고 나면 4.2 의
/// 게이트가 시간 창이 닫힐 때까지(경기 시작 +5시간) 판정을 통째로 건너뛰므로
/// 그 옛 사실은 최대 다섯 시간을 산다. 그동안 사람이 OS 설정에서 권한을 끄고
/// 돌아와도 이 함수가 `visited` 를 "권한이 있다"로 읽어 자리가 그대로 서
/// 있었다(phase 5 통합 검증 round 3 의 REJECT 사유. 그 자리를 재는 못이
/// `test/features/home/phase5_integration_round3_probe_test.dart` 의 Q1 이다).
/// **그 갈래에서는 판정을 믿지 않고 [askedPermission] 만 믿는다** —
/// [currentLocationNeedsPermissionAnswer] 가 같은 잣대로 그 조회를 켠다.
/// 이것은 5.2 가 **구장 이름** 쪽에 이미 대 두었던 잣대
/// ([currentLocationIsFresh] 가 판정까지 가지 못한 실행 뒤에 null 을 받는
/// 것)를 **자리를 그릴지** 쪽에도 대는 것이고, 새로 만드는 것은 다이얼로그
/// 없는 [LocationPermissionGateway.status] 하나뿐이라 4.1·4.2 의 측위 절제를
/// 되돌리지 않는다.
///
/// 갈래별 근거:
/// - **[visit] 이 null** — 판정이 아직 없거나(첫 프레임) 콘텐츠 문서를 못
///   얻어 판정이 아예 돌지 못한 실행이다([StadiumVisitCheck.run]). 뒤엣것은
///   권한이 있어도 자리가 통째로 접히던 자리라(통합 검증 탐침 E), 트리거가
///   한 번이라도 돌았으면([judgmentAttempted]) 권한을 따로 물어 가른다.
/// - **마지막 시도가 판정까지 가지 못했음** ([lastRunJudged] 이 거짓) — 위
///   문단. 이유가 무엇이든 [askedPermission] 이 정한다.
/// - **[StadiumVisitReason.permissionMissing]** — 권한이 없어 판정을
///   시도하지 않은 갈래다. 접는다.
/// - **[StadiumVisitReason.noGameToday]** — 판정할 후보가 없어
///   [judgeStadiumVisit] 이 권한조차 묻지 않은 갈래라, 이 함수 혼자서는
///   권한을 알 수 없다. 그 답을 [askedPermission] 으로 밖에서 받는다.
/// - **나머지 넷** — [StadiumVisitChecker.check] 가 권한을
///   [LocationPermissionStatus.granted] 로 이미 확인한 **그 실행이 마지막
///   실행일 때만** 권한이 있다는 뜻이고, 그때는 [askedPermission] 이 쓰이지
///   않는다.
///
/// [askedPermission] 이 아직 null 이면(조회가 로딩 중) 접는다 — "권한이 없는
/// 사람과 구분되지 않는다"는 위반을 반대 방향(아직 모르는데 그린다)으로
/// 되풀이하지 않기 위해서다.
///
/// [lastRunJudged] 는 [judgmentAttempted] 가 참일 때만 읽는다(시도한 적이
/// 없으면 "판정까지 갔는가"를 물을 대상 자체가 없다). 기본값을 두지 않은
/// 것은 의도다 — 이 값을 빠뜨린 부름이 곧 위 REJECT 의 거동이라, 새 부르는
/// 쪽이 그 사실을 반드시 한 번 지나가게 한다.
bool currentLocationVisible(
  StadiumVisitResult? visit, {
  bool judgmentAttempted = false,
  required bool lastRunJudged,
  LocationPermissionStatus? askedPermission,
}) {
  if (visit == null) {
    return judgmentAttempted &&
        askedPermission == LocationPermissionStatus.granted;
  }
  // 손에 든 판정이 마지막 실행의 답이 아니면 그 안의 "권한이 있었다"도 옛
  // 사실이다 — 다시 물은 답만 믿는다. (이 갈래는
  // [currentLocationNeedsPermissionAnswer] 의 같은 갈래와 짝이라, 여기 닿는
  // 부름에는 그 조회가 이미 켜져 있다.)
  if (judgmentAttempted && !lastRunJudged) {
    return askedPermission == LocationPermissionStatus.granted;
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
///
/// **[currentLocationVisible] 과 갈래가 정확히 같아야 한다** — 저쪽이
/// [askedPermission] 으로 답을 정하는 갈래에서 이쪽이 거짓이면 그 답은 늘
/// null 이라 자리가 영영 접히고, 반대면 물을 까닭 없는 조회가 생긴다. 그
/// 짝을 값으로 붙잡아 두는 시험이 `current_location_test.dart` 에 있다
/// ("두 함수의 갈래가 어긋나지 않는다").
///
/// 이 물음이 참인 세 갈래:
///  1. 판정이 아직 없는데 트리거는 돌았다([judgmentAttempted]).
///  2. **마지막 시도가 판정까지 가지 못했다**([lastRunJudged] 이 거짓) —
///     4.2 의 게이트가 닫혔거나 콘텐츠를 못 얻은 실행. 그 뒤로는 손에 든
///     판정이 권한을 대신 말해 주지 못한다(round 3 의 REJECT 사유).
///  3. 판정이 [StadiumVisitReason.noGameToday] 로 끝나 권한을 아예 묻지
///     않았다.
///
/// 셋 다 **복귀당 한 번**만 다시 답한다 — [locationPermissionStatusProvider]
/// 는 `autoDispose` 이고 그것을 버리는 자리는 [StadiumVisitTrigger] 의
/// 포그라운드 복귀뿐이라, 이 물음이 참인 동안 홈이 몇 번 다시 그려지든
/// 조회는 늘지 않는다.
bool currentLocationNeedsPermissionAnswer(
  StadiumVisitResult? visit, {
  required bool judgmentAttempted,
  required bool lastRunJudged,
}) {
  if (visit == null) return judgmentAttempted;
  if (judgmentAttempted && !lastRunJudged) return true;
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

/// 홈 상단 위치 한 줄 — 문구를 고르는 것뿐 아니라 **그 문구가 낡는 순간**을
/// 스스로 지켜보는 자리다.
///
/// **왜 위젯으로 따로 서는가.** [currentLocationIsFresh] 는 판정의 나이를
/// 재는 함수이고, 나이는 아무도 아무 일을 하지 않아도 자란다. 그것을 홈
/// 화면의 `build` 안에서만 재면 **홈이 다시 설 때에만** 재어진다 — 그런데
/// 탭 골격이 [IndexedStack] 이라 탭을 오가도 홈은 다시 서지 않고, 시간이
/// 흐르는 것만으로는 다시 설 까닭이 아예 없다. 그래서 사직에서 도장을 받고
/// (19:00) **앱을 배경으로 보내지 않은 채** 서울로 이동해 21:30이 되어도
/// "사직야구장 근처예요"가 그대로 서 있었다(phase 5 통합 검증 round 2 의
/// REJECT 사유). round 1 이 세운 성질([currentLocationIsFresh])은 옳았고,
/// 빠진 것은 **그 성질이 실제로 다시 재어지는 계기**였다.
///
/// 계기를 둘 둔다. 둘 다 좌표를 묻지 않는다 — 4.1·4.2 의 절제(도장을 받은
/// 뒤 창이 닫힐 때까지 측위를 켜지 않는다, `decisions.md` 2026-09-04 `[S]`)를
/// 되돌리지 않는 까닭이 그것이다. 여기서 자라는 것은 나이뿐이고, 나이를 재는
/// 데 필요한 것은 시계 하나다.
///
///  1. **낡는 그 순간에 한 번 깨어나는 타이머.** 판정이 난 시각 +
///     [kCurrentLocationFreshness] 에 맞춰 [Timer] 하나를 걸어 두고, 깨어나면
///     다시 그린다. 주기 실행이 아니라 **판정 하나당 한 번**이고, 깨어난 뒤에는
///     이미 낡았으므로 다시 걸지 않는다. 그래서 이 위젯이 들고 있는 타이머는
///     늘 0개 아니면 1개다.
///  2. **이 탭이 다시 보이는 순간** ([TickerMode]). 보이지 않는 동안에는
///     타이머를 두지 않고, 다시 보이는 순간 [TickerMode.valuesOf] 의존이 이
///     위젯을 다시 그려 나이를 그 자리에서 새로 잰다. 탭 골격이 보이지 않는 탭의
///     `Ticker` 를 끄는 데 쓰는 바로 그 신호이고(`main_tab_scaffold.dart`),
///     "지금 이 화면이 사람 눈앞에 있는가"를 이 계층이 알 수 있는 유일한
///     자리다.
///
/// **자리를 그릴지 말지는 여기서 정하지 않는다** — 그것은
/// [currentLocationVisible] 이 권한으로 정하고, 부르는 쪽이 그 답에 따라 이
/// 위젯을 아예 짓지 않는다. 여기서 갈리는 것은 문구뿐이다.
class CurrentLocationRow extends ConsumerStatefulWidget {
  const CurrentLocationRow({
    super.key,
    required this.visit,
    required this.stadiums,
    required this.judgedAt,
  });

  /// 가장 최근 판정 — 구장 이름을 아는 유일한 자리다.
  final StadiumVisitResult? visit;

  /// 구장 문서 — 이름을 얻지 못하면 id 로 저하한다.
  final StadiumsDocument? stadiums;

  /// [visit] 이 **난 시각** — 마지막 시도가 판정까지 가지 못했으면 null
  /// (`stadiumVisitRunProvider` 문서 참조).
  final DateTime? judgedAt;

  @override
  ConsumerState<CurrentLocationRow> createState() => _CurrentLocationRowState();
}

class _CurrentLocationRowState extends ConsumerState<CurrentLocationRow> {
  /// 판정이 낡는 순간에 한 번 깨어나는 타이머 — 없거나 하나다.
  Timer? _expiry;

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  /// 남은 신선도만큼 타이머를 다시 건다.
  ///
  /// 겨냥하는 것은 **절대 시각**([CurrentLocationRow.judgedAt] +
  /// [kCurrentLocationFreshness])이라, 이 위젯이 그사이 몇 번 다시 그려지든
  /// 깨어나는 순간은 같은 자리다. 이미 낡았거나([fresh] 가 거짓) 이 탭이 보이지
  /// 않으면([visible] 이 거짓) 타이머를 두지 않는다 — 앞엣것은 깨워도 바뀔
  /// 것이 없고, 뒤엣것은 다시 보이는 순간의 `build` 가 대신 재기 때문이다.
  void _armExpiry({
    required bool fresh,
    required bool visible,
    required DateTime now,
  }) {
    _expiry?.cancel();
    _expiry = null;
    final judgedAt = widget.judgedAt;
    if (!fresh || !visible || judgedAt == null) return;
    final remaining = judgedAt.add(kCurrentLocationFreshness).difference(now);
    _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final material = Theme.of(context);
    final muted =
        material.extension<AppVisualTheme>()?.textSecondary ??
        material.colorScheme.onSurfaceVariant;
    final now = ref.watch(clockProvider)();
    // 이 탭이 지금 사람 눈앞에 있는가 — 이 한 줄이 위 2) 의 의존을 만든다.
    final visible = TickerMode.valuesOf(context).enabled;
    final fresh = currentLocationIsFresh(judgedAt: widget.judgedAt, now: now);
    // `build` 안에서 타이머를 다시 거는 것은 상태를 바꾸지 않는 일이라
    // 이 프레임에 아무 영향이 없다 — 다음 프레임을 요청하지도 않는다.
    _armExpiry(fresh: fresh, visible: visible, now: now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpaceTokens.lg,
        SpaceTokens.lg,
        SpaceTokens.lg,
        0,
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_rounded, color: muted),
          const SizedBox(width: SpaceTokens.sm),
          Text(
            currentLocationLabel(
              visit: widget.visit,
              stadiums: widget.stadiums,
              fresh: fresh,
            ),
            style: TextTokens.bodyMuted,
          ),
        ],
      ),
    );
  }
}
