#!/usr/bin/env bash
# "기기가 어디에 있었는지는 서버로 올리지 않는다"는 개인정보 약속
# (decisions.md 의 데이터 소유권 XL 결정, lib/backend/CLAUDE.md 와
# lib/location/CLAUDE.md 의 같은 절)을 사람의 주의력이 아니라 검사로 지킨다 —
# 이 프로젝트 전용 신설 스크립트 (step 1.9, spec.md Enforcement plan).
#
# ─────────────────────────────────────────────────────────────────────────
# 이 검사들이 막는 것과 막지 못하는 것 — 먼저 읽으십시오.
# ─────────────────────────────────────────────────────────────────────────
#
# 이 검사들은 소스 **텍스트**를 본다. 그래서 이것이 실제로 막는 것은
# **실수와 무심코**다: 좌표를 다루는 계층에 import 를 하나 더 들이는 것,
# 값을 담아 둘 필드를 하나 두는 것, 판정 결과에 좌표 필드를 하나 더하는 것.
# 전부 사람이 나쁜 뜻 없이 하는 변경이고, 그때 커밋이 막히는 것이 이
# 검사의 목적이다.
#
# **작정하고 이 검사를 피하려는 코드는 막지 못한다.** 텍스트를 보는 검사에는
# 언제나 같은 일을 하면서 패턴을 비켜 가는 표기가 남고, 그것은 정규식을 더
# 촘촘히 해서 없앨 수 있는 성질이 아니다. 4.1 의 fresh 검증 round 3·4·5 가
# 그것을 세 번 보여 주었다: 매번 구현자가 검사를 하나 더 두껍게 했고, 매번
# 다음 검증자가 그 검사를 비켜 가는 표기를 찾았다. 실측으로 확인된 것만
# 적으면 별칭과 점 사이의 줄바꿈, 네 칸 들여쓴 클래스 필드, 한 줄로 쓴
# 클래스, 그리고 허용된 파일에 공개 함수 하나 더하기다. 이번 라운드가 그
# 넷을 막았지만, **다섯 번째가 없다고 주장하지 않는다.**
#
# 그런 우회를 실제로 막는 것은 검사가 아니라 **코드 리뷰**다. 그리고 그런
# 코드는 눈에 띈다 — 별칭과 점 사이에 줄바꿈을 넣거나 이 저장소의 포매팅
# 관례를 벗어나 네 칸을 들여쓴 필드는 리뷰에서 그냥 지나가지 않는다. 그것이
# 이 앱이 하는 약속의 정확한 문장이다: "앱의 코드가 좌표를 서버로 보내지
# 않으며, 그렇게 하려면 눈에 띄는 의도적 변경이 필요하다"
# (.wellbegun/decisions.md 2026-09-04 [L]).
#
# 그래서 아래 검사별 설명이 약속하는 것은 **"이 갈래는 실수로 지나갈 수
# 없다"**이지 **"이 갈래는 누구도 지날 수 없다"**가 아니다. 두 문장의 세기가
# 다르다는 것을 지우지 마십시오.
#
# **다음에 이 문단을 고치는 사람에게.** 새 표기 우회를 하나 찾았다고 해서
# 이 문단이 거짓이 되는 것은 아니다 — 그런 우회는 이 문단이 이미 인정한
# 범위 안이고, 그것을 막으려고 정규식을 한 겹 더 씌우는 것은 지난 세
# 라운드가 이미 해 본 일이다. 값어치가 있는 것은 다른 쪽이다: **실수로
# 지나갈 수 있는 갈래**(사람이 나쁜 뜻 없이 쓸 법한 모양인데 검사가 놓치는
# 자리)를 찾았다면 그것은 고치십시오. 보고할 때 둘을 구분해서 적으십시오.
#
# **그리고 반대 방향이 round 6·7 의 거부 사유였다: 오탐.** round 6 에서는
# 검사 4) 가 평범한 Dart 세 모양(값 나열 뒤에 멤버가 오는 enum · `@override`
# 가 붙은 필드 · 몸통 없는 게터 선언)을 잡았고, round 7 에서는 타입을 명시한
# 읽기 전용 provider(`final Provider<T> xProvider = Provider<T>(...)` — 이
# 저장소의 최상위 provider 18개 중 5개가 타입을 명시하고, 그중 읽기 전용
# `Provider<T>` 둘이 그 모양이다)와 `final` 앞에 수식어가
# 오는 필드(`static final int retryBudget = 3;` 등)를 잡았다. 이 검사는 CI 에도
# 걸려 있으므로 오탐은 로컬 훅뿐 아니라 CI 도 막는다.
#
# **round 8 의 거부 사유도 오탐이고, 뿌리는 이 스크립트 자신 안의 어긋남
# 이었다.** 검사 4) 가 "이 폴더가 스스로 선언한 타입"을 모으는 자리는 수식어를
# `abstract` 하나로 알고 있었는데 같은 검사의 topDecl() 은 일곱을 알고 있었다.
# 그래서 Dart 3 의 class modifier 가 붙은 타입이 그 집합에 들어오지 않았고,
# 그 타입의 `final` 필드가 exit 2 였다(실측: `class`·`abstract class` 는
# 통과하고 `final class`·`sealed class`·`base class`·`interface class`·
# `abstract final class` 다섯이 전부 exit 2). 이 저장소가 `lib/` 에서 그 모양을
# **31번** 쓰고(`abstract final class` 16 · `final class` 11 · `sealed class` 4),
# 5.2 가 이 폴더에 지을 모양이 그대로 그것이다(`sealed class CurrentPlace` +
# `final class AtStadium` — `final AtStadium nearest;` 가 exit 2 였고
# `flutter analyze` 는 무지적이었다). 같은 뿌리에서 함께 나온 것이 **제네릭
# 함수 typedef** 다: `typedef Parse<T> = T Function(String raw);` 는 이름 뒤의
# 타입 매개변수 목록 때문에 아예 읽히지 않아 `final Parse<int> parse;` 가
# exit 2 였다(제네릭을 뗀 같은 typedef 는 exit 0 이었다. 저장소에 실재하는
# 모양이다 — lib/content/content_loader.dart:121).
#
# 그래서 이번에는 **선언 머리를 읽는 규칙을 이 스크립트 안에서 한 번만 적고**
# (아래 DECL_MODIFIERS·DECL_KEYWORDS 와 DECL_AWK 의 declHead()), 그것을 세
# 자리가 함께 쓴다: 2-c 의 kst.dart 이름 읽기 · 검사 4) 의 타입 이름 모으기 ·
# 검사 4) 의 topDecl(). **같은 개념을 두 자리에 따로 적으면 어긋남이 다시
# 생긴다 — 이 스크립트를 고칠 때 그것부터 확인하십시오.**
#
# 그리고 round 6 은 이 헤더가 "일부러 거절하는 정당한 모양은 아래 **둘**"이라고
# **닫힌 목록**으로 적어 그 문장이 거짓이었던 것도 함께 거부 사유로 삼았고,
# round 7 은 같은 종류의 닫힌 문장을 하나 더 찾았다(최상위 변수의 허용 집합을
# 넷으로 못 박았는데 함수 타입 변수가 그 넷 중 무엇도 아니면서 통과했다).
# — **무엇을 열거하든 그것이 전부라고 단언하기 전에, 실제로 그것이 전부인지
# 확인했는지 자문하십시오.**
#
# ─────────────────────────────────────────────────────────────────────────
# 검사는 다섯이고 방향이 다르다.
# ─────────────────────────────────────────────────────────────────────────
#
#   1) lib/backend/ 안에 위도·경도로 읽히는 필드명이 없다 (step 1.9).
#      잡는 단어: lat, lng, latitude, longitude, coord — lib/backend/CLAUDE.md 가
#      명시한 필드명 목록과 같다. \b 단어 경계로 잡아서 "calculate"·"translate"
#      같은 부분 문자열을 오탐하지 않는다(Dart 식별자 문자는 [A-Za-z0-9_] 뿐이라
#      \b 는 그 앞뒤가 식별자 문자가 아닐 때만 걸린다). 검색 범위는 이 폴더
#      전체다 — 정당한 좌표 사용(지도·구장 거리 계산)은 전부 이 폴더 밖
#      (lib/ui/shared/stadium_map_view.dart 등)에서 일어나므로 "업로드 경로"만
#      따로 좁히지 않아도 깨끗한 트리는 매치가 없다.
#
#   2) lib/location/ 의 import 는 **허용 목록 안에만** 있다
#      (2026-09-04 round 4 에서 방향을 뒤집었다).
#
#      round 2·3·4 가 같은 자리를 세 번 뚫었다: 2.5 는 lib/backend/ 만 막았고,
#      round 3 은 lib/analytics/ 를 더했고, round 4 는 그 둘 밖에서
#      lib/content/content_providers.dart 의 `httpClientProvider`(네트워크
#      클라이언트를 공개 provider 로 내준다)와 lib/weather/weather.dart 의
#      `WeatherService.effectAt(lat:, lng:)`(좌표를 인자로 받아 OpenWeatherMap
#      에 보낸다)로 실 좌표를 외부 서버에 보내고 훅 4종·flutter analyze·시험
#      660개가 전부 초록불인 것을 재현했다. **이름을 하나씩 늘리는 방식은
#      다섯 번째 계층이 생길 때 또 샌다** — 그래서 거부 목록을 버리고 이
#      폴더가 import 할 수 있는 것을 열거한다.
#
#      허용 목록은 **지금 이 폴더가 실제로 쓰는 것**뿐이다. 새 import 가
#      필요해지면 그때 이 목록을 의도적으로 넓히고 ADR 을 남기게 되는데,
#      그 눈에 띔이 이 검사의 목적이다.
#
#      **허용 목록이 함께 닫는 것.** 이 폴더에서 dart:async·flutter/foundation
#      이 빠지면서, round 4 가 찾은 콘솔 우회 둘(`Zone.current.print(...)` ·
#      `debugPrintSynchronously(...)`)도 함께 막힌다 — 실측으로 확인했다:
#      지금 이 폴더가 들이는 것들(flutter_riverpod·geolocator·
#      permission_handler·dart:math·../content/kst.dart)은 Zone·Completer·
#      debugPrint·debugPrintSynchronously·Clipboard 를 하나도 재수출하지 않아
#      그 이름들이 전부 undefined 다(flutter analyze 로 재현). dart:core 만이
#      import 없이 서고, 그쪽에서 남는 것은 `print` 하나라 검사 5) 가 받는다.
#
#      **허용 목록의 유일한 폴더 밖 문**인 ../content/kst.dart 에는 짝 검사가
#      셋 붙는다 (아래 2-a·2-b·2-c). 그 파일이 이 계층의 이름 표면과 도달
#      범위를 함께 정하기 때문이다.
#
#      2-a) 그 파일에 `export`·`part` 가 없다. Dart 의 import 는 전이되지
#           않지만 `export` 는 전이되므로, 그 한 줄이면 이 폴더의 import 을
#           하나도 건드리지 않고 값을 내보내는 패키지가 이 계층에 선다 —
#           round 4 의 구현자가 재현했다: kst.dart 에
#           `export 'package:http/http.dart';` 한 줄과 visit_check.dart 안의
#           `await Client().post(...)` 한 줄로 실 좌표가 외부 서버로 나가는데
#           훅 2종이 exit 0, flutter analyze 도 초록불이었다. `part` 를 함께
#           막는 것은 part 파일이 그 라이브러리의 공개 이름을 늘리는데 아래
#           2-c 가 kst.dart 자신의 텍스트만 읽기 때문이다.
#
#      2-b) 그 파일의 import 도 허용 목록(lib/content/models.dart) 안에만
#           있다. 이름을 하나도 늘리지 않고도 이 문 안쪽에서 네트워크
#           클라이언트를 들이면 좌표가 나가기 때문이다.
#
#      2-c) 그 파일이 내미는 **최상위 공개 이름 집합**이 넷 그대로다
#           (kstOffset·kstDateOf·gameDateOf·gameStartsAt). round 5 의
#           검증자가 이 자리를 뚫었다: 2-a 가 `export` 만 보고 있어서 이
#           파일에 **공개 함수를 하나 더하고** 그 안에서 좌표를 외부 서버로
#           보내는 것이 훅 4종·시험 663개를 전부 통과했다. 이름 집합을 못
#           박으면 그 갈래는 이 검사와 함께 이름 목록까지 고쳐야 지나간다.
#
#   3) lib/location/ 은 `export`·`part`·`part of` 를 쓰지 않는다 (round 4 신설).
#      이 셋은 라이브러리 경계를 넓히는 지시자이고, 오늘 이 폴더에는 하나도
#      없다.
#
#      `export` 를 막는 것은 그것이 **허용 목록을 밖으로 흘리기** 때문이다:
#      `export 'package:geolocator/geolocator.dart';` 는 허용 목록 안의 URI 라
#      import 검사를 통과하는데, 그 한 줄이면 폴더 밖의 어느 파일이든
#      `lib/location/location.dart` 만 import 하고 `Geolocator` 를 직접 부를 수
#      있다(round 4 의 구현자가 재현했고 flutter analyze 가 초록불이었다).
#      그 갈래는 짝 훅(check-firebase-import-boundary.sh)이 grep 으로 이미
#      exit 2 를 내지만, 같은 자리를 두 각도에서 받아 둔다.
#
#      `part` 를 막는 것은 Dart 의 `_` 가 **파일**이 아니라 **라이브러리**
#      가시성이기 때문이다. part 파일을 더하면 그 파일이 같은 라이브러리 안에
#      들어와 `_readDeviceFix` 같은 private 통로를 공개 이름으로 다시 내보낼
#      수 있는데, 그 파일 자신은 geolocator 를 import 하지 않으므로 짝 훅
#      (check-firebase-import-boundary.sh)에도 걸리지 않는다. round 4 의
#      지휘자가 `Future<DeviceFix?> readFixFromPart() => _readDeviceFix();` 로
#      재현해 훅 2종이 exit 0 인 것을 확인했다. 이 폴더의 파일은 각자 하나의
#      라이브러리라는 것이 겹 1·2 가 서는 전제이므로, 그 전제를 검사로 못
#      박는다(짝으로 경계 시험의 겹 1 파수꾼도 같은 것을 잰다).
#
#   4) lib/location/ 에 값을 담아 둘 자리를 두지 않는다 — 최상위 선언도,
#      클래스 안의 static 저장소도, **인스턴스 필드도** (같은 [L] 결정의 짝,
#      round 3 에서 static 을, round 4 에서 인스턴스 필드를, round 5 에서
#      들여쓰기와 줄바꿈에 대한 민감함을 고쳤고, **round 7 에서 최상위 규칙을
#      타입에서 이름으로 뒤집었다**).
#
#      최상위 공개 변수 한 줄(`DeviceFix? lastSpot;`)이면 판정에 쓴 좌표가
#      라이브러리 밖에서 읽히는데, 결과 타입 파수꾼은 StadiumVisitResult 의
#      몸통만 보므로 그것을 놓쳤다(검증자 재현, 시험 644개·analyze 초록불).
#      round 3 이 같은 자리의 구멍 둘을 더 막았고(열 0 만 보던 검사가 놓친
#      `static DeviceFix? lastSpot;` · 담긴 것을 보지 않던
#      `Provider<List<DeviceFix>>`), round 4 가 클래스의 **인스턴스 필드**를
#      막았다.
#
#      **round 5 가 고친 것은 이 검사가 줄과 들여쓰기를 보고 있었다는 것이다.**
#      옛 검사는 "열 0 의 선언 · 어느 깊이든 static · **두 칸** 들여쓴 클래스
#      몸통의 선언"만 보았고, 그래서 아래 둘이 그냥 지나갔다(지휘자 재현,
#      둘 다 exit 0 이었고 검증자가 라이브러리 밖에서 실 좌표를 읽어 냈다):
#
#          class SpotLog {
#              final List<DeviceFix> seen = <DeviceFix>[];
#          }
#          class SpotLog2 { static final List<DeviceFix> seen = <DeviceFix>[]; }
#
#      뒤엣것은 "어느 깊이든 static 을 잡는다"는 문장까지 함께 깼다 — 그 줄의
#      첫 토막이 `class` 라서 static 검사가 아예 닿지 않았다. `dart format` 을
#      게이트로 세워 들여쓰기를 강제하는 길은 이 저장소에 없다(pre-commit 에도
#      .github/workflows/ci.yml 에도 없고, 지금 트리는 포매터 버전 차이로
#      `dart format --set-exit-if-changed` 에 74개 파일이 걸린다).
#
#      그래서 이 검사는 **줄이 아니라 문장(statement)을 본다.** 파일을 한 번
#      훑으면서 주석과 문자열을 걷어 내고, 괄호 밖의 중괄호로 깊이를 세고,
#      괄호 밖의 `;` 와 `{` 에서 문장을 끊어 공백을 하나로 접은 뒤 본다.
#      그러면 "클래스 몸통 안"이 들여쓰기가 아니라 **중괄호 깊이**로 정해져서,
#      네 칸을 들여쓰든 한 줄로 쓰든 같은 자리로 온다. 함수 몸통 안(깊이가
#      같아도 여는 중괄호가 클래스가 아닌 것)은 여전히 보지 않는다 — 그 자리를
#      보게 하면 이 파일의 정당한 지역 변수가 전부 걸린다.
#
#      **이 검사는 두 자리를 서로 다른 방식으로 본다.**
#
#      (a) **최상위 선언 — 타입이 아니라 이름을 본다** (round 7 에서 뒤집었다).
#          이 폴더의 최상위 선언 이름 집합을 아래 LOC_TOP_NAMES 로 그대로 못
#          박는다. 거기 없는 이름이 하나라도 서면 exit 2 다.
#
#          **왜 뒤집었는가.** round 6 이 오탐 셋을 고치자 round 7 이 정탐
#          둘을 찾았다: 최상위 `void Function(double, double)? coordSink;` 와
#          `(double, double)? lastSpot;` 이 그냥 지나갔다(옛 규칙의 타입 문자
#          집합에 괄호가 없었다). 그 둘은 표기 우회가 아니라 평범한 Dart 3
#          이고, 검증자가 그 자리로 실 좌표를 외부 서버에 보내면서 훅 4종·
#          flutter analyze·시험 665개가 전부 초록불인 것을 재현했다. 뿌리는
#          하나다: **타입 표기를 문자 집합으로 기술하는 한 다음 표기가 또
#          남는다.** 같은 뿌리를 이 저장소는 이미 한 번 풀었다 — round 4 가
#          import 검사를 거부 목록에서 허용 목록으로 뒤집었고 그 뒤로 그
#          자리에서는 우회가 나오지 않았다. 이름 목록은 그 방식이다.
#
#          실측(round 7): 최상위에 좌표를 담을 자리를 13가지 표기로 지어
#          보았고 전부 exit 2 였다 — 홑 타입 · 제네릭 · 함수 타입 · 레코드 ·
#          중첩 제네릭 · typedef 별칭 · dynamic · Object · var · 타입을 적지
#          않은 final · late · 최상위 게터 · 최상위 세터.
#
#          **갈래를 이름과 함께 못 박는다.** 이름을 그대로 두고 모양만 바꾸는
#          변경을 받기 위해서다(실측: `const double kStadiumVisitRadiusMeters`
#          를 `double` 저장소로 바꾸면 const→var, `stadiumVisitCheckerProvider`
#          의 타입 인자를 `List<DeviceFix>` 로 바꾸면 provider→var 로 떨어져
#          둘 다 exit 2). 갈래는 여섯이다:
#            type     class·enum·mixin·extension·typedef
#            func     이름 뒤에 매개변수 목록이 오는 선언
#            getter / setter
#            const    const 로 시작하는 값 선언
#            provider `=` 뒤가 `Provider`·`Provider.autoDispose`·
#                     `Provider.family` 이고 타입 인자가 전부 "담을 수 없는
#                     타입"이거나 함수 타입인 것. 타입 인자를 적지 않은
#                     `Provider((ref) => ...)` 과 StateProvider·
#                     NotifierProvider·FutureProvider·StreamProvider 는 이
#                     갈래가 아니다(실측 exit 2).
#            var      그 밖의 값 선언 — 오늘 이 폴더에는 하나도 없다.
#
#          이름을 읽지 못한 문장은 이름이 "?" 로 나가 목록과 어긋난다 —
#          **막히는 쪽으로 틀린다** (2-c 의 DOOR_NAMES 와 같은 방식이다).
#
#          정당하게 최상위 선언을 하나 더할 때는 LOC_TOP_NAMES 를 의도적으로
#          넓히고 ADR 을 남기게 되는데, **그 눈에 띔이 이 검사의 목적이다.**
#          그 대가도 적어 둔다: 이 폴더에 파일이나 헬퍼 클래스를 하나 더할
#          때마다 이 목록을 함께 고쳐야 한다. 5.2 가 그 자리다.
#
#      (b) **클래스·enum·mixin·extension 몸통의 선언 — 타입을 본다.**
#          여기는 이름으로 못 박기 어렵다(클래스가 여럿이고 필드는 늘어난다).
#          그래서 여기서는 허용 목록이 그대로 타입 쪽이다:
#            · `const` (컴파일 시각 값이라 실행 중에 얻은 좌표를 담을 수 없다)
#            · `final` 필드로 타입이 아래 "담을 수 없는 타입"이거나 함수
#              타입(`... Function(...)`)일 때. 함수 타입을 허용하는 것은
#              StadiumVisitChecker 의 두 이음매가 그 모양이기 때문이다.
#            · 메서드·생성자(이름 뒤에 괄호가 오는 선언)와, `=>` 로 몸통을
#              쓰는 선언 전부, 그리고 **몸통 없는 게터 선언**(`String get id;`).
#              게터는 값을 담지 못하고, 읽을 저장소 쪽이 이 검사에 먼저 걸린다.
#            · 선언 앞의 **애노테이션**(`@override final String name;`)은
#              걷어 낸 뒤 판정한다. 걷어 낸 뒤에 보므로
#              `@override final List<DeviceFix> seen;` 은 그대로 exit 2 다.
#            · `final` 앞에 오는 **수식어**(`static`·`abstract`·`external`·
#              `covariant`)도 걷어 낸 뒤 타입을 본다. round 7 의 오탐이 이
#              자리였다: 옛 검사가 타입을 보기도 전에 "첫 토막이 final 이
#              아니면 거절"해서 `static final int retryBudget = 3;`·
#              `static final String suffix`·`static final Duration gap`·
#              `static final int Function(int) doubler`·`abstract final String
#              id;` 가 전부 exit 2 였다(전부 평범한 Dart 이고 analyze 무지적
#              이며, 이 저장소에 선례도 있다 — lib/analytics/analytics.dart:68).
#              **`late` 는 이 집합에 없다** — 값이 생성자 밖의 어느 시점에
#              들어오는 자리라 일부러 거절한다.
#            · **enum 몸통의 첫 문장인 값 나열.** Dart 는 값 목록 뒤에 멤버가
#              하나라도 오면 `;` 를 요구하는데, 그것은 선언이 아니라 값
#              나열이다. 첫 문장 하나만 건너뛰므로 그 뒤의 필드는 전부 그대로
#              이 검사를 지난다(실측: `enum E { a, b; static DeviceFix? last; }`
#              는 exit 2).
#
#          **이 자리를 이 검사만 보고 있는 것이 아니다.** 경계를 넘는 세
#          타입(StadiumVisitResult·StadiumVisitCandidate·StadiumVisitChecker)의
#          **필드 집합 자체**는 test/features/badges/visit_check_test.dart 의
#          파수꾼들이 소스에서 읽어 표와 대조한다. 그래서 이 검사가 타입으로
#          거르는 넓은 자리와, 시험이 이름으로 못 박는 좁은 자리가 함께 선다.
#
#      **round 6 이 푼 오탐 셋**은 위 (b) 의 애노테이션·몸통 없는 게터·enum
#      값 나열이다. 셋 다 평범한 Dart 이고 `flutter analyze` 무지적인데 exit 2
#      였다. 그중 enum 은 오류 메시지가 안내하는 "허용 타입 목록 넓히기"로는
#      고칠 수도 없었다 — 걸린 것이 타입이 아니라 값 나열이었기 때문이다.
#
#      **"담을 수 없는 타입"** 은 (i) 값이 변하지 않는 dart:core 기본형
#      (bool·double·int·num·String·Duration·DateTime) 과 (ii) **이 폴더가
#      스스로 선언한 타입 이름들**의 합이다. 뒤엣것을 읽는 것이 declHead() 라,
#      class modifier 가 붙어도(`final class`·`sealed class`·`base class`·
#      `interface class`·`abstract final class`·`mixin class`) 같은 이름으로
#      읽히고 타입 매개변수 목록은 이름의 일부가 아니다(`class Box<T>` → Box).
#      **타입 인자를 붙인 인스턴스화까지 받는 것은 함수 타입 typedef 하나뿐
#      이다** (`Parse<int>`) — 함수 타입은 무엇으로 인스턴스화해도 값을 담지
#      못하기 때문이다. 그 문장이 참이도록, `=` 오른쪽의 **최상위** 토막이
#      `Function(`·`Function<` 로 시작하는 typedef 만 함수 타입으로 센다:
#      그 전에는 `typedef Bag = List<DeviceFix Function()>;` 이 함수 타입으로
#      세어져 `final Bag b;` 와 `Provider<Bag>` 이 통과했다(실측: round 7 판은
#      둘 다 exit 0, 지금은 둘 다 exit 2). 뒤엣것을 허용해도 고리가 닫히는
#      까닭은, 그 타입의 필드가 다시 이 검사를 지나기 때문이다 —
#      `Provider<SpotLog>` 는 통과해도 `SpotLog` 안의 `List<DeviceFix>` 에서
#      막힌다. 반대로 폴더 밖의 이름은 통과하지 못하므로
#      `Provider<StringBuffer>`·`Provider<List>` 같은 "홑 식별자인데 변경
#      가능한 통"이 함께 닫힌다.
#
#      **이 검사가 일부러 거절하는 정당한 모양** (5.2 가 여기 걸리면 여기서
#      까닭을 찾으라고 적어 둔다). 아래는 **닫힌 목록이 아니다** — round 6·7
#      의 구현자가 lib/location/ 에 평범한 Dart 를 지어 넣어 실측한 것들이고,
#      다음 하나가 없다고는 적지 않는다. 여기 없는 모양이 걸렸다면 그것이
#      오탐인지 정탐인지는 아래 "까닭"의 결로 판단하고, 오탐이면 이 목록에
#      실측과 함께 더하십시오.
#
#      까닭은 둘이다. **최상위는 이름이 목록에 없으면 거절한다** — 타입이
#      무엇이든, `final RegExp kStadiumIdPattern = RegExp(...);` 도
#      `final String probeLabel = ...;` 도 목록을 넓히기 전에는 거절이다.
#      **몸통 안은 무엇이 담길지 알 수 없는 자리를 거절한다.** 실측:
#        · 값 타입의 `final List<String> ids;` 필드 — List 는 담을 수 있는
#          통이라, `final StringBuffer log = StringBuffer();`(실측 정탐)와
#          같은 규칙에 걸린다. 이 저장소에 실재하는 모양이기도 하다
#          (lib/ui/shared/weather_backdrop.dart:94 의
#          `static final List<_Drop> _drops`) — 그 파일은 이 검사의 범위 밖
#          이지만, 같은 줄을 lib/location/ 에 두면 exit 2 다(실측).
#        · **타입을 적지 않은 `final` 필드**(`final separator = ' / ';`) —
#          추론 타입이라 이 검사가 무엇이 담기는지 알 수 없다. 이것을 허용하면
#          `final spots = <DeviceFix>[];` 가 함께 열린다. 타입을 적으십시오.
#        · `late final String name;` 과 `late` 가 붙은 모든 필드 — 값이
#          생성자 밖의 어느 시점에 들어오는 자리다.
#        · 타입 매개변수 필드(`final T value;`) — `Box<DeviceFix>` 로 세우면
#          그대로 좌표를 담는 통이라, "홑 식별자인데 변경 가능한 통"과 같은
#          규칙에 걸린다.
#        · 레코드 타입 필드(`final (int, int) span;`) — 폴더 밖의 모양이고
#          `(double, double)` 이면 좌표 한 쌍 그대로다.
#        · `extension type Box(List<DeviceFix> v) {}` — 표현 필드가 헤더의
#          괄호 안이라 몸통 검사가 닿지 않는데, 최상위 이름 목록이 받는다.
#        · **이 폴더가 선언한 class·enum·mixin 의 제네릭 인스턴스화**
#          (`class Box<T>` 를 두고 `final Box<int> b;`) — 이름은 받아도 타입
#          인자는 받지 않는다. 같은 자리에 `final Box<DeviceFix> b;` 를 적을
#          수 있기 때문이고, 그것도 exit 2 다(둘 다 실측). 위의 타입 매개변수
#          필드(`final T value;`)와 같은 규칙이다. 함수 타입 typedef 만 여기서
#          갈린다 — `Parse<int>` 는 통과한다(위 "담을 수 없는 타입" 참조).
#        · **레코드를 가리키는 typedef 필드**
#          (`typedef Point = ({double lat, double lng});` 를 두고
#          `final Point p;`) — 레코드는 값을 담는 자리이고 이 모양은 위의
#          `final (double, double) span;` 과 같은 것이다. 저장소에 실재하는
#          모양이다(lib/weather/weather.dart:87 의 WeatherPoint; 실측 exit 2).
#      전부 우회하지 말고 위 두 목록을 의도적으로 넓히고 ADR 을 남기십시오.
#      **그 눈에 띔이 이 검사의 목적이다.**
#
#   5) lib/location/ 이 좌표를 콘솔·기기 로그에 적지 않는다 (round 3 신설,
#      round 4 에서 넓혔다). `print` 는 dart:core 라 import 가 없어서 검사
#      2) 의 허용 목록이 원리상 닿지 못하는 유일한 자리다.
#      round 4 가 찾은 두 갈래를 함께 잡도록 패턴을 넓혔다: 이름을 점 뒤에서
#      부르는 꼴(`Zone.current.print(...)`)과 `debugPrint` 로 시작하는 이름
#      전부(`debugPrintSynchronously`·`debugPrintThrottled`). 그 둘은 검사
#      2) 가 dart:async·flutter/foundation 을 허용 목록에서 빼면서 이미
#      닫혔지만, 같은 자리를 두 각도에서 받아 둔다.
#      한계는 정직하게 적어 둔다: 이 검사가 잡는 것은 이름을 그대로 부르는
#      줄뿐이고, 함수를 변수에 담아 부르는 우회는 잡지 못한다.
#
# **이 검사들이 원리적으로 막지 못하는 것.** dart:core 는 막을 수 없다 —
# import 없이 서는 유일한 라이브러리이고 `print` 가 거기 있다(검사 5 가
# 이름으로만 받는다). kst.dart 짝 검사 셋은 그 파일 **자신의** 텍스트만
# 보므로, 그 파일이 부르는 lib/content/models.dart 안쪽까지는 보지 않는다.
# 그리고 판정 API 자체가 신탁이라 반복 질의로 좌표가 좁혀지는 성질은 어떤
# 검사로도 없앨 수 없다 (`.wellbegun/decisions.md` 2026-09-04 `[L]`,
# test/probe/coord_oracle_probe_test.dart).
#
# 위반은 stderr 에 찍고 exit 2 (Claude Code PostToolUse 훅이 읽는 신호).
set -u
cd "$(dirname "$0")/../.." || exit 1

