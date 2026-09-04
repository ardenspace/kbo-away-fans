/// 구장 방문 판정 (step 4.1) — **좌표가 사는 유일한 자리.**
///
/// `.wellbegun/decisions.md` 2026-09-01 `[L]` 이 정한 판정을 그대로 실현한다:
/// 앱이 열려 있을 때만 하는 포그라운드 판정이고, (1) 그 구장에 그날 경기가
/// 있고 (2) 기기 위치가 구장 좌표 반경 안이며 (3) 경기 시각 기준 시간 창 안일
/// 때 도장이다. 홈·원정은 구분하지 않는다 — 후보([StadiumVisitCandidate])에
/// 팀 id 가 아예 없는 것이 그 계약이고, round 5 부터는 그 필드 집합 자체를
/// 소스로 대조하는 파수꾼이 `test/features/badges/visit_check_test.dart` 에
/// 있다(그 전에는 `final String? homeTeamId = null;` 한 줄을 더해도 훅 4종과
/// 시험 663개가 전부 초록불이었다).
///
/// ## 이 파일이 좌표에 대해 하는 약속과 하지 않는 약속
///
/// **하는 약속:** 이 앱의 코드는 기기 좌표를 서버로 보내지 않고 어디에도
/// 적지 않는다. 그렇게 하려면 **눈에 띄는 의도적 변경**이 필요하다
/// (`.wellbegun/decisions.md` 2026-09-04 `[L]`).
///
/// ### 그 약속을 지키는 것이 어느 세기의 문장인가 — 겹 목록보다 먼저 읽을 것
///
/// 아래에 겹 다섯과 겹마다 "지키는 것"을 적는다. 그 목록을 읽기 전에 그
/// 목록이 무엇을 약속하고 무엇을 약속하지 않는지부터 못 박는다.
///
/// 이 겹들을 지키는 것은 대부분 **소스 텍스트를 보는 검사와 시험**이다.
/// 텍스트를 보는 검사가 실제로 막는 것은 **실수와 무심코**다: 이 계층에
/// import 를 하나 더 들이는 것, 값을 담아 둘 필드를 하나 두는 것, 결과 타입에
/// 좌표 필드를 하나 더하는 것, 후보 타입에 팀 id 를 하나 더하는 것. 전부
/// 사람이 나쁜 뜻 없이 하는 변경이고, 그때 커밋이 막히는 것이 이 검사들의
/// 목적이다.
///
/// **작정하고 그 검사를 피하려는 코드는 막지 못한다.** 텍스트를 보는 검사에는
/// 언제나 같은 일을 하면서 패턴을 비켜 가는 표기가 남고, 그것은 정규식을 더
/// 촘촘히 해서 없앨 수 있는 성질이 아니다. 4.1 의 fresh 검증이 그것을 세 번
/// 보여 주었다 — round 3·4·5 가 매번 검사를 하나 더 두껍게 했고, 매번 다음
/// 검증자가 그 검사를 비켜 가는 표기를 찾았다. round 5 가 찾은 넷은 별칭과
/// 점 사이의 줄바꿈, 네 칸 들여쓴 클래스 필드, 한 줄로 쓴 클래스, 그리고
/// 허용된 파일(`../content/kst.dart`)에 공개 함수 하나 더하기다. 이번에 그 넷을
/// 전부 막았지만 **다섯 번째가 없다고는 적지 않는다** — 이 라운드의 구현자도
/// 스스로 공격해서 하나를 더 찾았고, 아래 겹 1 의 "지키지 않는 것"에 그대로
/// 적어 두었다.
///
/// 그런 우회를 실제로 막는 것은 검사가 아니라 **코드 리뷰**다. 그리고 그런
/// 코드는 눈에 띈다 — 별칭과 점 사이에 줄바꿈을 넣거나, 이 저장소의 포매팅
/// 관례를 벗어나 네 칸을 들여쓰거나, 열 0 을 블록 주석으로 여는 선언은
/// 리뷰에서 그냥 지나가지 않는다. 그것이 위 "하는 약속"의 문장이 **"불가능
/// 하다"가 아니라 "눈에 띄는 의도적 변경이 필요하다"인 까닭**이다.
///
/// 그래서 아래 "지키는 것" 목록이 약속하는 것은 **"이 갈래는 실수로 지나갈 수
/// 없다"**이지 **"이 갈래는 누구도 지날 수 없다"**가 아니다. 두 문장의 세기를
/// 섞지 말 것 — round 3·4·5 의 REJECT 는 전부 그 섞임이었다.
///
/// **다음에 이 문단을 고치는 사람에게.** 새 표기 우회를 하나 찾았다고 해서
/// 이 문단이 거짓이 되는 것은 아니다: 그런 우회는 이 문단이 이미 인정한 범위
/// 안이고, 그것을 막으려고 정규식을 한 겹 더 씌우는 것은 지난 세 라운드가
/// 이미 해 본 일이다. 값어치가 있는 것은 다른 쪽이다 — **실수로 지나갈 수
/// 있는 갈래**(사람이 나쁜 뜻 없이 쓸 법한 모양인데 검사가 놓치는 자리)를
/// 찾았다면 그것은 고칠 값어치가 있다. 보고할 때 그 둘을 구분해서 적을 것.
///
/// **그리고 세 번째 방향이 round 6 의 거부 사유였다: 오탐.** 겹 4 의 검사가
/// 평범한 Dart 세 모양을 잡는데, 그 검사와 이 문서가 "일부러 거절하는 정당한
/// 모양은 아래 **둘**"이라고 **닫힌 목록**으로 적어 두어서 그 문장이
/// 거짓이었다. 그 검사는 CI 에도 걸려 있으므로 오탐은 로컬 훅뿐 아니라 CI 도
/// 막는다. 그래서 이 문서의 열거는 열린 모양으로 다시 썼다 — **무엇을
/// 열거하든 그것이 전부라고 단언하기 전에, 실제로 그것이 전부인지 확인했는지
/// 자문할 것.** 확인하지 않았다면 열린 모양으로 쓸 것.
///
/// ### 겹 다섯
///
/// 아래의 "지키는 것"은 전부 위반을 실제로 만들어 빨간불(시험) 또는 exit
/// 2(훅)를 확인한 것이고, "지키지 않는 것"은 실제로 우회를 써 보고 초록불인
/// 것을 확인한 자리다.
///
/// 1. **좌표를 얻는 통로가 이 라이브러리 안에서만 보인다.** 기기의 좌표를
///    실제로 읽는 자리는 아래 [_readDeviceFix] 하나이고 이름이 `_` 로 시작해
///    다른 라이브러리에서 부를 수 없다. 그 통로를 들고 도는
///    [StadiumVisitChecker] 도 그것을 **private 필드**로만 쥔다 — 생성자로
///    넣을 수는 있어도(시험이 갈아 끼우는 이음매) 밖에서 다시 꺼내 부를 수는
///    없어서, `stadiumVisitCheckerProvider` 를 읽은 쪽이 손에 넣는 것은
///    "판정을 한 번 돌린다"는 능력뿐이다.
///
///    *지키는 것:* Dart 의 `_` 가시성(구조)과, 그 구조가 그대로 서 있는지를
///    소스로 대조하는 `test/features/badges/visit_check_test.dart` 의 겹 1
///    파수꾼 일곱. **일곱 다 폴더 전체를 본다** — round 7 에서 뒤의 넷을
///    `visit_check.dart` 한 파일에서 폴더로 넓혔다(그 전에는 이 폴더에 파일이
///    하나 더 생기는 순간 그 넷이 새 파일에 닿지 않았고, 5.2 가 그 자리다).
///    (a) 이 폴더에 `part`·`part of` 가 없다(그래야 "파일 하나가 라이브러리
///    하나"라는 전제가 선다), (b) geolocator 를 들이는 **모든 별칭**을 만지는
///    최상위 선언이 [_readDeviceFix] **하나뿐이다**(별칭 없는 import 자체가
///    빨간불이다 — 접두어가 없으면 표지가 지워진다), (c) [_readDeviceFix] 를
///    이름으로 부르는 최상위 선언은 그 함수 자신과
///    `stadiumVisitCheckerProvider` 둘뿐이다, (d) `_readFix` 를 이름으로 쓰는
///    줄은 정확히 셋이다(필드 선언·생성자 초기화·[StadiumVisitChecker.check]
///    안의 호출), (e) 밖에서 값을 건네받는 두 서명
///    ([StadiumVisitChecker.check] 와 [judgeStadiumVisit])이 소스 텍스트
///    그대로이고 폴더에서 **각각 한 번씩만** 선다, (f) [StadiumVisitChecker]
///    가 값을 두는 자리는 `readPermission` 과 `_readFix` 둘뿐이다(그 클래스를
///    선언하는 파일이 폴더에 하나라는 것까지 함께 잰다), (g) **[_readDeviceFix]
///    의 몸통이 그대로다.**
///
///    (g) 가 round 7 에서 생겼다. 그 전까지 (a)~(f) 는 좌표를 **얻는 자리가
///    어디인지**만 보고 있었고 **그 자리 안에서 좌표에 무엇을 하는지**는 아무
///    시험도 보지 않았다 — round 7 의 검증자가 정확히 그 틈으로 실 좌표를
///    내보냈다(최상위에 함수 타입 변수를 하나 두고 이 함수 몸통에서 그것을
///    부르는 두 줄). 첫 줄은 이제 겹 4 의 훅이 이름 목록으로 받고, 둘째 줄이
///    들어간 몸통을 (g) 가 받는다. (g) 가 재는 성질은 "기기에서 온 좌표를
///    만지는 줄이 이 함수 몸통에 있는 그 목록 그대로다"이고, 재지 않는 것은
///    같은 일을 하는 **다른 표기**다(소스 텍스트 대조의 세기다).
///
///    **round 5 가 (b) 를 두 곳 고쳤다.** 앞엣것이 검증자가 찾은 우회이고,
///    뒤엣것은 그것을 고치면서 함께 보인 두 걸음짜리 갈래다.
///
///    · 옛 파수꾼은 별칭과 점이 **한 줄 안에 붙어** 있을 때만 표지가 섰다
///      (`line.contains('$prefix.')`). 그래서 아래 표기가 훅 4종과 시험
///      663개를 전부 통과했고, 검증자가 이것을 끝까지 이어 `lib/features/
///      badges/` 에서 실 좌표를 외부 서버로 보내면서 `flutter analyze`·훅
///      4종·시험 663개가 전부 초록불인 것을 확인했다:
///
///      ```dart
///      final p = await geo
///          .Geolocator
///          .getCurrentPosition();
///      ```
///
///      이제 파수꾼은 한 선언이 차지하는 줄을 전부 이어 붙인 뒤 **점 둘레의
///      공백과 줄바꿈만 지우고** 표지를 찾는다. 위 표기도, 별칭과 점 사이에
///      공백을 넣는 변종도, 이름을 다음 줄로 내린 표기도 빨간불이다(실측).
///
///    · 옛 파수꾼의 조건은 "표지를 만지는 선언이 `_` 로 시작하면 된다"였다.
///      그러면 private 헬퍼를 하나 더 두고(`_wrap`) 그것을 공개 함수가 부르는
///      두 걸음짜리 갈래가 통째로 열린다. 이제 그 선언이 [_readDeviceFix]
///      **하나여야** 하므로 첫 걸음에서 걸리고, 둘째 걸음은 (c) 가 받는다.
///
///    실측 빨간불(round 3 의 넷, round 4 의 여덟, round 5 의 다섯):
///    `_readDeviceFix` 를 공개 이름으로 개명 · 공개 래퍼(`Future<DeviceFix?>
///    readFixNow() => _readDeviceFix();`) 추가 · 새 공개 함수에서 플러그인
///    직접 호출 · `_readFix` 를 public 필드로 되돌리기 · 기존 import 를 둔 채
///    `as gps;` 별칭을 하나 더 들여 공개 함수에서 부르기 · 별칭 없는
///    geolocator import 를 하나 더 · **이 폴더의 새 파일**에서 별칭으로 직접
///    호출 · `part` 파일로 통로를 공개 이름으로 다시 내보내기 ·
///    `Provider<DeviceFixReader>` 의 클로저가 통로를 실어 내보내기 ·
///    `check` 에 `void Function(String)? spy` 인자를 더해 실 좌표를 부르는
///    쪽에 넘기기 · 판정기에 공개 메서드(`peek() => _readFix();`)를 더하기 ·
///    [judgeStadiumVisit] 에 같은 sink 인자를 더하기 · 별칭과 점 사이의
///    줄바꿈 · 별칭과 점 사이의 공백 · 이름을 다음 줄로 내린 공개 함수 ·
///    private 헬퍼 + 공개 래퍼의 두 걸음 · **이 폴더의 새 파일**에서 줄바꿈
///    별칭으로 호출.
///
///    (round 3 이전에는 이 겹을 재는 것이 **하나도 없었고**, round 4 이전에는
///    파수꾼이 **파일 하나와 별칭 하나**만 보고 있었다.)
///
///    **round 6 이 (b) 의 폴더 훑기를 재귀로 고쳤다.** 그 전에는 폴더를 한
///    겹만 훑어서 `lib/location/` 의 **하위 폴더**가 통째로 시야 밖이었다 —
///    짝인 `check-no-location-upload.sh` 는 `find` 로 처음부터 재귀적으로
///    보고 있었으므로 훅과 파수꾼의 시야가 갈려 있었다. 실측: 하위 폴더에
///    줄바꿈 별칭으로 좌표를 읽는 공개 함수를 둔 파일을 하나 두면 옛
///    파수꾼은 초록불이고 고친 뒤에는 빨간불이다(그동안 그 자리를 실제로
///    막고 있던 것은 `check-firebase-import-boundary.sh` 였다 — 같은 파일에
///    exit 2 다). 5.2 가 하위 폴더를 만들면 그 어긋남이 곧 구멍이 된다.
///
///    *지키지 않는 것:* 새 private 통로를 하나 더 두는 것 자체는 이 겹이
///    막지 않는다 — 다만 그 통로가 geolocator 를 만지면 (b) 가 잡으므로,
///    남는 것은 이미 손에 있는 좌표를 private 끼리 주고받는 경우다. (e) 가
///    재는 것은 **그 두 서명의 소스 텍스트**라, 서명을 그대로 둔 채 private
///    헬퍼끼리 좌표를 주고받는 것은 보지 않는다(그쪽은 보낼 수단도 겹 3,
///    담아 둘 자리도 겹 4 없다는 쪽이 받는다).
///
///    그리고 **이 파수꾼은 선언을 열 0 의 머리 줄로 알아본다.** 열 0 이 블록
///    주석으로 시작하는 선언은 머리로 읽히지 않아 **바로 앞 선언의 이름을
///    물려받으므로**, 그것을 [_readDeviceFix] 바로 뒤에 두면 이 파수꾼을
///    지난다. 이 라운드의 구현자가 스스로 공격해 확인했다 — 아래가 시험
///    665개와 훅 4종을 전부 통과한다:
///
///    ```dart
///    /*x*/Future<DeviceFix?> readSneaky() async { ... geo.Geolocator ... }
///    ```
///
///    정규식을 한 겹 더 씌우지 않고 여기에 적어 두는 쪽을 골랐다: 열 0 을
///    블록 주석으로 여는 선언은 실수로 나오는 모양이 아니라 위 문단이 말한
///    "리뷰에서 눈에 띄는" 코드의 전형이고, 그것을 잡으려고 머리 줄 판정을
///    넓히면 다음 표기가 또 나온다.
/// 2. **플러그인을 직접 부르는 길이 이 파일 하나로 못 박혀 있다.** 위 통로
///    밖에서 좌표를 얻으려면 `package:geolocator` 를 직접 부르는 수밖에
///    없는데, 그 import 를 `lib/` 안에서 이 **파일**로 좁혀 둔다.
///
///    *지키는 것:* `scripts/hooks/check-firebase-import-boundary.sh`
///    (PostToolUse + pre-commit + **CI**). 실측: 그 import 를 다른 파일에
///    두면 exit 2. 같은 훅이 `export 'package:geolocator/geolocator.dart';`
///    도 잡는다 — round 4 가 확인한 갈래다: 그 한 줄이 `location.dart` 에
///    있으면 폴더 밖의 파일이 `lib/location/location.dart` 만 import 하고
///    `Geolocator` 를 접두어 없이 부를 수 있고, `flutter analyze` 는
///    초록불이다. 같은 자리를 `check-no-location-upload.sh` 의 검사 3) 도
///    함께 받는다.
/// 3. **이 계층은 값을 밖으로 내보낼 수단을 갖지 않는다.** `lib/location/` 이
///    import 할 수 있는 것은 **허용 목록 여섯**뿐이고(`dart:math` ·
///    `package:flutter_riverpod` · `package:geolocator` ·
///    권한 플러그인(그 import 는 `location.dart` 에만 있다) ·
///    `../content/kst.dart` · 같은 폴더의 파일), `export`·`part` 는 쓰지
///    않는다. 그래서 이 폴더 안에서 좌표를 손에 쥐고 있어도 보낼 곳이 없다.
///
///    **허용 목록으로 뒤집은 것이 round 4 가 막은 실제 구멍이다.** 옛 검사는
///    이름을 아는 업로드 폴더 둘(`lib/backend/`·`lib/analytics/`)만 막고
///    있었는데, 같은 힘을 가진 계층이 둘 더 열려 있었다:
///    `lib/content/content_providers.dart` 가 네트워크 클라이언트를 공개
///    provider(`httpClientProvider`)로 내주고,
///    `lib/weather/weather.dart` 의 `WeatherService.effectAt(lat:, lng:)` 이
///    좌표를 인자로 받아 OpenWeatherMap 에 보낸다. round 4 의 검증자가 이
///    파일에서 그 둘로 실 좌표를 외부 서버에 보내고 훅 4종·`flutter analyze`·
///    시험 660개가 전부 초록불인 것을 재현했다. 이름을 하나씩 늘리는 방식은
///    다섯 번째 계층이 생길 때 또 새므로, 거부 목록을 버렸다.
///
///    *지키는 것:* `scripts/hooks/check-no-location-upload.sh` 의 검사
///    2)·3)·5). 실측 정탐 24종이 exit 2 다 — `../content/content_providers.dart`
///    (상대 경로·패키지 경로 둘 다) · `../weather/weather.dart` ·
///    `lib/analytics/`(상대·패키지·겹따옴표) · `lib/backend/` ·
///    `package:http` · `dart:io` · `dart:async` · `dart:developer` ·
///    `package:flutter/foundation` · `package:flutter/material` ·
///    `package:share_plus` · `package:geolocator_platform_interface` ·
///    `show` 절이 붙은 금지 import · 조건부 import 의 둘째 URI ·
///    **이 폴더의 새 파일**이 하는 금지 import · `export` 지시자 ·
///    `part` 지시자 · `lib/content/kst.dart` 의 `export`·`part`·허용 목록 밖
///    import·공개 이름 하나 더하기, 그리고
///    `print(...)`·`debugPrint(...)`·`Zone.current.print(...)`·
///    `debugPrintSynchronously(...)`·`debugPrintThrottled(...)`.
///
///    **허용 목록의 유일한 폴더 밖 문**인 `../content/kst.dart` 에는 짝 검사가
///    셋 붙는다. round 4 는 그 문에 `export` 가 없다는 것만 보고 있었는데,
///    round 5 의 검증자가 그 옆으로 지나갔다: 그 파일에 **공개 함수를 하나
///    더하고** 그 안에서 `package:http` 로 실 좌표를 외부 서버에 보내는 것이
///    훅 4종과 시험 663개를 전부 통과했다. 이제 셋을 함께 본다 —
///    (a) `export`·`part` 가 없다, (b) 그 파일 자신의 import 도 허용
///    목록(`models.dart`) 안에만 있다, (c) 그 파일이 내미는 **최상위 공개
///    이름 집합**이 넷 그대로다(`kstOffset`·`kstDateOf`·`gameDateOf`·
///    `gameStartsAt`). 셋 다 실측으로 exit 2 를 확인했다.
///
///    **round 6 이 그 짝 검사 셋의 침묵을 없앴다.** 셋이 `[ -f ]` 가드 뒤에
///    있어서, 그 파일이 옮겨지거나 이름이 바뀌면 셋이 통째로 **조용히**
///    건너뛰어지고 훅은 exit 0 이었다(round 6 의 지휘자가
///    `git mv lib/content/kst.dart lib/content/kst2.dart` 로 재현했다). 이제
///    스크립트가 자기가 볼 세 자리(`lib/backend`·`lib/location`·
///    `lib/content/kst.dart`)의 존재를 먼저 단언하므로, 자리가 사라지면
///    검사가 침묵하는 대신 exit 2 로 드러난다(실측).
///
///    허용 목록이 함께 닫은 것이 round 4 가 찾은 콘솔 우회 둘이다:
///    `Zone.current.print(...)` 와 `debugPrintSynchronously(...)` 는 각각
///    `dart:async` 와 `package:flutter/foundation` 을 필요로 하는데 둘 다
///    목록 밖이다. 실측으로 확인했다 — 지금 이 폴더가 들이는 것들은
///    `Zone`·`Completer`·`debugPrint`·`debugPrintSynchronously`·`Clipboard`
///    를 하나도 재수출하지 않아 그 이름이 전부 undefined 다
///    (`flutter analyze` 로 재현).
///
///    *지키지 않는 것:* `dart:core` 는 막을 수 없다 — import 없이 서는 유일한
///    라이브러리이고 거기 `print` 가 있다. 검사 5) 는 그것을 **이름을 그대로
///    부르는 줄**로만 잡으므로, 함수를 변수에 담아 부르는 우회
///    (`final logger = print; logger('...');`)는 잡지 못한다 — 실측으로
///    확인했다(훅 4종이 전부 exit 0). 그리고 kst.dart 짝 검사 셋은 **그 파일
///    자신의 텍스트**만 보므로, 그 파일이 부르는 `lib/content/models.dart`
///    안쪽까지는 보지 않는다. 허용 목록의 패키지 다섯이 새 버전에서 무언가를
///    더 재수출하는 것도 이 검사들의 시야 밖이다.
/// 4. **이 계층에는 값을 남겨 둘 자리가 없다.** 이 폴더에는 최상위 선언으로
///    값을 담아 두는 자리도, 클래스 안의 `static` 저장소도, **좌표를 쌓을 수
///    있는 인스턴스 필드도** 둘 수 없다.
///
///    *지키는 것:* 같은 스크립트의 검사 4). 그 검사는 **두 자리를 서로 다른
///    방식으로 본다.**
///
///    · **최상위 선언은 타입이 아니라 이름을 본다** (round 7 에서 뒤집었다).
///      이 폴더의 최상위 선언 이름 집합을 스크립트의 `LOC_TOP_NAMES` 가 그대로
///      못 박고, 거기 없는 이름이 하나라도 서면 exit 2 다. 갈래(type·func·
///      getter·setter·const·provider·var)도 이름과 함께 못 박으므로, 이름을
///      그대로 두고 모양만 바꾸는 변경도 걸린다(실측: `const double
///      kStadiumVisitRadiusMeters` 를 `double` 저장소로 바꾸면 const→var,
///      `stadiumVisitCheckerProvider` 의 타입 인자를 `List<DeviceFix>` 로
///      바꾸면 provider→var 로 떨어져 둘 다 exit 2).
///
///      **뒤집은 까닭.** round 6 이 오탐 셋을 고치자 round 7 이 정탐 둘을
///      찾았다: 최상위 `void Function(double, double)? coordSink;` 와
///      `(double, double)? lastSpot;` 이 그냥 지나갔다(옛 규칙의 타입 문자
///      집합에 괄호가 없었다). 둘 다 표기 우회가 아니라 평범한 Dart 3 이고,
///      검증자가 그 자리로 실 좌표를 외부 서버에 보내면서 훅 4종·
///      `flutter analyze`·시험 665개가 전부 초록불인 것을 재현했다. 뿌리는
///      하나다 — **타입 표기를 문자 집합으로 기술하는 한 다음 표기가 또
///      남는다.** 같은 뿌리를 이 저장소는 round 4 에서 한 번 풀었고(import
///      검사를 거부 목록에서 허용 목록으로 뒤집었다), 이름 목록은 그 방식이다.
///      실측: 최상위에 좌표를 담을 자리를 13가지 표기로 지어 보았고 전부
///      exit 2 다 — 홑 타입·제네릭·함수 타입·레코드·중첩 제네릭·typedef
///      별칭·dynamic·Object·var·타입을 적지 않은 final·late·최상위 게터·
///      최상위 세터. 이름을 읽지 못한 문장은 "?" 로 나가 목록과 어긋나므로
///      **막히는 쪽으로 틀린다.**
///
///      대가도 적어 둔다: 이 폴더에 파일이나 헬퍼 클래스를 하나 더할 때마다
///      그 목록을 함께 고쳐야 한다. 우회하지 말고 목록을 넓히고 ADR 을 남길
///      것 — **그 눈에 띔이 이 검사의 목적이다.**
///
///    · **클래스·enum·mixin·extension 몸통의 선언은 타입을 본다.** 여기는
///      이름으로 못 박기 어렵다(클래스가 여럿이고 필드는 늘어난다). 통과하는
///      것은 `const`, "담을 수 없는 타입"이나 함수 타입(`... Function(...)`)의
///      `final` 필드, 메서드·생성자와 `=>` 로 몸통을 쓰는 선언, 몸통 없는
///      게터 선언, 그리고 enum 몸통의 첫 문장인 값 나열이다. 선언 앞의
///      애노테이션과 `final` 앞의 수식어(`static`·`abstract`·`external`·
///      `covariant`)는 걷어 낸 뒤 타입을 본다. "담을 수 없는 타입"은 값이
///      변하지 않는 dart:core 기본형(`bool`·`double`·`int`·`num`·`String`·
///      `Duration`·`DateTime`)과 **이 폴더가 스스로 선언한 class·enum·mixin
///      이름들**(그리고 함수 타입 typedef)의 합이다 — 그것을 허용해도 고리가
///      닫히는 까닭은 그 타입의 필드가 다시 이 검사를 지나기 때문이고, 폴더
///      밖의 이름을 막으므로 `Provider<StringBuffer>`·`Provider<List>` 같은
///      "홑 식별자인데 변경 가능한 통"이 함께 닫힌다.
///
///      **이 자리를 이 검사만 보고 있는 것이 아니다.** 경계를 넘는 세 타입
///      ([StadiumVisitResult]·[StadiumVisitCandidate]·[StadiumVisitChecker])의
///      **필드 집합 자체**는 겹 1·5 의 파수꾼이 소스에서 읽어 표와 대조한다.
///      그래서 이 검사가 타입으로 거르는 넓은 자리와, 시험이 이름으로 못 박는
///      좁은 자리가 함께 선다.
///
///    **round 5 가 이 검사를 줄에서 문장으로 옮겼다.** 옛 검사는 "열 0 의
///    선언 · 어느 깊이든 `static` · **두 칸** 들여쓴 클래스 몸통의 선언"만
///    보았고, 그래서 아래 둘이 그냥 지나갔다(지휘자 재현, 둘 다 exit 0 이고
///    검증자가 라이브러리 밖에서 실 좌표 `37.5121, 127.0719` 를 읽어 냈다):
///
///    ```dart
///    class SpotLog {
///        final List<DeviceFix> seen = <DeviceFix>[];
///    }
///    class SpotLog2 { static final List<DeviceFix> seen = <DeviceFix>[]; }
///    ```
///
///    `dart format` 을 게이트로 세워 들여쓰기를 강제하는 길은 이 저장소에
///    없다(pre-commit 에도 CI 에도 없고, 지금 트리는 포매터 버전 차이로
///    `dart format --set-exit-if-changed` 에 74개 파일이 걸린다). 그래서
///    검사가 파일을 한 번 훑으며 주석과 문자열을 걷어 내고, 괄호 밖의
///    중괄호로 깊이를 세고, 괄호 밖의 `;` 와 `{` 에서 문장을 끊어 공백을
///    하나로 접은 뒤 본다. "클래스 몸통 안"이 들여쓰기가 아니라 **중괄호
///    깊이**로 정해져서, 네 칸을 들여쓰든 여덟 칸을 들여쓰든 탭을 쓰든 한
///    줄로 쓰든 같은 자리로 온다(넷 다 실측으로 exit 2).
///
///    실측 정탐. round 7 이 이 폴더에 좌표를 담을 자리를 **51갈래**로 지어
///    넣어 전부 exit 2 인 것을 다시 쟀다(짝으로 오탐 후보 19갈래가 전부
///    exit 0 이다. BSD awk 와 ubuntu 의 mawk 가 70갈래 전부에서 같은 답을
///    낸다 — CI 가 mawk 다). 최상위 쪽 13갈래는 위에 적었고,
///    그중 몸통·provider 쪽은 `Provider<List<DeviceFix>>`·
///    `Provider<Map<String, DeviceFix>>`·`Provider<StringBuffer>`·
///    `Provider<List>`·`StateProvider`·`FutureProvider`·`NotifierProvider`·
///    타입 인자를 적지 않은 `Provider((ref) => ...)`, 두 칸 들여쓴
///    `static DeviceFix? lastSpot;`·`static final List<DeviceFix> spots = [];`,
///    인스턴스 필드 `final List<DeviceFix> seen = [];`·`DeviceFix? last;`·
///    `late DeviceFix last;`·`var count = 0;`·
///    `final StringBuffer log = StringBuffer();`·`final T value;`·
///    `final (int, int) span;`·`final separator = ' / ';`·
///    `@override final List<DeviceFix> seen;`·
///    `enum E { a, b; static DeviceFix? last; }`, 네 칸·여덟 칸·탭 들여쓰기와
///    한 줄 클래스(인스턴스·static 둘 다) · 토막 사이 블록 주석 · `mixin`
///    몸통 · `abstract class` 안의 static · `extension` 안의 static · 선언을
///    세 줄로 쪼갠 필드 · `extension type` 표현 필드 · `typedef` 별칭 필드,
///    그리고 round 4 의 검증자가 라이브러리 밖에서 실 좌표를 읽어 낸 조합
///    그대로(`class SpotLog { final List<DeviceFix> seen = []; ... }` +
///    `Provider<SpotLog>`).
///
///    **round 6·7 이 이 검사의 오탐 다섯을 풀었다** (round 6·7 의 거부 사유).
///    다섯 다 평범한 Dart 이고 `flutter analyze` 무지적인데 exit 2 였다.
///    round 6: 값 나열 뒤에 멤버가 오는 enum(`enum E { a, b; bool get x =>
///    ...; }` — Dart 가 요구하는 그 `;` 를 검사가 값 자리로 읽었다. 이 폴더에
///    이미 enum 이 둘 있으므로 게터 한 줄을 더하는 것만으로 커밋과 CI 가
///    막혔다), `@override` 가 붙은 필드, 추상 클래스·인터페이스·mixin 의
///    몸통 없는 게터 선언. round 7: **타입을 명시한 읽기 전용 provider**
///    (`final Provider<T> xProvider = Provider<T>(...)` — 이 저장소의 최상위
///    provider 18개 중 5개가 타입을 명시하고, 그중 읽기 전용 `Provider<T>` 둘이
///    그 모양이다: `lib/backend/auth.dart:114`·`lib/backend/user_data.dart:830`.
///    나머지 셋은 StreamProvider·AsyncNotifierProvider 라 타입 표기와 무관하게
///    이 검사가 일부러 거절한다. 옛 허용 규칙이 선언의 앞부분까지
///    `^final <이름> = Provider…` 로 못 박고 있었다), 그리고
///    **`final` 앞에 수식어가 오는 필드**(`static final int retryBudget = 3;`·
///    `static final String suffix`·`static final Duration gap`·
///    `static final int Function(int) doubler`·`abstract final String id;` —
///    옛 검사가 타입을 보기도 전에 첫 토막만으로 거절했다). 다섯 다 이제
///    지나가고, 정탐은 그대로다(실측).
///
///    *지키지 않는 것:* **함수 몸통 안의 지역 변수와 클로저 캡처**는 보지
///    않는다(그 자리를 보게 하면 이 파일의 정당한 지역 변수가 전부 걸린다).
///    실측으로 `Provider<DeviceFixReader>` 의 클로저가 좌표를 붙잡는 변이를
///    만들어 보았는데, 그것을 빨간불로 잡은 것은 이 검사가 아니라 겹 1 의
///    파수꾼이었다. 그리고 `final String spot;` 같은 **문자열 필드**는
///    통과한다 — String 은 변하지 않아 쌓을 수 없지만 좌표 하나를 글자로
///    담을 수는 있다(그 값이 밖으로 나가려면 겹 1·5 를 지나야 한다).
///
///    **이 검사가 일부러 거절하는 정당한 모양**도 적어 둔다(5.2 가 여기
///    걸리면 까닭을 여기서 찾으라고). **닫힌 목록이 아니다** — round 6·7 의
///    구현자가 이 폴더에 평범한 Dart 를 지어 넣어 실측한 것들이고, 다음
///    하나가 없다고는 적지 않는다. 까닭은 둘이다. **최상위는 이름이 목록에
///    없으면 거절한다** — 타입이 무엇이든, `final RegExp ... = RegExp(...)`
///    도 `final String ... = ...` 도 목록을 넓히기 전에는 거절이다.
///    **몸통 안은 무엇이 담길지 알 수 없는 자리를 거절한다** — 값 타입의
///    `final List<String> ids;`(이 저장소에 실재하는 모양이다:
///    `lib/ui/shared/weather_backdrop.dart:94` 의
///    `static final List<_Drop> _drops`. 그 파일은 이 검사의 범위 밖이지만
///    같은 줄을 이 폴더에 두면 exit 2 다) · 타입을 적지 않은
///    `final separator = ' / ';`(추론 타입이라 무엇이 담기는지 알 수 없고,
///    허용하면 `final spots = <DeviceFix>[];` 가 함께 열린다) ·
///    `late final String name;` 을 비롯한 `late` 필드 전부 · 타입 매개변수
///    필드 `final T value;`(`Box<DeviceFix>` 로 세우면 그대로 좌표를 담는
///    통이다) · 레코드 타입 필드 `final (int, int) span;`. 전부 우회하지 말고
///    허용 목록을 의도적으로 넓히고 ADR 을 남길 것.
/// 5. **경계를 넘는 값에 좌표가 없다.** 이 파일이 밖으로 내보내는 판정 결과
///    [StadiumVisitResult] 는 이유·구장 id·경기 id 와 [StadiumVisitResult.isVisit]
///    뿐이다. [DeviceFix] 는 타입 자체는 공개(시험이 판정 함수에 좌표를 넣어야
///    한다)지만, 위 1번 때문에 **실제 기기 좌표가 담긴 값**은 이 라이브러리
///    밖으로 나가지 않는다.
///
///    *지키는 것:* `test/features/badges/visit_check_test.dart` 의 타입
///    파수꾼 셋 — [StadiumVisitResult] 가 **값을 두는 자리 집합 자체**를 이
///    파일의 소스에서 읽어 표와 대조하고, 짝으로 그 몸통에 좌표 어휘가
///    없음을 재고, round 5 부터 [StadiumVisitCandidate] 의 필드 집합도 같은
///    방식으로 못 박는다. 실측: 결과 타입에 좌표 필드·`static` 필드·좌표
///    게터를 하나씩 더하면 각각 빨간불이고, 후보 타입에
///    `final String? homeTeamId = null;` 한 줄을 더해도 빨간불이다.
///
///    **round 6 이 이 파수꾼을 줄에서 문장으로 옮겼다 — 겹 4 와 세기를 맞춘
///    자리다.** round 5 는 겹 4 의 훅만 문장 단위로 옮기고 이 파수꾼은 두 칸
///    들여쓰기(`^  `)에 못 박힌 채로 두었다. 그래서 [StadiumVisitResult] 에
///    `final DeviceFix? at;` 를 **네 칸** 들여쓰고 생성자에 `this.at` 을
///    더하면 그 필드가 표에 아예 들어오지 않았고, 훅 4종·`flutter analyze`·
///    시험 665개가 전부 초록불인 채로 라이브러리 밖에서 좌표가 읽혔다
///    (round 6 의 검증자 재현). 겹 4 는 같은 표기를 이미 막고 있었으므로 두
///    겹의 세기가 어긋나 있었다. 이제 이 파수꾼도 주석·문자열을 걷어 내고
///    괄호 밖의 중괄호로 깊이를 세어 클래스 몸통의 문장을 끊는다 — 실측으로
///    네 칸·여덟 칸·탭·열 0·한 줄·세 줄로 쪼갠 표기가 전부 빨간불이고, 후보
///    타입과 판정기에 같은 표기로 넣은 변이도 빨간불이다.
///
/// ### 이 검사들이 도는 자리
///
/// PostToolUse 훅(`check-hardcoded-values.sh`·`check-no-location-upload.sh`) ·
/// `pre-commit`(검사 4종 전부) · **CI 의 `conventions` job**. 마지막 것이
/// round 5 에서 배선됐다 — 그 전까지 `check-no-location-upload.sh` 와
/// `check-firebase-import-boundary.sh` 는 로컬 훅에만 걸려 있어서, 훅을
/// 설정하지 않은 클론과 `--no-verify` 커밋과 크론 워크플로의 봇 커밋이 전부
/// 지나갔다. 겹 2·3·4 가 통째로 그 두 검사에 얹혀 있으므로, 그동안 이 문서가
/// "지킨다"라고 적은 것의 실제 강제 범위는 **훅을 설정한 사람의 컴퓨터**뿐
/// 이었다. `.github/workflows/ci.yml` 자신의 3행이 그 까닭을 이미 적어 두고
/// 있었다.
///
/// ### 하지 않는 약속
///
/// **"기기 좌표를 알아내는 것이 구조적으로 불가능하다"고 말하지 않는다.**
/// [StadiumVisitChecker.check] 는 후보 지점을 **부르는 쪽이 지어서** 넣고
/// 결과에 어느 후보가 맞았는지를 담아 돌려주므로, "이 지점 반경 안에 기기가
/// 있는가"를 묻는 신탁(oracle)이다. 자오선·위선 위에 후보를 늘어놓고
/// 정순·역순으로 물으면 원판의 양 끝이 나오고 그 중점이 곧 기기 좌표라,
/// **측위 5회로 오차 0.03m 까지 좁혀진다**
/// (`test/probe/coord_oracle_probe_test.dart` 가 그것을 실행하며, 그 시험이
/// 초록불인 것은 결함이 아니라 기록된 성질이다).
///
/// **다음에 이 문단을 고치는 사람에게.** 위 다섯 겹을 더 두껍게 만드는 것은
/// 좋지만 "불가능하다"를 다시 써 넣지 말 것 — 한 앱 바이너리 안에 위치 기반
/// 참·거짓을 묻는 코드가 있는 한 반복 질의로 좌표는 언제나 좁혀지므로, 그
/// 문장은 어떤 기법을 더해도 참이 되지 않는다. 이미 시도해 본 두 갈래가
/// `.wellbegun/decisions.md` 2026-09-04 `[L]` 에 rejected 로 적혀 있다(위치
/// 계층이 후보 생성을 소유하기 · 후보 개수 상한으로 신탁 비용만 올리기).
/// 이 앱이 하는 약속은 그 절대문이 아니라 위의 "하는 약속" 쪽이다.
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
/// 기기에서 읽은 값이 담긴 채로 이 라이브러리를 벗어나는 길은 앱의 코드에
/// 없다 — 파일 첫 문단의 다섯 겹 참조. 타입 자체가 공개인 것은 순수 판정
/// 함수에 좌표를 넣어 다섯 갈래를 재는 시험 때문이다.
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
  /// **이 메서드가 곧 신탁이다.** 후보를 부르는 쪽이 지어서 넣고 결과가 어느
  /// 후보에 맞았는지를 말해 주므로, 반복해서 물으면 기기 좌표가 좁혀진다 —
  /// 그것을 없애려면 결과에서 "어느 구장"을 지워야 하는데 도장 기능 자체가
  /// 그 해상도를 요구한다(파일 첫 문단의 "하지 않는 약속").
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
/// 계층에는 이 값을 받아 갈 통로가 없다(파일 첫 문단 1번 — 판정 API 를 신탁
/// 으로 쓰는 갈래는 그 문단의 "하지 않는 약속" 쪽이다).
/// SDK 예외를 밖으로 내보내지 않는다 — 무엇이 오든(권한 예외·위치 서비스
/// 꺼짐·상한 초과·플랫폼 오류) null 하나로 접는다. 그 실패 계약을
/// `test/location/stadium_visit_fix_contract_test.dart` 가 geolocator 의
/// 플랫폼 인터페이스를 갈아 끼워 **이 함수 그대로** 잰다.
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
