# lib/location/ — 작업 전 필독 (read-first)

기기의 위치와 닿는 코드는 이 폴더를 통과한다. 파일이 둘이고 아는 것이 다르다:
`location.dart` 는 **권한 상태 세 갈래**를(step 2.5), `visit_check.dart` 는
**좌표와 구장 방문 판정**을(step 4.1) 안다. 5.2(홈 상단 현재 위치)가 좌표를
쓸 자리도 이 계층 안이다.

- **위치 플러그인 import 는 이 폴더 안에만.** `package:permission_handler`·
  `package:geolocator` 를 `lib/features/`·`lib/ui/` 에서 import 하지 않는다.
  사이클 1이 지도·날씨 SDK 에 세운 규칙과 같다 — 화면은 이 계층이 내보내는
  타입(`LocationPermissionStatus`·`StadiumVisitResult`)만 소비한다.
  `scripts/hooks/check-firebase-import-boundary.sh` 가 이 경계를 잡고
  (pre-commit), 폴더가 아니라 **파일**로 좁혀 둔다 — `permission_handler` 는
  `lib/location/location.dart` 에만, `geolocator` 는
  `lib/location/visit_check.dart` 에만. 뒤엣것이 더 좁은 데는 까닭이 있다:
  기기의 좌표를 얻는 통로(`_readDeviceFix`)를 그 라이브러리 안에 private 으로
  가둬 두면 다른 계층에는 그 값을 받아 갈 통로가 없다. 그 통로를
  들고 도는 `StadiumVisitChecker` 도 그것을 **private 필드**로만 쥔다 —
  생성자로 넣을 수는 있어도(시험이 갈아 끼우는 이음매)
  `stadiumVisitCheckerProvider` 를 읽은 쪽이 다시 꺼내 부를 수는 없다.
- **SDK 예외를 밖으로 내보내지 않는다** (`lib/backend/CLAUDE.md` 의 같은 이름
  규칙의 짝). 이 폴더의 실패 계약은 오류 타입이 아니라 **값 하나**다: 권한
  조회는 던지지 않고, `kLocationPermissionTimeout` 안에 반드시 답하며,
  알아내지 못한 실행은 `LocationPermissionStatus.denied` 로 답한다. 좌표 조회도
  같은 모양이다 — 던지지 않고, `kLocationFixTimeout` 안에 답하며, 알아내지
  못한 실행은 `null` 로 답한다(판정은 그것을
  `StadiumVisitReason.locationUnavailable` 로 받는다). 그 계약을 실행하는
  자리는 `resolveLocationPermission`·`_readDeviceFix` 둘뿐이므로, 새 구현이나
  새 메서드를 더할 때 SDK 호출을 그 둘 중 하나의 모양으로 감싼다. 두 자리 다
  **실 코드 그대로** 재는 시험이 있다 — 플러그인의 플랫폼 인터페이스를 갈아
  끼워 던지는 실행·답하지 않는 실행을 만든다
  (`test/location/device_permission_handler_gateway_test.dart`,
  `test/location/stadium_visit_fix_contract_test.dart`).
- **기다림에는 상한이 있다.** 이 규칙은 이 저장소가 이미 세 번 세웠다
  (`kAppCheckActivationTimeout`·`kProfileServerConfirmGrace`·
  `kCachedTeamReadTimeout`). 상한을 두는 까닭은 확률이 아니라 빠져나갈 길이
  없다는 성질이다 — 권한 조회를 기다리는 것은 온보딩 직후의 대기 화면이다.
  다만 **길이는 그 기다림이 무엇을 붙잡고 있는지에 따라 다르다**:
  `kLocationFixTimeout`(10초)이 위 넷보다 긴 것은 측위가 아무 화면도 붙잡지
  않기 때문이고, 그 근거는 그 상수 주석에 있다.