fail=0

# 검사가 볼 자리가 사라지면 **조용히 건너뛰는 대신 드러난다.**
#
# 아래 검사들은 각자 `[ -d ]`·`[ -f ]` 로 자기 자리를 확인하고 들어간다.
# 그 가드만 있으면 자리가 옮겨지거나 이름이 바뀌었을 때 검사가 아무 말도
# 하지 않고 exit 0 이 된다 — round 6 의 지휘자가
# `git mv lib/content/kst.dart lib/content/kst2.dart` 로 재현했다: 그 문에
# 붙는 짝 검사 셋(2-a·2-b·2-c)이 통째로 침묵했다. 그래서 세 자리의 존재를
# 먼저 단언한다. 자리를 정말 옮기는 변경이라면 여기 목록도 함께 고치게
# 되는데, 그 눈에 띔이 이 단언의 목적이다.
for required in lib/backend lib/location lib/content/kst.dart; do
  if [ ! -e "$required" ]; then
    echo "$required 이 없습니다 — 아래 검사들이 이 자리를 보고 있으므로, 자리가 사라지면 검사가 조용히 통과하는 대신 여기서 멈춥니다 (정말 옮겼다면 이 스크립트의 목록과 검사 본문을 함께 고치십시오)." >&2
    fail=2
  fi
