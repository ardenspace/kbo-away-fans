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
/// **딱 한 갈래([StadiumVisitReason.noGameToday])에서만 예외를 둔다.**
/// [judgeStadiumVisit] 이 후보 게이트를 권한보다 먼저 보므로, 오늘(KST) 그
/// 어느 구장에도 경기가 없는 날은 권한을 아예 묻지 않은 채 `noGameToday` 로
/// 끝난다 — KBO 정규 시즌의 월요일과 비시즌 전체가 그 날이다. 그 갈래를
/// [StadiumVisitReason.permissionMissing] 과 같이 접으면, **권한을 허용한 사람이 월요일·비시즌에
/// 홈을 열 때도 위치 자리가 통째로 사라져 acceptance 첫 문장("권한이 있으면
/// 현재 위치가 상단에 뜬다")을 어긴다** — 그 화면이 권한을 거부한 사람의
/// 화면과 구분되지 않는다. 그래서 [noGameTodayPermissionProvider] 가 이
/// 갈래에서만 [LocationPermissionGateway.status] 를 다시 물어 "권한이
/// 있는가"를 알아낸다. **[LocationPermissionGateway.request] 는 절대
/// 부르지 않는다** — 새 OS 다이얼로그를 띄우는 것은 이 화면의 일이 아니다
/// (그 진입점은 이미 배지 탭의 `VisitStatusNotice` 에 있다).
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

/// [StadiumVisitReason.noGameToday] 판정에서만 권한 상태를 다시 묻는 자리 —
/// 위 클래스 문서의 "왜 이 재조회가 4.1 이 세운 절제를 깨지 않는가" 참조.
/// [resolveLocationPermission] 을 그대로 통과시켜 실패 계약(상한 안에 반드시
/// 답한다)을 새로 만들지 않는다.
final noGameTodayPermissionProvider =
    FutureProvider.autoDispose<LocationPermissionStatus>(
      (ref) => resolveLocationPermission(
        () => ref.read(locationPermissionGatewayProvider).status(),
      ),
    );

/// 방문 판정이 구장을 특정하지 못했을 때(반경 밖·시간 창 밖·좌표를 못
/// 얻음)의 일반 문구. 권한이 없거나 아직 판정이 없으면 자리 자체를
/// 접으므로, 이 문구가 뜨는 것은 "권한은 있는데 지금은 어느 구장도 아니다"
/// 뿐이다 — 오늘 경기가 없어도 권한이 있으면 이 갈래로 들어온다
/// ([currentLocationVisible] 의 `noGameToday` 처리 참조).
const String kCurrentLocationGenericLabel = '현재 위치를 사용하고 있어요';

/// 홈 상단 위치 자리를 그릴지 — [visit] 이 권한을 실제로 물어 본 판정이거나,
/// [noGameTodayPermission] 이 그 물음을 대신 답했을 때다.
///
/// [StadiumVisitReason.permissionMissing] 은 권한이 없어 판정을 시도하지
/// 않은 갈래이므로 접는다. [StadiumVisitReason.noGameToday] 는 판정할 후보
/// 자체가 없어 [judgeStadiumVisit] 이 권한조차 묻지 않은 갈래라, 이 함수
/// 혼자서는 "권한이 있는지" 알 방법이 없다 — 그래서 그 답을 [noGameTodayPermission]
/// 으로 밖에서 받는다(부르는 쪽이 [noGameTodayPermissionProvider] 로 딱 이
/// 갈래에서만 다시 물은 값). 값이 [LocationPermissionStatus.granted] 일
/// 때만 그리고, 아직 답이 없거나(null — provider 가 아직 로딩 중) 없다는
/// 답(`denied`·`permanentlyDenied`)이면 접는다 — "권한이 없는 사람과
/// 구분되지 않는다"는 계약 위반을 반대 방향(아직 모르는데 그린다)으로
/// 되풀이하지 않기 위한 선택이다. 그 밖의 넷([StadiumVisitReason.visited]·
/// [StadiumVisitReason.locationUnavailable]·[StadiumVisitReason.outsideRadius]·
/// [StadiumVisitReason.outsideTimeWindow])은 [StadiumVisitChecker.check] 가
/// 권한을 이미 [LocationPermissionStatus.granted] 로 확인한 뒤에만 나오는
/// 갈래라([judgeStadiumVisit] 참조) 권한이 있다는 뜻이고, [noGameTodayPermission]
/// 은 그 넷에서 쓰이지 않는다.
bool currentLocationVisible(
  StadiumVisitResult? visit, {
  LocationPermissionStatus? noGameTodayPermission,
}) {
  if (visit == null) return false;
  return switch (visit.reason) {
    StadiumVisitReason.permissionMissing => false,
    StadiumVisitReason.noGameToday =>
      noGameTodayPermission == LocationPermissionStatus.granted,
    StadiumVisitReason.visited ||
    StadiumVisitReason.locationUnavailable ||
    StadiumVisitReason.outsideRadius ||
    StadiumVisitReason.outsideTimeWindow => true,
  };
}

/// 홈 상단에 보일 문구 — [visit] 이 방문을 확정했으면 그 구장 이름,
/// 아니면 [kCurrentLocationGenericLabel].
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
}) {
  final stadiumId = visit?.stadiumId;
  if (visit == null || !visit.isVisit || stadiumId == null) {
    return kCurrentLocationGenericLabel;
  }
  final name = stadiums?.byId(stadiumId)?.name ?? stadiumId;
  return '$name 근처예요';
}