- **기기가 어디에 있었는지는 서버로 올리지 않는다** (되돌리기 비용 XL 의 제품
  결정, `.wellbegun/decisions.md` 2026-09-01). 좌표는 이 계층 안에서 판정에만
  쓰고 결과(어느 구장·어느 경기)만 백엔드로 넘긴다. 그래서 이 폴더는
  **허용 목록에 있는 것만 import 한다** — 값을 밖으로 낼 수 있는 계층이나
  패키지에 닿을 길을 아예 만들지 않으면 좌표가 payload 로 흘러갈 길도 없다.
  백엔드로 넘길 결과가 있으면 이 폴더가 아니라 부르는 쪽(feature)이 두 계층을
  잇는다. `scripts/hooks/check-no-location-upload.sh` 가 이 폴더의
  `import`·`export`·`part` 를 잡는다(step 2.5; PostToolUse · pre-commit ·
  **CI**). **거부 목록이 아니라 허용 목록인 데는 까닭이 있다:** 2.5 는
  `lib/backend/` 만, round 3 은 `lib/analytics/` 까지 막았는데 round 4 가 그
  둘 밖에서 같은 힘을 가진 계층 둘(`lib/content/content_providers.dart`·
  `lib/weather/weather.dart`)을 찾아냈다 — 이름을 하나씩 늘리는 방식은 다섯
  번째 계층이 생길 때 또 샌다. 그 검사가 `lib/backend/` 에서처럼 `lat`·`lng`
  같은 **이름**을 막지 않는 것은 이 폴더에서는 좌표가 정당하기 때문이다 —
  여기서 막는 것은 이름이 아니라 나가는 길이다.

  **이 폴더가 하는 약속의 정확한 문장은 "앱의 코드가 좌표를 서버로 보내지
  않으며, 그렇게 하려면 눈에 띄는 의도적 변경이 필요하다" 이다**
  (`.wellbegun/decisions.md` 2026-09-04 `[L]`).

  **그 문장이 왜 "불가능하다"가 아닌가 — 겹 목록보다 먼저 읽을 것.** 아래
  다섯 겹을 지키는 것은 대부분 **소스 텍스트를 보는 검사와 시험**이다.
  텍스트를 보는 검사가 실제로 막는 것은 **실수와 무심코**다: import 를 하나
  더 들이는 것, 값을 담아 둘 필드를 하나 두는 것, 경계를 넘는 타입에 필드를
  하나 더하는 것. 반대로 **작정하고 그 검사를 피하려는 코드는 막지 못한다** —
  텍스트를 보는 검사에는 언제나 같은 일을 하면서 패턴을 비켜 가는 표기가
  남고, 그것은 정규식을 더 촘촘히 해서 없앨 수 있는 성질이 아니다. 4.1 의
  fresh 검증 round 3·4·5 가 매번 검사를 하나 더 두껍게 했고 매번 다음 표기가
  나왔다(별칭과 점 사이의 줄바꿈 · 네 칸 들여쓴 클래스 필드 · 한 줄로 쓴
  클래스 · 허용된 파일에 공개 함수 하나 더하기). round 5 가 그 넷을 막았지만
  다섯 번째가 없다고 적지 않는다 — 이 라운드의 구현자가 스스로 공격해 찾은
  하나가 `visit_check.dart` 첫 문단의 겹 1 에 적혀 있다.

  그런 우회를 실제로 막는 것은 검사가 아니라 **코드 리뷰**이고, 그런 코드는
  눈에 띈다. 그래서 아래 "지키는 것" 목록이 약속하는 것은 **"이 갈래는 실수로
  지나갈 수 없다"**이지 **"이 갈래는 누구도 지날 수 없다"**가 아니다. 두
  문장의 세기를 섞지 말 것 — round 3·4·5 의 REJECT 는 전부 그 섞임이었다.

  **다음에 이 문단을 고치는 사람에게.** 새 표기 우회를 하나 찾았다고 해서 이
  문단이 거짓이 되는 것은 아니다: 그런 우회는 이 문단이 이미 인정한 범위
  안이다. 값어치가 있는 것은 **실수로 지나갈 수 있는 갈래**(사람이 나쁜 뜻
  없이 쓸 법한 모양인데 검사가 놓치는 자리)를 찾는 쪽이다. 보고할 때 그 둘을
  구분해서 적을 것.

  4.1 이 실제로 좌표를 들여온 뒤로 그 약속을 지키는 겹은 다섯이다. **겹마다
  무엇이 그것을 지키는지, 그리고 무엇은 지키지 않는지 따로 적는다** —
  뭉뚱그려 "다섯 다 검사나 시험이 지킨다"라고 쓰면 안 된다:

  1. 좌표를 얻는 통로가 `visit_check.dart` 안의 private 함수 하나이고
     판정기(`StadiumVisitChecker`)도 그것을 private 필드로만 쥔다.
     **지키는 것:** Dart 의 `_` 가시성(구조)과
     `test/features/badges/visit_check_test.dart` 의 겹 1 파수꾼 여섯 —
     이 폴더에 `part` 가 없는가 · **폴더 전체**에서 geolocator 를 들이는
     **모든 별칭**을 만지는 최상위 선언이 `_readDeviceFix` **하나뿐인가**
     (별칭 없는 import 자체가 빨간불이다) · 측위 함수를 이름으로 부르는
     최상위 선언이 둘뿐인가 · `_readFix` 를 이름으로 쓰는 줄이 셋뿐인가 ·
     밖에서 값을 건네받는 두 서명이 소스 그대로인가 · 판정기가 값을 두는
     자리가 둘뿐인가. round 5 가 둘째 파수꾼을 두 곳 고쳤다: 표지를 줄이
     아니라 **선언 단위**로 보고(점 둘레의 공백·줄바꿈을 지운 뒤 찾는다),
     "private 이면 된다"가 아니라 "`_readDeviceFix` 하나여야 한다"로 좁혔다.
     **막지 않는 것:** 이미 손에 있는 좌표를 private 헬퍼끼리 주고받는 것
     (그쪽은 겹 3·4 가 받는다). 그리고 이 파수꾼은 선언을 **열 0 의 머리
     줄**로 알아보므로, 열 0 을 블록 주석으로 여는 선언은 앞 선언의 이름을
     물려받아 지나간다(실측 — `visit_check.dart` 첫 문단에 그대로 적어 두었다).
  2. 그 밖의 길인 플러그인 직접 호출은 import 가 같은 파일로 못 박혀 있다.
     **지키는 것:** `scripts/hooks/check-firebase-import-boundary.sh` — 그
     import 를 다른 파일에 두는 것도, `export` 로 재수출하는 것도 exit 2 다
     (뒤엣것은 폴더 밖에서 `Geolocator` 를 접두어 없이 부를 수 있게 되는
     갈래이고, `check-no-location-upload.sh` 의 검사 3) 도 함께 받는다).
  3. 이 폴더가 import 할 수 있는 것은 **허용 목록 여섯**뿐이고
     (`dart:math` · `package:flutter_riverpod` · `package:geolocator` ·
     권한 플러그인 · `../content/kst.dart` · 같은 폴더의 파일),
     `export`·`part` 는 쓰지 않으며, 콘솔에 찍지도 못한다.
     **지키는 것:** `check-no-location-upload.sh` 의 검사 2)·3)·5) 와, 허용
     목록의 유일한 폴더 밖 문(`lib/content/kst.dart`)에 붙는 짝 검사 **셋** —
     그 파일에 `export`·`part` 가 없고, 그 파일 자신의 import 도 허용
     목록(`models.dart`) 안에만 있고, 그 파일이 내미는 **최상위 공개 이름
     집합**이 넷 그대로다. 셋째 검사가 round 5 에서 생겼다: 그 전에는 짝
     검사가 `export` 만 보고 있어서, 그 파일에 공개 함수를 하나 더하고 그
     안에서 좌표를 외부 서버로 보내는 것이 훅 4종·시험 663개를 전부
     통과했다. 허용 목록 방향은 round 4 가 뒤집었다 — 거부 목록이던 동안
     `lib/content/content_providers.dart` 의 `httpClientProvider` 와
     `lib/weather/weather.dart` 의 `WeatherService.effectAt(lat:, lng:)` 이
     열려 있었고, 그 둘로 실 좌표가 외부 서버에 도착하는데 훅 4종·시험
     660개가 전부 초록불이었다.
     **막지 않는 것:** `dart:core` — import 없이 서는 유일한 라이브러리이고
     거기 `print` 가 있다. 검사 5) 는 이름을 그대로 부르는 줄만 잡으므로
     `final logger = print; logger('...');` 는 잡지 못한다(실측 확인). 그리고
     kst.dart 짝 검사 셋은 **그 파일 자신의 텍스트**만 보므로 그 파일이 부르는
     `lib/content/models.dart` 안쪽까지는 보지 않고, 허용 목록의 패키지
     다섯이 새 버전에서 무언가를 더 재수출하는 것도 보지 못한다.
  4. 이 폴더에 최상위 변수도, 클래스 안의 `static` 저장소도, 좌표를 쌓을 수
     있는 인스턴스 필드도 둘 수 없다. 통과하는 것은 `const`·`static const`,
     "담을 수 없는 타입"(변하지 않는 dart:core 기본형 + 이 폴더가 스스로
     선언한 class·enum·mixin 이름 + 함수 타입 typedef)의 `final` 필드, 함수
     타입의 `final` 필드, 그리고 그런 타입 인자를 받는 읽기 전용 provider
     뿐이다.
     **지키는 것:** 같은 스크립트의 검사 4). round 5 가 이 검사를 **줄에서
     문장으로** 옮겼다 — 그 전에는 "두 칸 들여쓴 클래스 몸통의 선언"만 보고
     있어서 네 칸 들여쓴 필드와 한 줄로 쓴 클래스가 그냥 지나갔다(실측, 그
     자리에서 라이브러리 밖으로 실 좌표가 읽혔다). 이제 괄호 밖의 중괄호로
     깊이를 세므로 들여쓰기와 줄바꿈이 판정을 바꾸지 못한다. 같은 라운드에서
     `extension type` 과 함수 타입이 아닌 `typedef` 를 허용 타입에서 뺐다 —
     그 둘은 몸통이 없거나 표현 필드가 헤더 괄호 안에 있어서 "그 타입의
     필드가 다시 이 검사를 지난다"는 고리를 끊는다.
     **막지 않는 것:** 함수 몸통 안의 지역 변수와 클로저 캡처(그 자리를 보게
     하면 정당한 지역 변수가 전부 걸린다 — 그쪽은 겹 1 의 파수꾼이 받는다),
     게터(값을 담지 못한다), 그리고 `final String spot;` 같은 문자열 필드
     (String 은 쌓지 못하지만 좌표 하나를 글자로 담을 수는 있다 — 그 값이
     밖으로 나가려면 겹 1·5 를 지나야 한다).
     **일부러 거절하는 정당한 모양:** 최상위 `final RegExp ... = RegExp(...)`
     와 값 타입의 `final List<String> ids;` 는 좌표를 담지 못하는데도 exit 2
     다. 우회하지 말고 허용 목록을 넓히고 ADR 을 남길 것(까닭은 그 스크립트
     헤더의 4) 에 적혀 있다).
  5. 경계를 넘는 값(`StadiumVisitResult`)에 좌표가 없고, 후보
     (`StadiumVisitCandidate`)에 팀 id 가 없다. 두 타입 다 **값을 두는 자리
     집합 자체**를 소스에서 읽어 표와 대조한다 — 결과 타입에 좌표 필드나
     `static` 필드나 좌표 게터를 더하면, 후보 타입에 `homeTeamId` 를 더하면
     빨간불이다.
     **지키는 것:** `test/features/badges/visit_check_test.dart` 의 타입
     파수꾼 셋(후보 타입 쪽이 round 5 에서 생겼다).

  이 목록의 "지키는 것"은 전부 위반을 실제로 만들어 빨간불(시험) 또는 exit 2
  (훅)를 확인한 것이고, "막지 않는 것"도 실제로 우회를 써 보고 초록불인 것을
  확인한 자리다. 각 겹이 서술뿐이던 동안 무엇이 열려 있었는지는
  `.wellbegun/decisions.md` 2026-09-04 `[M]`·`[S]`·`[L]` 과 그 뒤의 round
  3·4·5 줄에 남아 있다.

  **이 검사들이 도는 자리.** PostToolUse 훅 2종 · `pre-commit`(4종 전부) ·
  **CI 의 `conventions` job**. 마지막 것이 round 5 에서 배선됐다 — 그때까지
  `check-no-location-upload.sh` 와 `check-firebase-import-boundary.sh` 는
  로컬 훅에만 걸려 있어서, 훅을 설정하지 않은 클론과 `--no-verify` 커밋과
  크론 워크플로의 봇 커밋이 전부 지나갔다. 겹 2·3·4 가 통째로 그 두 검사에
  얹혀 있으므로, 그동안 이 문서가 "지킨다"라고 적은 것의 실제 강제 범위는
  훅을 설정한 사람의 컴퓨터뿐이었다.

  **검사를 넓혀야 할 때.** 겹 3·4 가 허용 목록이라, 이 폴더에 새 import 나 새
  모양의 provider 가 필요해지면 검사가 먼저 커밋을 막는다. 그때 할 일은 우회가
  아니라 `check-no-location-upload.sh` 의 허용 목록을 의도적으로 넓히고 ADR 을
  남기는 것이다 — **그 눈에 띔이 이 검사의 목적이다.**

  **하지 않는 약속:** "좌표를 알아내는 것이 구조적으로 불가능하다"고 적지
  않는다. `StadiumVisitChecker.check` 는 후보 지점을 부르는 쪽이 지어서 넣고
  어느 후보가 맞았는지를 돌려주는 신탁이라, 반복 질의로 기기 좌표가 좁혀진다
  (측위 5회로 오차 0.03m — `test/probe/coord_oracle_probe_test.dart` 가 그것을
  실행하며 초록불인 것이 맞다). 한 앱 바이너리 안에 위치 기반 참·거짓을 묻는
  코드가 있는 한 그 성질은 기법을 바꿔 없앨 수 없으므로, 위 다섯 겹을 더
  두껍게 만드는 것은 좋지만 절대문을 다시 써 넣지는 말 것. 좌표가 이 계층
  안에서만 살고 판정이 끝나면 버려진다는 것 — 캐시·`shared_preferences`·로그
  어느 쪽으로도 흐르지 않는다는 것 — 은 그대로 참이다.