done

# 1) 업로드 계층에 좌표 필드가 없다.
DIR="lib/backend"
pattern='\b(lat|lng|latitude|longitude|coord)\b'

if [ -d "$DIR" ]; then
  hits=$(grep -rniE --include='*.dart' "$pattern" "$DIR" 2>/dev/null)
  if [ -n "$hits" ]; then
    {
      echo "위치 필드로 읽히는 이름이 $DIR 에 있습니다 (기기의 지점은 서버로 올리지 않는다):"
      echo "$hits"
    } >&2
    fail=2
  fi
fi

LOC_DIR="lib/location"

# ─────────────────────────────────────────────────────────────────────────
# 선언 머리를 읽는 규칙 — 이 스크립트 안에서 **한 번만** 적는다.
# ─────────────────────────────────────────────────────────────────────────
#
# round 8 의 거부 사유가 이것을 두 번 다르게 적은 것이었다. 검사 4) 가 "이
# 폴더가 스스로 선언한 타입"을 모을 때 쓰던 grep 은 수식어를 `abstract` 하나로
# 알고 있었는데, 바로 아래 같은 검사의 topDecl() 은 일곱을 알고 있었다. 그래서
# `final class`·`sealed class`·`base class`·`interface class`·
# `abstract final class` 로 선언한 타입이 그 집합에 들어오지 않아 **그 타입의
# final 필드가 exit 2** 였다 — 이 저장소가 `lib/` 에서 실제로 31번 쓰는 모양
# 이고(`abstract final class` 16 · `final class` 11 · `sealed class` 4), 5.2 가
# 이 폴더에 지을 모양 그대로다. 같은 개념을 두 자리에 따로 적으면 어긋남이
# 다시 생기므로, 아래 awk 함수 하나를 **세 자리**가 함께 쓴다:
#   · 2-c 의 kst.dart 공개 이름 읽기
#   · 검사 4) 의 "이 폴더가 스스로 선언한 타입" 모으기
#   · 검사 4) 의 topDecl() (최상위 선언의 이름 읽기)
#
# 수식어 집합은 Dart 3 의 class modifier 전부다(`abstract`·`base`·`final`·
# `sealed`·`interface`)에 `external`·`augment` 를 더한 것이다.
DECL_MODIFIERS='abstract|base|final|sealed|interface|external|augment'
DECL_KEYWORDS='class|enum|mixin|extension|typedef'

