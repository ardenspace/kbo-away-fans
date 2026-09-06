/// 홈 상단 현재 위치 표시 (step 5.2) — 순수 로직.
///
/// **새 측위도, 새 권한 조회도 만들지 않는다.** `lib/location/CLAUDE.md`
/// 가 5.2 에 남긴 지침대로, 위치 권한 상태와 측위 경로는 4.1 이 이미 세운
/// 것을 그대로 쓴다 — 이 파일이 유일하게 읽는 신호는
/// `lib/features/badges/stadium_visit.dart` 의 [stadiumVisitProvider] 다.
/// 그 provider 는 앱을 열 때·포그라운드로 돌아올 때 이미
/// [StadiumVisitTrigger] 가 돌리고 있고, 판정 자체가 "판정할 후보가 없으면
/// 권한도 좌표도 묻지 않는다"([judgeStadiumVisit] 문서 참조)는 계약으로 이미
/// 위치 I/O 를 최소화해 두었다 — 이 화면이 그 위에 **또 다른 독립된**
/// 권한 조회를 얹으면 그 절제가 깨진다.
///
/// **실측으로 확인한 대가.** 처음에는 [LocationPermissionGateway.status]
/// 를 홈이 매 빌드마다 새로 묻는 자리를 따로 만들었는데, 그러면 위치
/// 게이트웨이를 override 하지 않는 전체 앱 부팅 시험들
/// (`test/phase2_journey_probe_test.dart` 등)이 실 플랫폼 채널을 만지며
/// 타이머가 위젯 트리 해제 뒤까지 남아 깨졌다(`test/phase2_journey_probe_test.dart`
/// 의 "상한 셋이 한 실행에서 겹쳐도 사람은 예산 안에 홈에 닿는다" 등 2건
/// 재현, 전체 스위트에서는 같은 뿌리로 20여 개 시험이 함께 흔들렸다). 그래서
/// 새 조회를 버리고 이미 도는 [stadiumVisitProvider] 만 읽는 이 모양으로
/// 되돌렸다 — `.wellbegun/decisions.md` 참조.
///
/// **그 대가로 남는 것.** [stadiumVisitProvider] 는 판정할 후보(그날 그
/// 구장에 경기)가 있는 날에만 권한을 실제로 묻는다. 그래서 이 화면의 위치
/// 표시도 **경기가 있는 날에만** 뜬다 — 경기가 없는 날은 권한이 있어도
/// 자리가 접힌다(discretion: 갱신 주기를 4.1 의 트리거와 게이트에 그대로
/// 맡긴다). "구장 근접 표시"라는 형태 자체가 경기가 있는 날의 개념이라는
/// 점과도 맞는다.
///
/// **표기 형태는 "구장 근접 표시"를 고른다** (plan.md step 5.2 discretion).
/// [StadiumVisitResult] 는 방문이 확정된 갈래에만 구장 id 를 담으므로
/// (`lib/location/visit_check.dart` 겹 5), 이 계층이 아는 "지금 위치"는
/// "어느 구장 근처에 있는가, 아니면 모른다" 둘뿐이다. "구·동 단위" 표기
/// (역지오코딩)는 `lib/location/` 의 허용 import 목록에 없는 외부 지도
/// 서비스를 새로 들여야 해서 고르지 않았다.
library;

import '../../content/models.dart';
import '../../location/visit_check.dart';

/// 방문 판정이 구장을 특정하지 못했을 때(반경 밖·시간 창 밖·좌표를 못
/// 얻음)의 일반 문구. 권한이 없거나(판정 이유) 아직 판정이 없거나
/// (오늘 경기가 없어 판정할 것 자체가 없는 경우 포함) 자리 자체를 접으므로
/// 이 문구가 뜨는 것은 "권한은 있는데 지금은 어느 구장도 아니다" 뿐이다.
const String kCurrentLocationGenericLabel = '현재 위치를 사용하고 있어요';

/// 홈 상단 위치 자리를 그릴지 — [visit] 이 권한을 실제로 물어 본 판정일
/// 때만이다.
///
/// [StadiumVisitReason.permissionMissing] 은 권한이 없어 판정을 시도하지
/// 않은 갈래이므로 접는다. [StadiumVisitReason.noGameToday] 는 판정할 후보
/// 자체가 없어 권한조차 묻지 않은 갈래라 "권한이 있는지" 알 방법이 없으므로
/// 같이 접는다(위 문서 "그 대가로 남는 것"). 그 밖의 넷([StadiumVisitReason.visited]·
/// [StadiumVisitReason.locationUnavailable]·[StadiumVisitReason.outsideRadius]·
/// [StadiumVisitReason.outsideTimeWindow])은 [StadiumVisitChecker.check] 가
/// 권한을 이미 [LocationPermissionStatus.granted] 로 확인한 뒤에만 나오는
/// 갈래라([judgeStadiumVisit] 참조) 권한이 있다는 뜻이다.
bool currentLocationVisible(StadiumVisitResult? visit) {
  if (visit == null) return false;
  return switch (visit.reason) {
    StadiumVisitReason.permissionMissing ||
    StadiumVisitReason.noGameToday => false,
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