- **백그라운드 위치는 쓰지 않는다** (`.wellbegun/decisions.md` 2026-09-01 [L]).
  묻는 권한은 `Permission.locationWhenInUse` 하나이고, "항상 허용"을 뜻하는
  `Permission.location` 을 요청하지 않는다. 구장 방문 확인은 앱이 열려 있을 때만
  하는 포그라운드 판정이다 — 그 판정을 트리거하는 자리도 앱이 열려 있을 때만
  도는 위젯(`lib/features/badges/stadium_visit.dart` 의 `StadiumVisitTrigger`)
  이고, 이 폴더에는 주기 실행도 백그라운드 작업도 없다.
- **이 폴더는 권한을 다시 묻지 않는다.** 2.5 가 온보딩에서 한 번 묻고, 4.1 의
  판정은 `status()`(다이얼로그 없는 조회)만 쓴다. 이 규칙을 재는 자리는
  `test/location/stadium_visit_fix_contract_test.dart` 다 — 판정기를 만드는
  `stadiumVisitCheckerProvider` 가 `status` 대신 `request` 를 쥐면 빨간불이
  된다(그 한 글자가 바뀌면 경기가 있는 날마다 앱을 열 때 OS 다이얼로그가
  뜬다). "나중에 할게요"로 건너뛴 사람에게 다시 묻는 진입점은 아직 저장소
  어디에도 없다 — 그것을 세우는 단계는
  `StadiumVisitReason.permissionMissing` 을 신호로 쓸 수 있다(그 이유는
  **경기가 있는 날에만** 선다).