# 세 자리가 함께 쓰는 awk 함수 셋. 부르는 쪽은 이 문자열을 자기 프로그램 앞에
# 이어 붙이고 DECL_MOD_RE·DECL_KW_RE 를 -v 로 넘긴다.
DECL_AWK='
  # 괄호·꺾쇠 **밖**의 공백으로만 토막 낸다 — `Future<A> Function()` 은
  # 두 토막이지만 `DeviceFix({required this.lat, ...})` 는 한 토막이다.
  function topTokens(s, arr,   i, c, d, cur, n) {
    d = 0; n = 0; cur = ""
    for (i = 1; i <= length(s); i++) {
      c = substr(s, i, 1)
      if (c == "(" || c == "<" || c == "[" || c == "{") d++
      else if (c == ")" || c == ">" || c == "]" || c == "}") d--
      if (d == 0 && (c == " " || c == "\t")) {
        if (cur != "") { arr[++n] = cur; cur = "" }
        continue
      }
      cur = cur c
    }
    if (cur != "") arr[++n] = cur
    return n
  }

  # 괄호·꺾쇠 밖의 첫 "=" 자리 (없으면 0). "=>"·"==" 도 그 "=" 에서 끊긴다.
  function firstTopEq(s,   i, c, d) {
    d = 0
    for (i = 1; i <= length(s); i++) {
      c = substr(s, i, 1)
      if (c == "(" || c == "<" || c == "[" || c == "{") { d++; continue }
      if (c == ")" || c == ">" || c == "]" || c == "}") { d--; continue }
      if (d == 0 && c == "=") return i
    }
    return 0
  }

  # 선언 머리 arr[1..n] 에서 갈래 키워드와 이름을 읽는다 (애노테이션은 부른
  # 쪽에서 이미 걷어 냈다). 수식어를 앞에서 걷어 내고, 이름에서 타입 매개변수
  # 목록과 표현 필드 목록을 뗀다(`final class Box<T> {` → class · Box).
  #
  # 돌려주는 값이 셋이다:
  #    1  읽었다 — out["kw"] · out["name"] 이 찼다.
  #   -1  갈래 키워드는 왔는데 이름을 읽지 못했다 (부른 쪽은 "?" 로 낸다).
  #    0  타입을 짓는 선언이 아니다 (부른 쪽은 값·함수 쪽으로 넘어간다).
  function declHead(arr, n, out,   i, kw, t) {
    out["kw"] = ""; out["name"] = ""
    for (i = 1; i <= n; i++) {
      kw = arr[i]
      if (kw == "mixin" && i < n && arr[i + 1] == "class") continue
      if (kw == "extension" && i < n && arr[i + 1] == "type") continue
      if (kw ~ DECL_KW_RE) {
        if (i < n) {
          t = arr[i + 1]
          sub(/[<(].*$/, "", t)
          if (t ~ /^[A-Za-z_$][A-Za-z0-9_$]*$/ && t != "on") {
            out["kw"] = kw; out["name"] = t
            return 1
          }
        }
        return -1
      }
      if (kw !~ DECL_MOD_RE) return 0
    }
    return 0
  }
'
DECL_MOD_RE="^($DECL_MODIFIERS)$"
DECL_KW_RE="^($DECL_KEYWORDS)$"

# 2)·3) 이 폴더의 import 는 허용 목록 안에만 있고, export·part 는 쓰지 않는다.
#
# 허용 목록(오늘 이 폴더가 실제로 쓰는 것 전부):
#   dart:math                                       — 하버사인 거리
#   package:flutter_riverpod/flutter_riverpod.dart  — provider 표면
#   package:geolocator/geolocator.dart              — 좌표 통로 (겹 2)
#   package:permission_handler/permission_handler.dart — 권한 접점
#   ../content/kst.dart                             — KST 달력
#   <같은 폴더의 파일>.dart                          — 이 폴더 안의 파일끼리
#
# 같은 폴더 파일을 통째로 허용해도 새는 곳이 없는 것은, 그 파일들도 전부 이
# 검사들을 그대로 지나기 때문이다(find 가 폴더 전체를 훑는다).
ALLOWED_URI='^(dart:math'
ALLOWED_URI="${ALLOWED_URI}|package:flutter_riverpod/flutter_riverpod[.]dart"
ALLOWED_URI="${ALLOWED_URI}|package:geolocator/geolocator[.]dart"
ALLOWED_URI="${ALLOWED_URI}|package:permission_handler/permission_handler[.]dart"
ALLOWED_URI="${ALLOWED_URI}|[.][.]/content/kst[.]dart"
ALLOWED_URI="${ALLOWED_URI}|[A-Za-z0-9_]+[.]dart)$"

if [ -d "$LOC_DIR" ]; then
  # awk 가 실패하면 **드러난다.** 출력만 $( ) 로 받고 종료 상태를 버리면,
  # awk 프로그램이 깨졌을 때 stderr 에만 오류가 찍히고 훅은 그대로 exit 0 이
  # 된다(round 7 의 지휘자가 검사 2)·3)·4) 셋 다에서 재현했다 — 구문 오류를
  # 넣고 실 정탐을 트리에 두었는데 exit 0 이었다). round 6 이 `[ -f ]` 가드의
  # 침묵을 없앴는데 같은 종류의 침묵이 한 겹 아래에 남아 있었다.
  uri_scan=$(find "$LOC_DIR" -type f -name '*.dart' | sort | while read -r dart_file; do
    awk -v ALLOW="$ALLOWED_URI" -v FNAME="$dart_file" '
      function report(msg) { printf "%s:%d: %s\n", FNAME, ln, msg }
      {
        line = $0
        trimmed = line
        sub(/^[[:space:]]+/, "", trimmed)
        if (trimmed ~ /^\/\//) next
        # 지시자의 URI 에는 "//" 가 없으므로 줄 주석은 그냥 잘라 낸다.
        sub(/\/\/.*$/, "", line)

        if (buf == "") {
          if (line ~ /^[[:space:]]*(import|export)[[:space:]]+["'"'"']/) { buf = line; ln = FNR }
          else if (line ~ /^[[:space:]]*part[[:space:]]+(["'"'"']|of[[:space:]])/) { buf = line; ln = FNR }
          else next
        } else {
          buf = buf " " line
        }
        if (buf !~ /;/) next

        stmt = buf
        buf = ""
        # 3) 라이브러리 경계를 넓히는 지시자는 이 폴더에 하나도 없다.
        if (stmt ~ /^[[:space:]]*(export|part)[[:space:]]/) {
          sub(/^[[:space:]]+/, "", stmt)
          report("이 폴더가 쓰지 않는 지시자 (export·part 는 허용 목록을 밖으로 흘리거나 라이브러리 가시성을 넓힌다) — " stmt)
          next
        }
        rest = stmt
        seen = 0
        while (match(rest, /"[^"]*"|'"'"'[^'"'"']*'"'"'/)) {
          uri = substr(rest, RSTART + 1, RLENGTH - 2)
          rest = substr(rest, RSTART + RLENGTH)
          seen = 1
          if (uri !~ ALLOW) report("허용 목록 밖의 import — " uri)
        }
        if (!seen) { sub(/^[[:space:]]+/, "", stmt); report("URI 를 읽지 못한 지시자 — " stmt) }
      }
      END { if (buf != "") report("닫히지 않은 지시자 — " buf) }
    ' "$dart_file" || printf 'AWKFAIL\t%s\n' "$dart_file"
  done)

  uri_awk_fail=$(printf '%s\n' "$uri_scan" | sed -n 's/^AWKFAIL\t//p')
  if [ -n "$uri_awk_fail" ]; then
    {
      echo "검사 2)·3) 의 awk 가 아래 파일에서 실패했습니다 — 검사가 조용히 통과하는 대신 여기서 멈춥니다:"
      echo "$uri_awk_fail"
    } >&2
    fail=2
  fi
  uri_hits=$(printf '%s\n' "$uri_scan" | grep -v '^AWKFAIL	' | grep -v '^$')

  if [ -n "$uri_hits" ]; then
    {
      echo "$LOC_DIR 이 허용 목록 밖의 것을 들입니다 (이 계층은 판정만 하고 아무것도 보내지 않는다 — 정말 필요하면 이 스크립트의 허용 목록을 넓히고 ADR 을 남기십시오):"
      echo "$uri_hits"
    } >&2
    fail=2
  fi

  # 허용 목록의 유일한 폴더 밖 문(lib/content/kst.dart)에 붙는 짝 검사 셋.
  # 위 헤더의 2-a·2-b·2-c 가 각각의 까닭이다.
  DOOR="lib/content/kst.dart"
  if [ -f "$DOOR" ]; then
    # 2-a) 재수출도, part 도 없다.
    door_hits=$(grep -nE "^[[:space:]]*(export|part)[[:space:]]" "$DOOR" 2>/dev/null)
    if [ -n "$door_hits" ]; then
      {
        echo "$DOOR 이 라이브러리 경계를 넓힙니다 — 이 파일은 $LOC_DIR 허용 목록의 유일한 폴더 밖 문이라, export 는 곧 그 허용 목록에 이름을 몰래 더하는 것이고 part 는 아래 공개 이름 검사의 시야 밖에서 이름을 더하는 것입니다:"
        echo "$door_hits"
      } >&2
      fail=2
    fi

    # 2-b) 그 문 자신의 import 도 허용 목록 안에만 있다.
    door_uris=$(grep -oE "^[[:space:]]*import[[:space:]]+[\"'][^\"']*[\"']" "$DOOR" 2>/dev/null \
      | sed -E "s/^[[:space:]]*import[[:space:]]+[\"']//; s/[\"']\$//" \
      | grep -vxE 'models[.]dart' | sort -u)
    if [ -n "$door_uris" ]; then
      {
        echo "$DOOR 이 허용 목록(models.dart) 밖의 것을 들입니다 — 이 문 안쪽에서 네트워크 클라이언트를 들이면 $LOC_DIR 의 이름을 하나도 늘리지 않고 좌표가 나갑니다:"
        echo "$door_uris"
      } >&2
      fail=2
    fi

    # 2-c) 그 문이 내미는 최상위 공개 이름 집합이 넷 그대로다.
    #
    # round 5 의 검증자가 뚫은 자리다: 2-a 가 `export` 만 보고 있어서, 이
    # 파일에 공개 함수를 하나 더하고 그 안에서 좌표를 외부 서버로 보내는 것이
    # 훅 4종·시험 663개를 전부 통과했다. 이름을 읽지 못한 최상위 줄은 "?" 를
    # 붙여 내보내므로, 선언을 쪼개 이름을 다음 줄로 내리는 표기도 목록과
    # 어긋나 exit 2 가 된다(막히는 쪽으로 틀린다).
    DOOR_NAMES='gameDateOf
gameStartsAt
kstDateOf
kstOffset'
    # 선언 머리는 위 DECL_AWK 의 declHead() 하나로 읽는다 — 검사 4) 의 두
    # 자리와 같은 수식어 집합·같은 이름 추출이다.
    door_actual=$(awk -v DECL_MOD_RE="$DECL_MOD_RE" -v DECL_KW_RE="$DECL_KW_RE" "$DECL_AWK"'
      /^[[:space:]]*\/\// { next }
      /^(import|export|part|library)([[:space:]]|;)/ { next }
      /^[A-Za-z_$]/ {
        line = $0
        sub(/\/\/.*$/, "", line)
        hdN = topTokens(line, hdArr)
        head = declHead(hdArr, hdN, hd)
        if (head == 1) { print hd["name"]; next }
        if (head == 0 && match(line, /[A-Za-z_$][A-Za-z0-9_$]*[ ]*[(=;]/)) {
          s = substr(line, RSTART, RLENGTH); sub(/[ ]*[(=;]$/, "", s); print s; next
        }
        print "?" line
      }
    ' "$DOOR")
    # awk 의 종료 상태는 대입 **직후**에만 남는다 — 파이프 뒤로 미루면 사라진다.
    door_awk_status=$?
    door_actual=$(printf '%s\n' "$door_actual" | grep -v '^_' | grep -v '^$' | sort -u)
    if [ "$door_awk_status" -ne 0 ]; then
      echo "2-c) 의 awk 가 $DOOR 에서 실패했습니다 — 검사가 조용히 통과하는 대신 여기서 멈춥니다." >&2
      fail=2
    fi
    if [ "$door_actual" != "$DOOR_NAMES" ]; then
      {
        echo "$DOOR 의 최상위 공개 이름 집합이 바뀌었습니다 — 이 파일은 $LOC_DIR 허용 목록의 유일한 폴더 밖 문이라, 여기에 공개 이름이 하나 늘면 그것이 곧 좌표를 들고 나갈 수 있는 새 표면입니다. 정말 필요하면 이 스크립트의 DOOR_NAMES 를 의도적으로 넓히고 ADR 을 남기십시오."
        echo "기대: $(echo "$DOOR_NAMES" | paste -sd' ' -)"
        echo "실제: $(echo "$door_actual" | paste -sd' ' -)"
      } >&2
      fail=2
    fi
  fi
fi

# 4) 좌표를 다루는 계층에 값을 담아 둘 자리를 두지 않는다.
#
# 이 검사는 줄이 아니라 **문장**을 본다 (까닭은 위 헤더의 4) 참조). 파일을
# 한 번 훑으면서 주석과 문자열을 걷어 내고, 괄호 밖의 중괄호로 깊이를 세고,
# 괄호 밖의 `;` 와 `{` 에서 문장을 끊는다. "클래스 몸통 안"은 들여쓰기가
# 아니라 그 깊이를 연 중괄호가 class/enum/mixin/extension 의 것인지로 정해진다.
#
# 그 문장들을 **두 자리로 나눠 본다**: 깊이 0 의 문장은 이름을 읽어
# LOC_TOP_NAMES 와 대조하고(NAME 표), 클래스 몸통의 문장은 타입을 본다
# (FIELD 표). 까닭은 위 헤더의 4) (a)·(b) 에 있다.
if [ -d "$LOC_DIR" ]; then
  # 이 폴더가 스스로 선언하는 타입 이름들 — 허용 타입 집합의 절반이다.
  #
  # class·enum·mixin 만 센다. 그 셋은 **몸통이 있어서** 그 안의 필드가 다시
  # 이 검사를 지나므로 고리가 닫히는데, 나머지 둘은 그렇지 않다(round 5 의
  # 구현자가 스스로 공격해서 찾은 자리다):
  #   · `extension type Box(List<DeviceFix> v) {}` 의 표현 필드는 헤더의
  #     괄호 안에 있어서 이 검사의 문장 분해가 닿지 않는다.
  #   · `typedef Bag = List<DeviceFix>;` 은 몸통이 아예 없다.
  # 그래서 그 둘의 이름을 허용 타입으로 받으면 `final Box b;`·`final Bag b;`
  # 한 줄이 그대로 좌표를 쌓을 자리가 된다.
  #
  # 예외는 **함수 타입 typedef** 하나다(`typedef X = ... Function(...)`).
  # 함수 타입은 값을 담지 못하고, 이 폴더의 이음매(`DeviceFixReader`)가 그
  # 모양이라 이것까지 빼면 정당한 필드가 걸린다.
  # 이름은 **위 DECL_AWK 의 declHead() 하나로** 읽는다 — topDecl() 이 읽는
  # 것과 같은 수식어 집합이고 같은 이름 추출이다(round 8 의 거부 사유가 이
  # 둘이 어긋난 것이었다). 그래서 `final class Foo`·`sealed class Foo`·
  # `abstract final class Foo`·`mixin class Foo`·`class Box<T>` 가 전부 이
  # 집합에 들어온다.
  #
  # **함수 타입 typedef 는 따로 모은다**(FNTYPES). 그 이름은 타입 매개변수를
  # 붙인 인스턴스화(`Parse<int>`)까지 받아야 하는데, class 이름 쪽은 그러면
  # 안 되기 때문이다 — `Box<DeviceFix>` 는 그대로 좌표를 담는 통이다.
  # 함수 타입은 무엇으로 인스턴스화해도 값을 담지 못하므로 그 차이가 성립하고,
  # 그것이 성립하도록 `=` 오른쪽의 **최상위** 토막이 `Function(`·`Function<`
  # 로 시작하는 typedef 만 여기 센다(`typedef Bag = List<int Function()>;` 는
  # 함수가 아니라 통이므로 들어오지 않는다).
  decl_scan=$(find "$LOC_DIR" -type f -name '*.dart' | sort | while read -r dart_file; do
    awk -v DECL_MOD_RE="$DECL_MOD_RE" -v DECL_KW_RE="$DECL_KW_RE" "$DECL_AWK"'
      function isFnTypedef(s,   eq, rhs, rt, m, i) {
        eq = firstTopEq(s)
        if (eq == 0) return 0
        rhs = substr(s, eq + 1)
        m = topTokens(rhs, rt)
        for (i = 1; i <= m; i++) if (rt[i] ~ /^Function[(<]/) return 1
        return 0
      }
      /^[A-Za-z_$]/ {
        line = $0
        sub(/\/\/.*$/, "", line)
        n = topTokens(line, arr)
        if (declHead(arr, n, hd) != 1) next
        if (hd["kw"] == "typedef") {
          if (isFnTypedef(line)) print "FN\t" hd["name"]
          next
        }
        # class·enum·mixin 만 센다 (까닭은 위 문단). extension·extension type
        # 과 함수 타입이 아닌 typedef 는 여기 오지 않는다.
        if (hd["kw"] == "class" || hd["kw"] == "enum" || hd["kw"] == "mixin")
          print "TYPE\t" hd["name"]
      }
    ' "$dart_file" || printf 'AWKFAIL\t%s\n' "$dart_file"
  done)

  decl_awk_fail=$(printf '%s\n' "$decl_scan" | sed -n 's/^AWKFAIL\t//p')
  if [ -n "$decl_awk_fail" ]; then
    {
      echo "검사 4) 의 타입 이름 모으기 awk 가 아래 파일에서 실패했습니다 — 검사가 조용히 통과하는 대신 여기서 멈춥니다:"
      echo "$decl_awk_fail"
    } >&2
    fail=2
  fi

  declared=$(printf '%s\n' "$decl_scan" | sed -n 's/^TYPE\t//p' | grep -v '^$' | sort -u)
  declared_fn=$(printf '%s\n' "$decl_scan" | sed -n 's/^FN\t//p' | grep -v '^$' | sort -u)
  all_declared=$(printf '%s\n%s\n' "$declared" "$declared_fn" | grep -v '^$' | sort -u | paste -sd'|' -)
  FNTYPES=$(printf '%s\n' "$declared_fn" | paste -sd'|' -)
  TYPES='bool|double|int|num|String|Duration|DateTime'
  [ -n "$all_declared" ] && TYPES="$TYPES|$all_declared"

  scan=$(find "$LOC_DIR" -type f -name '*.dart' | sort | while read -r dart_file; do
    awk -v TYPES="$TYPES" -v FNTYPES="$FNTYPES" -v FNAME="$dart_file" \
        -v DECL_MOD_RE="$DECL_MOD_RE" -v DECL_KW_RE="$DECL_KW_RE" "$DECL_AWK"'
      BEGIN {
        n = split(TYPES, t, "|"); for (i = 1; i <= n; i++) ok[t[i]] = 1
        if (FNTYPES != "") { n = split(FNTYPES, t, "|"); for (i = 1; i <= n; i++) okfn[t[i]] = 1 }
        SQ = sprintf("%c", 39); DQ = sprintf("%c", 34)
      }

      { src = src $0 "\n" }

      # 선언의 앞부분(수식어 + 타입 + 이름)만 잘라 온다 — 괄호·꺾쇠 밖의
      # 첫 ";" 나 "=" 까지다. "=>" 와 "==" 는 선언의 끝이 아니므로 빈 문자열을
      # 돌려준다(표현식 본문 메서드·게터와 함수 선언이 여기서 빠진다).
      function declPart(s,   i, c, nx, d) {
        d = 0
        for (i = 1; i <= length(s); i++) {
          c = substr(s, i, 1)
          if (c == "(" || c == "<" || c == "[" || c == "{") { d++; continue }
          if (c == ")" || c == ">" || c == "]" || c == "}") { d--; continue }
          if (d != 0) continue
          if (c == ";") return substr(s, 1, i - 1)
          if (c == "=") {
            nx = substr(s, i + 1, 1)
            if (nx == ">" || nx == "=") return ""
            return substr(s, 1, i - 1)
          }
        }
        return ""
      }

      # topTokens()·firstTopEq()·declHead() 는 위 DECL_AWK 에 있다 — 이
      # 스크립트의 세 자리가 같은 함수를 쓴다.

      # 값을 담아 둘 수 없는 **함수 타입**인가.
      #
      # 그 자리에 직접 적은 함수 타입(`... Function(...)`)과, 이 폴더가
      # 선언한 함수 타입 typedef 의 이름 둘 다다. typedef 이름은 타입
      # 매개변수를 붙인 인스턴스화(`Parse<int>`)까지 받는다 — 함수 타입은
      # 무엇으로 인스턴스화해도 값을 담지 못하기 때문이고, 위에서 그 집합을
      # 모을 때 오른쪽이 **최상위** 함수 타입인 typedef 만 세는 것이 이
      # 문장을 참으로 만든다. class 이름 쪽은 이렇게 하지 **않는다**:
      # `Box<DeviceFix>` 는 그대로 좌표를 담는 통이라 exit 2 다.
      function isFnType(t,   b) {
        if (t ~ /Function[(]/) return 1
        b = t
        sub(/[?]$/, "", b)
        sub(/<.*$/, "", b)
        return (b in okfn)
      }

      # 클래스 몸통의 선언 하나가 "값을 담아 둘 수 없는" 모양인가.
      function fieldOk(s,   arr, n, i, type, base) {
        n = topTokens(s, arr)
        # 애노테이션은 선언의 모양을 바꾸지 않는다 — 앞에서 걷어 낸다.
        # (round 6 의 구현자가 스스로 공격해 찾은 오탐: `@override final String
        # name;` 이 exit 2 였다. 걷어 낸 **뒤에** 판정하므로
        # `@override final List<DeviceFix> seen;` 은 그대로 걸린다.)
        base = 1
        while (base <= n && arr[base] ~ /^@/) base++
        if (base > 1) {
          for (i = base; i <= n; i++) arr[i - base + 1] = arr[i]
          n = n - base + 1
        }
        if (n < 2) return 1                       # 이름 하나뿐 — 선언이 아니다
        if (arr[n] ~ /[(]/) return 1              # 메서드·생성자
        if (arr[1] ~ /[(]/) return 1              # 초기화 목록이 붙은 생성자
        # 몸통 없는 게터 선언(`String get id;`) — 게터는 값을 담지 못한다.
        # `=>` 로 몸통을 쓰는 게터는 declPart 가 이미 걸러 내지만, 추상
        # 클래스·인터페이스의 게터 선언은 여기까지 온다 (round 6 오탐).
        if (n >= 3 && arr[n - 1] == "get") return 1
        # 수식어는 무엇이 담기는지를 바꾸지 않는다 — 앞에서 걷어 낸 뒤에 타입을 본다.
        # (round 7 의 오탐: `static final int retryBudget = 3;` 이 exit 2 였다.
        #  옆 줄이 타입을 보기도 전에 `arr[1] != "final"` 로 거절했기
        #  때문이고, 그래서 `static final String`·`static final Duration`·
        #  `abstract final String` 도 같이 걸렸다.)
        # `late` 는 이 집합에 **없다** — 값이 생성자 밖의 어느 시점에
        # 들어오는 자리라 일부러 거절하는 모양이다(헤더의 4) 참조).
        #
        # **이 집합은 위 DECL_MODIFIERS 와 다른 개념이고, 같아서도 안 된다.**
        # 저것은 선언 **머리**의 수식어(class modifier)이고 이것은 **필드**의
        # 수식어다: `sealed`·`base`·`interface` 는 필드에 붙지 않고
        # `static`·`covariant` 는 머리에 붙지 않는다. 둘이 겹치는 것은
        # `abstract`·`external` 둘뿐이다.
        base = 1
        while (base <= n && arr[base] ~ /^(static|abstract|external|covariant)$/) base++
        if (base > 1) {
          for (i = base; i <= n; i++) arr[i - base + 1] = arr[i]
          n = n - base + 1
        }
        if (n < 2) return 1
        if (arr[1] == "const") return 1
        if (arr[1] != "final") return 0           # var·late·수식어 없음
        type = ""
        for (i = 2; i < n; i++) type = (type == "" ? arr[i] : type " " arr[i])
        if (isFnType(type)) return 1              # 이음매(함수 타입)
        if (n != 3) return 0
        sub(/[?]$/, "", type)
        return (type in ok)
      }

      # 구분자로 토막 낸다 — 괄호·꺾쇠 **밖**의 것만 구분자로 센다.
      function splitTop(s, arr, sep,   i, c, d, cur, n) {
        d = 0; n = 0; cur = ""
        for (i = 1; i <= length(s); i++) {
          c = substr(s, i, 1)
          if (c == "(" || c == "<" || c == "[" || c == "{") d++
          else if (c == ")" || c == ">" || c == "]" || c == "}") d--
          if (d == 0 && c == sep) { arr[++n] = cur; cur = ""; continue }
          cur = cur c
        }
        if (cur != "") arr[++n] = cur
        return n
      }

      # `=` **뒤에 오는 생성자**가 읽기 전용 provider 인가.
      #
      # 옛 판은 이것을 선언의 앞부분까지 함께 보는 정규식
      # (`^final <이름> = Provider…`)으로 두어서, 타입을 명시한 provider
      # (`final Provider<T> xProvider = Provider<T>(...)` — 이 저장소의 최상위
      # provider 18개 중 5개가 타입을 명시하고, 그중 읽기 전용 `Provider<T>` 둘이
      # 그 모양이다: lib/backend/auth.dart:114 · lib/backend/user_data.dart:830)
      # 를 오탐했다. 이제 앞부분은 보지 않는다.
      #
      # 타입 인자의 규칙은 클래스 필드 쪽(fieldOk)과 같다: "담을 수 없는
      # 타입"이거나 함수 타입이면 통과한다. 함수 타입을 함께 받는 것은 이
      # 폴더의 이음매가 그 모양이고(`Provider<DeviceFixReader>`), 같은 것을
      # typedef 없이 그 자리에 적은 모양(`Provider<DateTime Function()>` —
      # lib/features/home/next_away_game.dart:21 이 그 모양이다)을 다르게
      # 다룰 까닭이 없기 때문이다.
      # StateProvider·NotifierProvider·FutureProvider·StreamProvider 는 이름이
      # 어긋나 통과하지 못하고, 타입 인자를 적지 않은 `Provider((ref) => ...)`
      # 도 무엇이 담기는지 알 수 없어 통과하지 못한다.
      function providerOk(init,   i, c, d, args, a, n, t) {
        if (init !~ /^Provider([.]autoDispose)?([.]family)?</) return 0
        i = index(init, "<")
        d = 0; args = ""
        for (; i <= length(init); i++) {
          c = substr(init, i, 1)
          if (c == "<" || c == "(" || c == "[" || c == "{") { d++; if (d == 1) continue }
          else if (c == ">" || c == ")" || c == "]" || c == "}") { d--; if (d == 0) break }
          args = args c
        }
        if (d != 0) return 0
        if (substr(init, i + 1, 1) != "(") return 0
        n = splitTop(args, a, ",")
        if (n < 1) return 0
        for (i = 1; i <= n; i++) {
          t = a[i]
          sub(/^ +/, "", t); sub(/ +$/, "", t)
          if (isFnType(t)) continue
          sub(/[?]$/, "", t)
          if (!(t in ok)) return 0
        }
        return 1
      }

      # 한 문장에 값 자리가 둘 이상인가 (`double a, b;` ·
      # `final a = 1, b = 2;`).
      #
      # 괄호·대괄호·중괄호 **밖**의 쉼표 뒤에 "이름 다음에 = 나 ; 나 문장
      # 끝"이 오는지로 본다. 꺾쇠는 깊이로 세지 않는다 — 초기화 식에는
      # `=>`·`>=` 처럼 짝이 맞지 않는 꺾쇠가 흔해서 깊이가 어긋나기
      # 때문이다. 대신 뒤에 `>` 가 오는 쉼표(`Map<String, int> a;` ·
      # `Provider.family<int, String>(`)는 이 조건에 걸리지 않는다.
      function multiDeclarator(s,   i, c, d, rest) {
        d = 0
        for (i = 1; i <= length(s); i++) {
          c = substr(s, i, 1)
          if (c == "(" || c == "[" || c == "{") { d++; continue }
          if (c == ")" || c == "]" || c == "}") { d--; continue }
          if (d != 0 || c != ",") continue
          rest = substr(s, i + 1)
          if (rest ~ /^ *[A-Za-z_$][A-Za-z0-9_$]* *(;|$)/) return 1
          if (rest ~ /^ *[A-Za-z_$][A-Za-z0-9_$]* *=[^=>]/) return 1
        }
        return 0
      }

      # 최상위 문장 하나에서 (이름, 갈래) 를 뽑아 out 에 담는다.
      #
      # **이 검사의 최상위 규칙이 보는 것은 타입이 아니라 이름이다** (round 7
      # 에서 방향을 뒤집었다 — 까닭은 헤더의 4) 참조). 그래서 여기서 하는 일은
      # "이 선언이 값을 담을 수 있는가"를 판정하는 것이 아니라 **선언의 이름을
      # 읽어 오는 것**뿐이고, 읽지 못한 문장은 이름을 "?" 로 내보내 목록과
      # 어긋나게 한다(막히는 쪽으로 틀린다 — kst.dart 의 2-c 와 같은 방식이다).
      #
      # 갈래를 함께 못 박는 것은 **이름을 그대로 두고 모양만 바꾸는** 변경을
      # 받기 위해서다: const 를 저장소로 바꾸거나(const→var), 읽기 전용
      # provider 의 타입 인자를 담을 수 있는 통으로 바꾸면(provider→var,
      # providerOk 가 어긋나므로) 이름은 그대로여도 갈래가 달라져 걸린다.
      #   type     class·enum·mixin·extension·typedef
      #   func     이름 뒤에 매개변수 목록이 오는 선언
      #   getter   / setter
      #   const    const 로 시작하는 값 선언
      #   provider providerOk 에 맞는 읽기 전용 provider
      #   var      그 밖의 값 선언 (오늘 이 폴더에는 하나도 없다)
      function topDecl(s, out,   arr, n, i, base, eq, pre, init, kw, t, h, hd) {
        out["name"] = "?"; out["kind"] = "?"
        # 빈 문장 — 중괄호 리터럴(`const Map<..> t = <..>{...};` · 최상위
        # 클로저)의 닫는 괄호 뒤에 남는 `;` 가 여기로 온다. 선언 자체는 그
        # 리터럴을 여는 `{` 에서 이미 머리로 읽혔다.
        t = s
        gsub(/[ ;]/, "", t)
        if (t == "") { out["name"] = ""; return }
        if (s ~ /^(import|export|part|library)([ ;]|$)/) { out["name"] = ""; return }

        n = topTokens(s, arr)
        base = 1
        while (base <= n && arr[base] ~ /^@/) base++
        if (base > 1) {
          for (i = base; i <= n; i++) arr[i - base + 1] = arr[i]
          n = n - base + 1
        }
        if (n < 1) { out["name"] = ""; return }

        # (1) 타입을 짓는 선언 — 위 DECL_AWK 의 declHead() 가 읽는다.
        #     같은 함수를 검사 4) 의 타입 이름 모으기와 2-c 도 쓴다.
        h = declHead(arr, n, hd)
        if (h == 1) { out["name"] = hd["name"]; out["kind"] = "type"; return }
        if (h == -1) return

        # (2) 값·함수 선언 — 괄호 밖의 첫 "=" 앞이 선언의 앞부분이다.
        eq = firstTopEq(s)
        pre = (eq > 0) ? substr(s, 1, eq - 1) : s
        init = (eq > 0) ? substr(s, eq + 1) : ""
        sub(/^>/, "", init)                       # "=>" 의 나머지
        sub(/^ +/, "", init)
        sub(/;$/, "", pre)
        n = topTokens(pre, arr)
        base = 1
        while (base <= n && arr[base] ~ /^@/) base++
        if (base > 1) {
          for (i = base; i <= n; i++) arr[i - base + 1] = arr[i]
          n = n - base + 1
        }
        while (n >= 1 && arr[n] ~ /^(async|async[*]|sync[*])$/) n--
        if (n < 1) return

        if (arr[n] ~ /[(]/) {
          # 이름 + (타입 매개변수) + 매개변수 목록 — 앞의 식별자가 이름이다.
          t = arr[n]
          sub(/[(<].*$/, "", t)
          if (t ~ /^[A-Za-z_$][A-Za-z0-9_$]*$/) {
            out["name"] = t
            out["kind"] = (n >= 2 && arr[n - 1] == "set") ? "setter" : "func"
            return
          }
        }
        if (arr[n] !~ /^[A-Za-z_$][A-Za-z0-9_$]*$/) return
        # 한 문장이 값 자리를 **여럿** 선언하면 이름을 하나밖에 읽지 못한다.
        # 그때 나머지가 조용히 목록을 지나가지 않도록 이름을 "?" 로 둔다 —
        # 이 폴더에서는 선언 하나에 이름 하나로 쓰십시오. (스스로 공격해서
        # 찾은 자리다: `final <목록에 있는 provider 이름> = Provider<T>(...),
        # sneaky = <DeviceFix>[];` 는 앞 이름만 읽으면 그대로 지나간다.)
        if (multiDeclarator(s)) return
        out["name"] = arr[n]
        if (n >= 2 && arr[n - 1] == "get") { out["kind"] = "getter"; return }
        if (n >= 2 && arr[n - 1] == "set") { out["kind"] = "setter"; return }
        if (n >= 2 && arr[1] == "const") { out["kind"] = "const"; return }
        out["kind"] = providerOk(init) ? "provider" : "var"
      }

      # 문장 하나를 그 중괄호 깊이와 함께 받아 판정한다.
      function emit(stmt, depth, ln,   decl, d0) {
        sub(/^ +/, "", stmt); sub(/ +$/, "", stmt)
        if (stmt == "") return
        # enum 몸통의 **첫 문장**은 값 나열이지 선언이 아니다. Dart 는 값
        # 목록 뒤에 멤버가 하나라도 오면 `;` 를 요구하는데, 그 `;` 로 끝나는
        # 줄을 옛 검사가 "값을 담아 둘 자리"로 읽어 `enum E { a, b; bool get
        # x => ...; }` 를 exit 2 로 냈다 (round 6 의 거부 사유). Dart 문법이
        # 값 나열을 몸통의 첫 자리에 못 박으므로, 여기서 첫 문장 하나만
        # 건너뛰어도 그 뒤의 필드는 전부 그대로 지난다.
        if (enumHead[depth]) { enumHead[depth] = 0; return }
        if (depth == 0) {
          # (a) 최상위 선언 — **타입이 아니라 이름을 본다.** 이 폴더의 최상위
          #     선언 이름 집합 자체를 아래 LOC_TOP_NAMES 로 못 박으므로, 새
          #     선언은 타입 표기가 무엇이든(홑 타입·제네릭·함수 타입·레코드·
          #     중첩 제네릭·typedef 별칭·dynamic·Object·var) 목록과 어긋나
          #     걸린다. 읽지 못한 문장은 이름이 "?" 로 나가 역시 어긋난다.
          topDecl(stmt, d0)
          if (d0["name"] != "")
            printf "NAME\t%s:%s\t%s:%d\t%s\n", d0["name"], d0["kind"], FNAME, ln, stmt
          return
        }
        decl = declPart(stmt)
        if (decl == "") return                    # 함수·게터·헤더 — 값 자리가 아니다
        # (b)·(c) 클래스·enum·mixin·extension 몸통의 선언과, 깊이와 무관하게
        #     static 으로 시작하는 선언. 함수 몸통 안의 지역 변수는 그 깊이를
        #     연 중괄호가 클래스의 것이 아니므로 여기 오지 않는다.
        if (!kind[depth] && stmt !~ /^static /) return
        if (!fieldOk(decl)) printf "FIELD\t%s:%d:%s\n", FNAME, ln, stmt
      }

      END {
        len = length(src)
        bd = 0; pd = 0; cur = ""; line = 1; sline = 1; q = ""
        for (i = 1; i <= len; i++) {
          c = substr(src, i, 1)

          if (q != "") {                          # 문자열 안 — 내용은 보지 않는다
            if (c == "\n") line++
            else if (c == "\\") { i++; if (substr(src, i, 1) == "\n") line++ }
            else if (c == q) q = ""
            cur = cur c
            continue
          }

          if (c == "/" && substr(src, i + 1, 1) == "/") {      # 줄 주석
            while (i <= len && substr(src, i, 1) != "\n") i++
            c = "\n"
          } else if (c == "/" && substr(src, i + 1, 1) == "*") { # 블록 주석
            i += 2
            while (i < len && !(substr(src, i, 1) == "*" && substr(src, i + 1, 1) == "/")) {
              if (substr(src, i, 1) == "\n") line++
              i++
            }
            i++
            c = " "
          }

          if (c == "\n") { line++; c = " " }
          if (c == " " || c == "\t" || c == "\r") {
            if (cur != "" && substr(cur, length(cur), 1) != " ") cur = cur " "
            continue
          }

          if (c == SQ || c == DQ) { q = c; if (cur == "") sline = line; cur = cur c; continue }
          if (c == "(" || c == "[") { pd++; if (cur == "") sline = line; cur = cur c; continue }
          if (c == ")" || c == "]") { pd--; cur = cur c; continue }

          if (c == "{") {
            if (pd == 0) {
              hdr = cur; sub(/ +$/, "", hdr)
              emit(hdr, bd, sline)
              bd++
              # 이 갈래 집합은 위 DECL_KEYWORDS 에서 `typedef` 를 뺀 것이다 —
              # typedef 는 몸통을 열지 않으므로 여기 올 일이 없다. 그리고
              # declHead() 가 아니라 머리 문자열을 그대로 보는데, 그래야
              # `extension type Box(...) {` 의 몸통도 함께 세어진다
              # (declHead() 는 그것을 타입 선언으로 읽지 않는다 — 막히는
              # 쪽으로 틀린다).
              kind[bd] = (hdr ~ /(^|[^A-Za-z0-9_$])(class|enum|mixin|extension)[ ]/) ? 1 : 0
              enumHead[bd] = (hdr ~ /(^|[^A-Za-z0-9_$])enum[ ]/) ? 1 : 0
              cur = ""
            } else {
              bd++; kind[bd] = 0; enumHead[bd] = 0; cur = cur c
            }
            continue
          }
          if (c == "}") {
            if (bd > 0) bd--
            if (pd == 0) cur = ""; else cur = cur c
            continue
          }
          if (c == ";") {
            if (pd == 0) { emit(cur ";", bd, sline); cur = "" } else cur = cur c
            continue
          }

          if (cur == "") sline = line
          cur = cur c
        }
        emit(cur, bd, sline)
      }
    ' "$dart_file" || printf 'AWKFAIL\t%s\n' "$dart_file"
  done)

  awk_fail=$(printf '%s\n' "$scan" | sed -n 's/^AWKFAIL\t//p')
  if [ -n "$awk_fail" ]; then
    {
      echo "검사 4) 의 awk 가 아래 파일에서 실패했습니다 — 검사가 조용히 통과하는 대신 여기서 멈춥니다:"
      echo "$awk_fail"
    } >&2
    fail=2
  fi

  # (a) 최상위 선언 이름 집합.
  #
  # 오늘 이 폴더가 내미는 최상위 선언 전부다(private 도 포함한다 — 그 값을
  # 같은 라이브러리의 다른 선언이 실어 낼 수 있다). 새 선언을 정당하게 하나
  # 더할 때는 이 목록을 넓히고 ADR 을 남기게 되는데, **그 눈에 띔이 이 검사의
  # 목적이다** (.wellbegun/decisions.md 2026-09-04 [S] 와 같은 논거이고,
  # 2-c 의 DOOR_NAMES 와 같은 방식이다).
  LOC_TOP_NAMES='DeviceFix:type
DeviceFixReader:type
DevicePermissionHandlerGateway:type
LocationPermissionGateway:type
LocationPermissionStatus:type
StadiumVisitCandidate:type
StadiumVisitChecker:type
StadiumVisitReason:type
StadiumVisitResult:type
_metersBetween:func
_radians:func
_readDeviceFix:func
candidatesToJudge:func
judgeStadiumVisit:func
kLocationFixTimeout:const
kLocationPermissionTimeout:const
kStadiumVisitRadiusMeters:const
kVisitWindowAfterStart:const
kVisitWindowBeforeStart:const
locationPermissionGatewayProvider:provider
resolveLocationPermission:func
stadiumVisitCheckerProvider:provider
visitWindowCovers:func'

  # 정렬은 LC_ALL=C 로 못 박는다 — 로케일이 다른 기계에서 목록과 실제의
  # **차례**만 달라져 이 검사가 헛되이 빨간불이 되는 것을 막는다.
  top_names=$(printf '%s\n' "$scan" | sed -n 's/^NAME\t//p' | LC_ALL=C sort)
  top_actual=$(printf '%s\n' "$top_names" | cut -f1 | grep -v '^$' | LC_ALL=C sort -u)
  top_expected=$(printf '%s\n' "$LOC_TOP_NAMES" | LC_ALL=C sort -u)
  if [ "$top_actual" != "$top_expected" ]; then
    {
      echo "$LOC_DIR 의 최상위 선언 이름 집합이 바뀌었습니다 — 이 폴더의 최상위 선언은 타입이 아니라 **이름**으로 못 박혀 있습니다(새 최상위 자리는 그 타입 표기가 무엇이든 여기서 걸립니다). 정말 필요한 선언이면 이 스크립트의 LOC_TOP_NAMES 를 의도적으로 넓히고 ADR 을 남기십시오."
      unknown=$(comm -23 <(printf '%s\n' "$top_actual") <(printf '%s\n' "$top_expected"))
      missing=$(comm -13 <(printf '%s\n' "$top_actual") <(printf '%s\n' "$top_expected"))
      if [ -n "$unknown" ]; then
        echo "목록 밖:"
        printf '%s\n' "$unknown" | while IFS= read -r nk; do
          printf '%s\n' "$top_names" | awk -F'\t' -v nk="$nk" '$1 == nk { print "  " $2 ": " $1 "  —  " $3 }'
        done
      fi
      if [ -n "$missing" ]; then
        echo "목록에 있으나 소스에 없음:"
        printf '%s\n' "$missing" | sed 's/^/  /'
      fi
    } >&2
    fail=2
  fi

  # (b) 클래스·enum·mixin·extension 몸통의 값 자리.
  top_hits=$(printf '%s\n' "$scan" | sed -n 's/^FIELD\t//p')
  if [ -n "$top_hits" ]; then
    {
      echo "$LOC_DIR 에 값을 담아 둘 자리가 있습니다 (판정에 쓴 좌표가 라이브러리 밖에서 읽히는 자리다 — const 이거나, 담을 수 없는 타입의 final 필드여야 합니다. 정당한 모양인데 여기 걸렸다면 이 스크립트 헤더의 4) 에 있는 \"일부러 거절하는 정당한 모양\" 을 읽으십시오):"
      echo "$top_hits"
    } >&2
    fail=2
  fi
fi

# 5) 좌표를 콘솔·기기 로그에 적지 않는다.
#
# `print` 는 dart:core 라 import 가 없어서 검사 2) 의 허용 목록이 원리상 닿지
# 못한다. 점 뒤에서 부르는 꼴(`Zone.current.print(...)`)과 `debugPrint` 로
# 시작하는 이름 전부(`debugPrintSynchronously` 등)를 함께 잡는다.
# 주석 줄은 뺀다(이 파일들이 규칙 자체를 서술하는 자리다).
if [ -d "$LOC_DIR" ]; then
  log_hits=$(grep -rnE --include='*.dart' \
    '\b(print|debugPrint[A-Za-z]*)[[:space:]]*\(' "$LOC_DIR" 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//')
  if [ -n "$log_hits" ]; then
    {
      echo "$LOC_DIR 이 콘솔·기기 로그에 값을 적습니다 (좌표는 이 계층 안에서 태어나 그 안에서 죽는다):"
      echo "$log_hits"
    } >&2
    fail=2
  fi
fi

exit $fail
