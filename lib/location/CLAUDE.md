# lib/location/ — 작업 전 필독 (read-first)

기기의 위치와 닿는 코드는 이 폴더를 통과한다. 파일이 둘이고 아는 것이 다르다:
`location.dart` 는 **권한 상태 세 갈래**와 그것을 한 번 묻는 provider 를(step
2.5 · 5.2 가 승격), `visit_check.dart` 는
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

  **round 6 의 REJECT 는 방향이 달랐다: 오탐이다.** 겹 4 의 검사가 평범한
  Dart 세 모양(값 나열 뒤에 멤버가 오는 enum · `@override` 가 붙은 필드 ·
  몸통 없는 게터 선언)을 잡는데, 그 검사와 문서 셋이 "일부러 거절하는 정당한
  모양은 아래 **둘**"이라고 **닫힌 목록**으로 적어 두어 그 문장이 거짓이었다.
  그 검사는 CI 에도 걸려 있으므로 오탐은 로컬 훅뿐 아니라 CI 도 막는다.
  **무엇을 열거하든 그것이 전부라고 단언하기 전에, 실제로 그것이 전부인지
  확인했는지 자문할 것** — 확인하지 않았다면 열린 모양으로 쓸 것.

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
     `test/features/badges/visit_check_test.dart` 의 겹 1 파수꾼 **일곱** —
     이 폴더에 `part` 가 없는가 · geolocator 를 들이는 **모든 별칭**을 만지는
     최상위 선언이 `_readDeviceFix` **하나뿐인가**(별칭 없는 import 자체가
     빨간불이다) · 측위 함수를 이름으로 부르는 최상위 선언이 둘뿐인가 ·
     `_readFix` 를 이름으로 쓰는 줄이 셋뿐인가 · 밖에서 값을 건네받는 두
     서명이 소스 그대로이고 폴더에서 각각 한 번씩만 서는가 · 판정기가 값을
     두는 자리가 둘뿐인가(그 클래스를 선언하는 파일이 폴더에 하나인가까지) ·
     **측위 함수의 몸통이 그대로인가**.
     **일곱 다 폴더 전체를 본다** — round 7 이 뒤의 넷을 `visit_check.dart`
     한 파일에서 폴더로 넓혔다(그 전에는 이 폴더에 파일이 하나 더 생기는
     순간 그 넷이 새 파일에 닿지 않았다. 실측: 폴더에 파일을 하나 더 두고
     거기에 `_readDeviceFix` 를 이름으로 부르는 선언 · `check` 서명 사본 ·
     `judgeStadiumVisit` 서명 사본 · `StadiumVisitChecker` 사본 ·
     `_readFix` 를 쓰는 줄을 각각 넣으면 해당 파수꾼이 각각 빨간불이다).
     일곱째가 round 7 에서 생겼다: 그 전까지 파수꾼들은 좌표를 **얻는 자리가
     어디인지**만 보고 **그 자리 안에서 좌표에 무엇을 하는지**는 보지 않았고,
     round 7 의 검증자가 정확히 그 틈으로 실 좌표를 내보냈다(최상위에 함수
     타입 변수를 하나 두고 측위 함수 몸통에서 그것을 부르는 두 줄). round 5 가 둘째 파수꾼을 두 곳 고쳤다: 표지를 줄이
     아니라 **선언 단위**로 보고(점 둘레의 공백·줄바꿈을 지운 뒤 찾는다),
     "private 이면 된다"가 아니라 "`_readDeviceFix` 하나여야 한다"로 좁혔다.
     round 6 이 그 "폴더 전체"를 **재귀**로 고쳤다 — 그 전에는 한 겹만 훑어서
     하위 폴더가 통째로 시야 밖이었고, 짝인 훅은 `find` 로 처음부터
     재귀적으로 보고 있어 둘의 시야가 갈려 있었다(실측: 하위 폴더에 좌표를
     읽는 공개 함수를 둔 파일이 옛 파수꾼에는 초록불, 고친 뒤에는 빨간불.
     그동안 그 자리를 실제로 막던 것은 import-boundary 훅이었다). 5.2 가
     하위 폴더를 만들면 그 어긋남이 곧 구멍이 된다.
     **막지 않는 것:** 이미 손에 있는 좌표를 private 헬퍼끼리 주고받는 것
     (그쪽은 겹 3·4 가 받는다). 그리고 둘째·셋째 파수꾼은 선언을 **열 0 의
     머리 줄**로 알아보므로, 열 0 을 블록 주석으로 여는 선언은 앞 선언의
     이름을 물려받아 그 둘을 지나간다. **다만 그 갈래 자체가 열려 있지는
     않다** — round 7 이 여기를 "훅 4종과 시험 665개를 전부 통과한다"로 적었던
     것이 거짓이었고, round 8 이 그 조각(`/*x*/Future<DeviceFix?> readSneaky()
     ... geo.Geolocator ...`)을 측위 함수 바로 뒤에 두고 재어 **둘이 빨간불**
     인 것을 확인했다: 훅의 검사 4)(a) 가 블록 주석을 걷어 낸 뒤 이름을 읽어
     `readSneaky:func` 를 목록 밖으로 찍고, 일곱째 파수꾼(측위 함수 몸통)이
     그 줄들을 측위 함수의 몸통으로 물려받아 표와 어긋난다. 인정하는 것은
     **파수꾼 둘의 한계**이지 갈래가 열려 있다는 것이 아니다.
  2. 그 밖의 길인 플러그인 직접 호출은 import 가 같은 파일로 못 박혀 있다.
     **지키는 것:** `scripts/hooks/check-firebase-import-boundary.sh` — 그
     import 를 다른 파일에 두는 것도, `export` 로 재수출하는 것도 exit 2 다
     (뒤엣것은 폴더 밖에서 `Geolocator` 를 접두어 없이 부를 수 있게 되는
     갈래이고, `check-no-location-upload.sh` 의 검사 3) 도 함께 받는다).
  3. 이 폴더가 import 할 수 있는 것은 **허용 목록 여섯**뿐이고
     (`dart:math` · `package:flutter_riverpod` · `package:geolocator` ·
     권한 플러그인 · `../content/kst.dart` · 같은 폴더의 파일),
     `export`·`part` 는 쓰지 않으며, 콘솔에 찍지도 못한다.
     **이 폴더는 평평하다** — 하위 폴더를 두면 훅이 exit 2 다(round 9).
     그 전에는 허용 목록의 마지막 갈래가 `/` 가 든 상대 경로를 받지 않아
     하위 폴더에서 부모를 부르는 평범한 줄이 걸렸는데, 훅은 "허용 목록 밖의
     import"라고만 말하고 이 문서는 "같은 폴더의 파일"이라고 적어 둘이 다른
     말을 하고 있었다. 여는 대신 막는 쪽을 골랐다 — 까닭과 무른 쪽은
     `.wellbegun/decisions.md` 2026-09-05 `[S]` 에 있다. 정말 필요하면 훅의
     단언과 허용 목록과 이 문단을 함께 고치고 ADR 을 남기십시오.
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
     round 6 이 그 짝 검사 셋의 **침묵**을 없앴다: 셋이 `[ -f ]` 가드 뒤에
     있어서 그 파일이 옮겨지거나 이름이 바뀌면 통째로 조용히 건너뛰어지고
     훅이 exit 0 이었다(`git mv lib/content/kst.dart lib/content/kst2.dart`
     로 재현). 이제 스크립트가 자기가 볼 세 자리(`lib/backend` ·
     `lib/location` · `lib/content/kst.dart`)의 존재를 먼저 단언하므로 자리가
     사라지면 exit 2 로 드러난다(실측). round 7 이 같은 종류의 침묵을 한 겹
     아래에서 하나 더 없앴다: 검사 2)·3)·4) 와 2-c 가 awk 출력을 stdout 으로만
     받고 종료 상태를 버리고 있어서, awk 프로그램이 깨지면 stderr 에만 오류가
     찍히고 훅은 그대로 exit 0 이었다(셋 다 구문 오류를 넣고 실 정탐을 트리에
     두어 재현). 이제 셋 다 awk 실패를 exit 2 로 드러낸다(실측).
     **막지 않는 것:** `dart:core` — import 없이 서는 유일한 라이브러리이고
     거기 `print` 가 있다. 검사 5) 는 이름을 그대로 부르는 줄만 잡으므로
     `final logger = print; logger('...');` 는 잡지 못한다(실측 확인). 그리고
     kst.dart 짝 검사 셋은 **그 파일 자신의 텍스트**만 보므로 그 파일이 부르는
     `lib/content/models.dart` 안쪽까지는 보지 않고, 허용 목록의 패키지
     다섯이 새 버전에서 무언가를 더 재수출하는 것도 보지 못한다.
     **던져진 예외도 세지 않는다.** 이 겹이 세는 것은 값을 보낼 수 있는
     이름뿐이라, 좌표를 예외 메시지에 담아 던지면 그대로 밖으로 나간다 —
     round 8 실측: `_metersBetween` 안에 `throw StateError` 한 줄을 두면
     `lib/features/badges/stadium_visit.dart` 의 `run()`(`try/finally` 라
     잡지 않는다)을 지나 부르는 쪽이 실 좌표 문자열을 받고, 그때 훅 4종이
     전부 exit 0 이고 `flutter analyze` 도 무지적이다. 막을 필요는 없지만
     (실수로 나오는 모양이 아니다) 겹 3·4 를 "값이 나갈 길이 아예 없다"로
     읽지 않도록 적어 둔다.
  4. 이 폴더에 최상위 선언으로 값을 담아 두는 자리도, 좌표를 쌓을 수 있는
     필드도 둘 수 없다. **`static` 이 붙었는지는 보지 않는다** — 애노테이션과
     `static`·`abstract`·`external`·`covariant` 를 걷어 낸 **뒤** 타입을
     보므로, `static DeviceFix? lastSpot;` 과
     `static final List<double> spots = <double>[];` 은 exit 2 이고
     `static final int retryBudget = 3;` 과 `static final String label = 'x';`
     는 지난다(넷 다 실측이고 `flutter analyze` 는 넷 다 무지적이다). 뒤엣
     둘이 지나는 것은 round 6 이 오탐으로 고친 자리이고 **의도한 동작**이다 —
     이 검사가 막는 것은 수식어가 아니라 **무엇이 담기는지 알 수 없는
     타입**이다. round 12 까지 이 문장이 "클래스 안의 `static` 저장소도 둘 수
     없다"라고 적혀 있어서, 그것을 읽은 5.2 가 "`static` 은 전부 막힌다"로
     이해하면 검사와 어긋났다.

     **검사는 두 자리를 서로 다른 방식으로 본다.** 최상위 선언은 **타입이
     아니라 이름을 본다** — 이 폴더의 최상위 선언 이름 집합을 스크립트의
     `LOC_TOP_NAMES` 가 그대로 못 박고, 거기 없는 이름이 하나라도 서면 exit 2 다(갈래도 이름과
     함께 못 박으므로 이름을 그대로 두고 모양만 바꾸는 변경도 걸린다).
     round 11 이 그 문장을 한 번 거짓으로 만들었다: 그 검사의 문장 훑기가 세
     겹 문자열을 몰라서 `'''it's fine'''` 한 줄 뒤를 통째로 삼켰고, 삼켜진
     구간의 최상위 저장소가 조용히 통과했다(파일이 클래스 몸통으로 끝날 때).
     문자열을 알아보는 규칙을 `scripts/hooks/dart-source.sh` 한 자리로 모으고
     훑기가 사본의 전제를 스스로 확인하게 해서 닫았다.
     **phase 5 가 그 목록을 하나 넓혔다** — 4.5 와 5.2 가 글자 그대로 같은
     `FutureProvider.autoDispose<LocationPermissionStatus>` 를 각자 갖고
     있어서 공통 요소 규칙대로 이 폴더로 승격했고(`locationPermissionStatusProvider`),
     그때 `provider` 갈래가 `Provider…` 로만 좁혀 있어 그 모양이 `var` 로
     떨어졌다. 이름을 `var` 로 목록에 넣으면 그 이름이 나중에 무엇이든 담을
     수 있게 열리므로(`final x = <DeviceFix>[];` 도 var 다) 갈래 쪽을 넓혔다:
     이제 `FutureProvider`(`.autoDispose`·`.family` 포함)도 **타입 인자가
     전부 "담을 수 없는 타입"일 때만** 이 갈래다. 실측: 그 선언의 타입 인자를
     `List<DeviceFix>` 로 바꾸면 exit 2, `NotifierProvider` 로 바꾸면 exit 2,
     목록 밖 이름을 하나 더하면 exit 2, 클래스 몸통의 `static DeviceFix?
     lastSpot;` 도 그대로 exit 2 다.
     **막지 않는 것(전부터 그랬고 지금도 같다):** 목록에 **이미 있는 이름**의
     타입 인자를 이 폴더가 스스로 선언한 타입으로 바꾸는 것 — 실측:
     `locationPermissionStatusProvider` 를 `FutureProvider.autoDispose<DeviceFix>`
     로, `locationPermissionGatewayProvider` 를 `Provider<DeviceFix>` 로 바꾸면
     둘 다 exit 0 이다(뒤엣것은 phase 5 이전에도 같았다 — 이 갈래는 폴더가
     선언한 타입을 믿고, 그 타입의 필드 집합은 겹 5 가 따로 잰다).
     클래스·enum·mixin·extension 몸통의 선언은 타입을 보고, 통과하는 것은
     `const`, "담을 수 없는 타입"(변하지 않는 dart:core 기본형 + 이 폴더가
     스스로 선언한 class·enum·mixin 이름 + 함수 타입 typedef)이나 함수 타입의
     `final` 필드, 메서드·생성자와 `=>` 몸통, 몸통 없는 게터 선언, enum 몸통의
     첫 문장인 값 나열이다(애노테이션과 `final` 앞의 `static`·`abstract`·
     `external`·`covariant` 는 걷어 낸 뒤 타입을 본다).
     그 "스스로 선언한 이름"은 **class modifier 가 붙어도 같은 이름으로**
     읽히고(`final class`·`sealed class`·`base class`·`interface class`·
     `abstract final class`·`mixin class`), 타입 매개변수 목록은 이름의
     일부가 아니다(`class Box<T>` → `Box`). **타입 인자를 붙인 인스턴스화까지
     받는 것은 함수 타입 typedef 하나뿐이다**(`Parse<int>` 는 통과, 폴더가
     선언한 class 의 `Box<int>` 는 exit 2 — `Box<DeviceFix>` 가 그대로 통이기
     때문이다). **round 8 의 거부 사유가 이 자리였다:** 이름을 모으는 자리가
     수식어를 `abstract` 하나로 알고 있어서, 이 저장소가 `lib/` 에서 31번 쓰는
     모양(`abstract final class` 16 · `final class` 11 · `sealed class` 4)이
     그 집합에 들어오지 않았고 5.2 가 지을 `sealed class` + `final class`
     조합의 `final AtStadium nearest;` 가 exit 2 였다(`flutter analyze` 는
     무지적). 이제 선언 머리를 읽는 규칙을 훅 스크립트 안에서 **한 번만** 적고
     세 자리(2-c · 타입 이름 모으기 · 최상위 이름 읽기)가 그 함수 하나를 쓴다.
     **지키는 것:** 같은 스크립트의 검사 4). **round 7 이 최상위 규칙을
     타입에서 이름으로 뒤집었다** — round 6 이 오탐 셋을 고치자 round 7 이
     최상위 `void Function(double, double)? coordSink;` 와
     `(double, double)? lastSpot;` 이 그냥 지나가는 것을 찾았고(옛 규칙의 타입
     문자 집합에 괄호가 없었다), 검증자가 그 자리로 실 좌표를 외부 서버에
     보내면서 훅 4종·analyze·시험 665개가 초록불인 것을 재현했다. 뿌리는
     "타입 표기를 문자 집합으로 기술하는 한 다음 표기가 또 남는다"이고, 이
     저장소가 round 4 에서 import 검사에 쓴 것과 같은 처방(허용 목록)을 썼다.
     실측: 최상위에 좌표를 담을 자리를 13가지 표기로 지어 보았고 전부 exit 2
     다(홑 타입·제네릭·함수 타입·레코드·중첩 제네릭·typedef 별칭·dynamic·
     Object·var·타입을 적지 않은 final·late·최상위 게터·최상위 세터).
     round 5 는 이 검사를 **줄에서 문장으로** 옮겼다 — 그 전에는 "두 칸 들여쓴
     클래스 몸통의 선언"만 보고 있어서 네 칸 들여쓴 필드와 한 줄로 쓴 클래스가
     그냥 지나갔다(실측, 그 자리에서 라이브러리 밖으로 실 좌표가 읽혔다).
     같은 라운드에서 `extension type` 과 함수 타입이 아닌 `typedef` 를 허용
     타입에서 뺐다 — 그 둘은 몸통이 없거나 표현 필드가 헤더 괄호 안에 있어서
     "그 타입의 필드가 다시 이 검사를 지난다"는 고리를 끊는다.
     **막지 않는 것:** 함수 몸통 안의 지역 변수와 클로저 캡처(그 자리를 보게
     하면 정당한 지역 변수가 전부 걸린다 — 그쪽은 겹 1 의 파수꾼이 받는다),
     게터(값을 담지 못한다), 그리고 `final String spot;` 같은 문자열 필드
     (String 은 쌓지 못하지만 좌표 하나를 글자로 담을 수는 있다 — 그 값이
     밖으로 나가려면 겹 1·5 를 지나야 한다).
     **round 6·7 이 이 검사의 오탐 다섯을 풀었다** (round 6·7 의 거부 사유).
     round 6: 값 나열 뒤에 멤버가 오는 enum(`enum E { a, b; bool get x =>
     ...; }` — Dart 가 요구하는 그 `;` 를 검사가 값 자리로 읽었다. 이 폴더에
     이미 enum 이 둘 있으므로 게터 한 줄로 커밋과 CI 가 막혔다), `@override`
     가 붙은 필드, 추상 클래스·인터페이스·mixin 의 **몸통 없는 게터 선언**.
     round 7: **타입을 명시한 읽기 전용 provider**(`final Provider<T>
     xProvider = Provider<T>(...)` — 이 저장소의 최상위 provider 23개 중
     5개가 타입을 명시하고, 그중 읽기 전용 `Provider<T>` 둘이 그 모양이다:
     `lib/backend/auth.dart:114`·`lib/backend/user_data.dart:830`), 그리고 **`final` 앞에
     수식어가 오는 필드**(`static final int retryBudget = 3;`·
     `abstract final String id;` 등 — 옛 검사가 타입을 보기도 전에 첫 토막
     만으로 거절했다). 다섯 다 평범한 Dart 이고 `flutter analyze` 무지적이다.
     정탐은 그대로다(실측: `enum E { a, b; static DeviceFix? last; }` 와
     `@override final List<DeviceFix> seen;` 와 `Provider<List<DeviceFix>>`
     는 exit 2).
     **일부러 거절하는 정당한 모양 — 닫힌 목록이 아니다.** round 6·7 의
     구현자가 이 폴더에 평범한 Dart 를 지어 넣어 실측한 것들이고, 다음 하나가
     없다고는 적지 않는다. 까닭은 둘이다: **최상위는 이름이 목록에 없으면**
     타입이 무엇이든 거절하고, **몸통 안은 무엇이 담길지 알 수 없는 자리를**
     거절한다. 최상위 `final RegExp ... = RegExp(...)` 와 최상위
     `final String ... = ...` · 값 타입의 `final List<String> ids;` · 타입을
     적지 않은 `final separator = ' / ';`(추론 타입이라 무엇이 담기는지 알 수
     없고, 허용하면 `final spots = <DeviceFix>[];` 가 함께 열린다) ·
     `late final String name;` 을 비롯한 `late` 필드 전부 · 타입 매개변수
     필드 `final T value;` · 레코드 타입 필드 `final (int, int) span;`.
     우회하지 말고 허용 목록을 넓히고 ADR 을 남길 것(까닭은 그 스크립트
     헤더의 4) 에 적혀 있다).
  5. 경계를 넘는 값(`StadiumVisitResult`)에 좌표가 없고, 후보
     (`StadiumVisitCandidate`)에 팀 id 가 없다. **판정 계층이 화면 계층으로
     내보내는 기록(`StadiumVisitRun`)에도 좌표가 없다** (phase 5 가 연 통로 —
     아래 문단 참조). 두 타입 다 **값을 두는 자리
     집합 자체**를 소스에서 읽어 표와 대조한다 — 결과 타입에 좌표 필드나
     `static` 필드나 좌표 게터를 더하면, 후보 타입에 `homeTeamId` 를 더하면
     빨간불이다.
     **지키는 것:** `test/features/badges/visit_check_test.dart` 의 타입
     파수꾼 넷(후보 타입 쪽이 round 5 에서, `StadiumVisitRun` 쪽이 phase 5
     통합 검증 round 2 에서 생겼다). **round 6 이 그 셋을
     줄에서 문장으로 옮겨 겹 4 와 세기를 맞췄다** — 그 전에는 표가 두 칸
     들여쓰기(`^  `)에 못 박혀 있어서, 결과 타입에 `final DeviceFix? at;` 를
     네 칸 들여쓰고 생성자에 `this.at` 을 더하면 훅 4종·analyze·시험 665개가
     전부 초록불인 채로 라이브러리 밖에서 좌표가 읽혔다(실측). 겹 4 의 훅은
     같은 표기를 이미 막고 있었으므로 두 겹의 세기가 어긋나 있었다.
     **phase 5 가 이 겹이 지키는 통로를 하나 더 만들었다.** 5.2 는 "손에 든
     판정이 언제 난 것인가"를 알아야 해서 `StadiumVisitRun`(시각 하나 +
     참·거짓 하나)을 `lib/features/badges/stadium_visit.dart` 에 두고
     `lib/features/home/` 이 그것을 읽게 했는데, **그 자리는 겹 4 의 훅이
     보지 않는다** — 그 검사의 선언 범위가 `lib/location`·
     `lib/content/kst.dart`·`lib/backend` 뿐이기 때문이다(실측: 그 타입에
     `this.lat`·`this.lng` 를 더해도 훅 4종 exit 0 · `flutter analyze`
     무지적이었다. phase 5 통합 검증 round 2 의 계약 밖 발견). 훅의 범위를
     `lib/features/` 로 넓히는 대신 **같은 파일의 네 번째 타입 파수꾼**으로
     못 박았다 — 훅은 강제 장치라 오탐 하나가 저장소 전체의 커밋과 CI 를
     막고(round 6·7·8 의 거부 사유가 전부 그 오탐이다), 시험은 같은 변이를
     같은 세기로 잡으면서 그 위험이 없다. 실측: 그 변이를 넣으면 시험 둘이
     빨간불이고, 빼면 전부 초록불이다.

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
- **이 폴더는 권한을 다시 묻지 않는다.** 여기서 "묻는다"는 `request()`(OS
  다이얼로그)를 뜻한다 — 2.5 가 온보딩에서 한 번 묻고, 4.1 의 판정은
  `status()`(다이얼로그 없는 조회)만 쓴다. 그 조회 자체는 화면이 필요할 때
  다시 할 수 있고, 그 자리가 `locationPermissionStatusProvider` 다(4.5 의 배지
  탭 안내와 5.2 의 홈 상단이 함께 쓴다 — `request()` 는 그 provider 를 지나지
  않는다). **그 답은 포그라운드 복귀마다 새로 난다** —
  `lib/features/badges/stadium_visit.dart` 의 `StadiumVisitTrigger` 가
  `resumed` 에서 판정을 다시 돌리기 직전에 그 provider 를 무효화한다. 사람이
  OS 설정에서 권한을 끄고(또는 켜고) 돌아오는 갈래를 판정만으로는 알 수 없기
  때문이다: 경기 없는 날의 재판정은 후보 게이트에서 권한을 묻지 않고 끝나므로
  그 답만 갱신되지 않은 채 홈 상단이 옛 권한을 계속 읽었다(phase 5 통합 검증
  round 2 의 REJECT 사유 — 실측으로 권한 조회 횟수가 복귀 전후 1 → 1 이었다).
  되묻는 것은 **복귀당 한 번**이고 여전히 `status()` 뿐이며, 아무도 구독하지
  않는 동안에는 무효화가 그 provider 를 만들지도 않는다(실측: 구독 없는
  `autoDispose` 를 invalidate 해도 생성 횟수가 0 이다). 이 규칙을 재는 자리는
  `test/location/stadium_visit_fix_contract_test.dart` 다 — 판정기를 만드는
  `stadiumVisitCheckerProvider` 가 `status` 대신 `request` 를 쥐면 빨간불이
  된다(그 한 글자가 바뀌면 경기가 있는 날마다 앱을 열 때 OS 다이얼로그가
  뜬다). "나중에 할게요"로 건너뛴 사람에게 다시 묻는 진입점은 아직 저장소
  어디에도 없다 — 그것을 세우는 단계는
  `StadiumVisitReason.permissionMissing` 을 신호로 쓸 수 있다(그 이유는
  **경기가 있는 날에만** 선다).
