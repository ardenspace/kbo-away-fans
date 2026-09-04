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
# **그리고 반대 방향이 round 6 의 거부 사유였다: 오탐.** 검사 4) 가 평범한
# Dart 세 모양(값 나열 뒤에 멤버가 오는 enum · `@override` 가 붙은 필드 ·
# 몸통 없는 게터 선언)을 잡았는데, 이 헤더가 "일부러 거절하는 정당한 모양은
# 아래 **둘**"이라고 **닫힌 목록**으로 적어 두어 그 문장이 거짓이었다. 이
# 검사는 CI 에도 걸려 있으므로 오탐은 로컬 훅뿐 아니라 CI 도 막는다. 그래서
# 아래 그 목록은 열린 모양으로 다시 썼다 — **무엇을 열거하든 그것이 전부라고
# 단언하기 전에, 실제로 그것이 전부인지 확인했는지 자문하십시오.**
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
#   4) lib/location/ 에 값을 담아 둘 자리를 두지 않는다 — 최상위 변수도,
#      클래스 안의 static 저장소도, **인스턴스 필드도** (같은 [L] 결정의 짝,
#      round 3 에서 static 을, round 4 에서 인스턴스 필드를, round 5 에서
#      들여쓰기와 줄바꿈에 대한 민감함을 고쳤다).
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
#      **허용하는 모양** — 여기서도 거부 목록이 아니라 허용 목록이다.
#        · `const` · `static const` (컴파일 시각 값이라 실행 중에 얻은 좌표를
#          담을 수 없다)
#        · 최상위 읽기 전용 provider: `final <이름> = Provider<T>(` 꼴이고
#          T 가 아래 "담을 수 없는 타입" 집합 안에 있을 때.
#          StateProvider·NotifierProvider 처럼 상태를 들고 있는 provider 는
#          통과하지 못하고, FutureProvider·StreamProvider 도 마찬가지다
#          (5.2 가 필요로 하면 그때 의도적으로 넓히고 ADR 을 남긴다).
#        · 클래스의 `final` 필드: 타입이 "담을 수 없는 타입"이거나 함수
#          타입(`... Function(...)`)일 때. 함수 타입을 허용하는 것은
#          StadiumVisitChecker 의 두 이음매가 그 모양이기 때문이다.
#        · 메서드·생성자(이름 뒤에 괄호가 오는 선언)와, `=>` 로 몸통을 쓰는
#          선언 전부, 그리고 **몸통 없는 게터 선언**(`String get id;`).
#          게터는 값을 담지 못하고, 읽을 저장소 쪽이 이 검사에 먼저 걸린다.
#        · 선언 앞의 **애노테이션**(`@override final String name;`)은 걷어 낸
#          뒤 판정한다 — 애노테이션이 선언의 모양을 바꾸지는 않기 때문이다.
#          걷어 낸 뒤에 보므로 `@override final List<DeviceFix> seen;` 은
#          그대로 exit 2 다(실측).
#        · **enum 몸통의 첫 문장인 값 나열.** Dart 는 값 목록 뒤에 멤버가
#          하나라도 오면 `;` 를 요구하는데, 그것은 선언이 아니라 값 나열이다.
#          Dart 문법이 값 나열을 몸통의 첫 자리에 못 박으므로 첫 문장 하나만
#          건너뛴다 — 그 뒤의 필드는 전부 그대로 이 검사를 지난다(실측:
#          `enum E { a, b; static DeviceFix? last; }` 는 exit 2).
#
#      **round 6 이 푼 오탐 셋이 위 목록의 뒤 세 줄이다.** 셋 다 평범한 Dart
#      이고 `flutter analyze` 무지적인데 exit 2 였다: 값 나열 뒤에 게터를 하나
#      둔 enum(round 6 의 거부 사유 — 이 폴더에 이미 enum 이 둘 있다),
#      `@override` 가 붙은 필드, 그리고 추상 클래스·인터페이스·mixin 의 게터
#      선언. 앞엣것은 오류 메시지가 안내하는 "허용 타입 목록 넓히기"로는 고칠
#      수도 없었다 — 걸린 것이 타입이 아니라 값 나열이었기 때문이다.
#
#      **"담을 수 없는 타입"** 은 (i) 값이 변하지 않는 dart:core 기본형
#      (bool·double·int·num·String·Duration·DateTime) 과 (ii) **이 폴더가
#      스스로 선언한 타입 이름들**의 합이다. 뒤엣것을 허용해도 고리가 닫히는
#      까닭은, 그 타입의 필드가 다시 이 검사를 지나기 때문이다 —
#      `Provider<SpotLog>` 는 통과해도 `SpotLog` 안의 `List<DeviceFix>` 에서
#      막힌다. 반대로 폴더 밖의 이름은 통과하지 못하므로
#      `Provider<StringBuffer>`·`Provider<List>` 같은 "홑 식별자인데 변경
#      가능한 통"이 함께 닫힌다.
#
#      **이 검사가 일부러 거절하는 정당한 모양** (5.2 가 여기 걸리면 여기서
#      까닭을 찾으라고 적어 둔다). 아래는 **닫힌 목록이 아니다** — round 6 의
#      구현자가 lib/location/ 에 평범한 Dart 파일 50가지를 지어 넣어 보고
#      실측한 것들이고, 51번째가 없다고는 적지 않는다. 여기 없는 모양이
#      걸렸다면 그것이 오탐인지 정탐인지는 아래 "까닭"의 결로 판단하고,
#      오탐이면 이 목록에 실측과 함께 더하십시오.
#
#      까닭은 하나다: **이 검사는 무엇이 담길지 알 수 없는 자리를 거절한다.**
#      실측으로 확인한 것들:
#        · 최상위 `final RegExp kStadiumIdPattern = RegExp(...);` — RegExp 는
#          const 가 될 수 없고 폴더 밖의 이름이다.
#        · 최상위 `final String probeLabel = ...;` — 이 폴더에 최상위 저장소를
#          두지 않는다는 것이 이 검사의 본문이다(허용은 읽기 전용 provider 와
#          `const` 뿐).
#        · 값 타입의 `final List<String> ids;` 필드 — List 는 담을 수 있는
#          통이라, `final StringBuffer log = StringBuffer();`(실측 정탐)와
#          같은 규칙에 걸린다.
#        · **타입을 적지 않은 `final` 필드**(`final separator = ' / ';`) —
#          추론 타입이라 이 검사가 무엇이 담기는지 알 수 없다. 이것을 허용하면
#          `final spots = <DeviceFix>[];` 가 함께 열린다(그 최상위 판이 실측
#          정탐이다). 이 폴더에서는 타입을 적으십시오.
#        · `late final String name;` 과 `late` 가 붙은 모든 필드 — 값이
#          생성자 밖의 어느 시점에 들어오는 자리다. 허용 목록이 `const`·
#          `static const`·`final` 셋으로 닫혀 있다.
#        · 타입 매개변수 필드(`final T value;`) — `Box<DeviceFix>` 로 세우면
#          그대로 좌표를 담는 통이라, "홑 식별자인데 변경 가능한 통"과 같은
#          규칙에 걸린다.
#        · 레코드 타입 필드(`final (int, int) span;`) — 폴더 밖의 모양이고
#          `(double, double)` 이면 좌표 한 쌍 그대로다.
#      전부 우회하지 말고 위 허용 목록을 의도적으로 넓히고 ADR 을 남기십시오.
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
  uri_hits=$(find "$LOC_DIR" -type f -name '*.dart' | sort | while read -r dart_file; do
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
    ' "$dart_file"
  done)

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
    door_actual=$(awk '
      /^[[:space:]]*\/\// { next }
      /^(import|export|part|library)([[:space:]]|;)/ { next }
      /^[A-Za-z_$]/ {
        line = $0
        sub(/\/\/.*$/, "", line)
        if (match(line, /^(abstract[ ]+)?(base[ ]+|final[ ]+|sealed[ ]+|interface[ ]+)*(class|enum|mixin|extension|typedef)[ ]+[A-Za-z_$][A-Za-z0-9_$]*/)) {
          s = substr(line, RSTART, RLENGTH); n = split(s, a, /[ ]+/); print a[n]; next
        }
        if (match(line, /[A-Za-z_$][A-Za-z0-9_$]*[ ]*[(=;]/)) {
          s = substr(line, RSTART, RLENGTH); sub(/[ ]*[(=;]$/, "", s); print s; next
        }
        print "?" line
      }
    ' "$DOOR" | grep -v '^_' | sort -u)
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
  declared=$(grep -rhoE --include='*.dart' \
    '^(abstract +)?(class|enum|mixin) +[A-Za-z_][A-Za-z0-9_]*' \
    "$LOC_DIR" 2>/dev/null | awk '{ print $NF }' | sort -u)
  declared_fn=$(grep -rhE --include='*.dart' \
    '^typedef +[A-Za-z_][A-Za-z0-9_]* *=.*Function *[(<]' \
    "$LOC_DIR" 2>/dev/null | awk '{ print $2 }' | sort -u)
  declared=$(printf '%s\n%s\n' "$declared" "$declared_fn" | grep -v '^$' | sort -u | paste -sd'|' -)
  TYPES='bool|double|int|num|String|Duration|DateTime'
  [ -n "$declared" ] && TYPES="$TYPES|$declared"

  allow='^final [A-Za-z0-9_$]+ = Provider([.]autoDispose)?([.]family)?<('"$TYPES"')[?]?([[:space:]]*,[[:space:]]*('"$TYPES"')[?]?)*>[(]'

  top_hits=$(find "$LOC_DIR" -type f -name '*.dart' | sort | while read -r dart_file; do
    awk -v ALLOW="$allow" -v TYPES="$TYPES" -v FNAME="$dart_file" '
      BEGIN {
        n = split(TYPES, t, "|"); for (i = 1; i <= n; i++) ok[t[i]] = 1
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
        if (arr[1] == "const") return 1
        if (arr[1] == "static" && arr[2] == "const") return 1
        if (arr[1] != "final") return 0           # var·late·수식어 없음·static
        type = ""
        for (i = 2; i < n; i++) type = (type == "" ? arr[i] : type " " arr[i])
        if (type ~ /Function[(]/) return 1        # 이음매(함수 타입)
        if (n != 3) return 0
        sub(/[?]$/, "", type)
        return (type in ok)
      }

      # 문장 하나를 그 중괄호 깊이와 함께 받아 판정한다.
      function emit(stmt, depth, ln,   decl) {
        sub(/^ +/, "", stmt); sub(/ +$/, "", stmt)
        if (stmt == "") return
        # enum 몸통의 **첫 문장**은 값 나열이지 선언이 아니다. Dart 는 값
        # 목록 뒤에 멤버가 하나라도 오면 `;` 를 요구하는데, 그 `;` 로 끝나는
        # 줄을 옛 검사가 "값을 담아 둘 자리"로 읽어 `enum E { a, b; bool get
        # x => ...; }` 를 exit 2 로 냈다 (round 6 의 거부 사유). Dart 문법이
        # 값 나열을 몸통의 첫 자리에 못 박으므로, 여기서 첫 문장 하나만
        # 건너뛰어도 그 뒤의 필드는 전부 그대로 지난다.
        if (enumHead[depth]) { enumHead[depth] = 0; return }
        decl = declPart(stmt)
        if (decl == "") return                    # 함수·게터·헤더 — 값 자리가 아니다
        if (depth == 0) {
          # (a) 최상위 선언 — 이름 뒤에 "=" 나 ";" 가 오는 문장. 함수 선언과
          #     표현식 본문(`=>`)은 위 declPart 가 이미 걸러 냈고,
          #     class·enum·library·import 는 그 자리에 "{" 나 따옴표가 온다.
          #     typedef 는 값을 담지 않는 선언이라 이름으로 뺀다.
          if (stmt ~ /^[A-Za-z_][A-Za-z0-9_<>?,. ]* [A-Za-z_$][A-Za-z0-9_$]* *(=|;)/ &&
              stmt !~ /^(const|typedef) / && stmt !~ ALLOW)
            printf "%s:%d:%s\n", FNAME, ln, stmt
          return
        }
        # (b)·(c) 클래스·enum·mixin·extension 몸통의 선언과, 깊이와 무관하게
        #     static 으로 시작하는 선언. 함수 몸통 안의 지역 변수는 그 깊이를
        #     연 중괄호가 클래스의 것이 아니므로 여기 오지 않는다.
        if (!kind[depth] && stmt !~ /^static /) return
        if (!fieldOk(decl)) printf "%s:%d:%s\n", FNAME, ln, stmt
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
    ' "$dart_file"
  done)

  if [ -n "$top_hits" ]; then
    {
      echo "$LOC_DIR 에 값을 담아 둘 자리가 있습니다 (판정에 쓴 좌표가 라이브러리 밖에서 읽히는 자리다 — const 이거나, 담을 수 없는 타입의 final 필드이거나, 그런 타입 인자를 받는 읽기 전용 provider 여야 합니다. 정당한 모양인데 여기 걸렸다면 이 스크립트 헤더의 4) 에 있는 \"일부러 거절하는 정당한 모양\" 을 읽으십시오):"
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
