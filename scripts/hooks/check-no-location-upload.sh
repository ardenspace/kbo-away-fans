#!/usr/bin/env bash
# "기기가 어디에 있었는지는 서버로 올리지 않는다"는 개인정보 약속
# (decisions.md 의 데이터 소유권 XL 결정, lib/backend/CLAUDE.md 와
# lib/location/CLAUDE.md 의 같은 절)을 사람의 주의력이 아니라 검사로 지킨다 —
# 이 프로젝트 전용 신설 스크립트 (step 1.9, spec.md Enforcement plan).
#
# 검사는 다섯이고 방향이 다르다:
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
#      그 눈에 띔이 이 검사의 목적이다(2026-09-04 `[S]` 가 같은 논리를
#      검사 4) 에 대해 이미 적어 두었다).
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
#      하나 붙는다: 그 파일에 `export` 가 없어야 한다. Dart 의 import 는
#      전이되지 않지만 `export` 는 전이되므로, 그 한 줄이면 이 폴더의 import
#      을 하나도 건드리지 않고 값을 내보내는 패키지가 이 계층에 선다 —
#      round 4 의 구현자가 재현했다: `lib/content/kst.dart` 에
#      `export 'package:http/http.dart';` 한 줄과 visit_check.dart 안의
#      `await Client().post(...)` 한 줄로 실 좌표가 외부 서버로 나가는데
#      훅 2종이 exit 0, flutter analyze 도 초록불이었다. kst.dart 에 export 가
#      없으면 이 폴더의 이름 표면은 위 목록으로 닫힌다.
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
#      가시성이기 때문이다. part 파일을
#      더하면 그 파일이 같은 라이브러리 안에 들어와 `_readDeviceFix` 같은
#      private 통로를 공개 이름으로 다시 내보낼 수 있는데, 그 파일 자신은
#      geolocator 를 import 하지 않으므로 짝 훅(check-firebase-import-boundary.sh)
#      에도 걸리지 않는다. round 4 의 지휘자가
#      `Future<DeviceFix?> readFixFromPart() => _readDeviceFix();` 로 재현해
#      훅 2종이 exit 0 인 것을 확인했다. 이 폴더의 파일은 각자 하나의
#      라이브러리라는 것이 겹 1·2 가 서는 전제이므로, 그 전제를 검사로 못
#      박는다(짝으로 경계 시험의 겹 1 파수꾼도 같은 것을 잰다).
#
#   4) lib/location/ 에 값을 담아 둘 자리를 두지 않는다 — 최상위 변수도,
#      클래스 안의 static 저장소도, **인스턴스 필드도** (같은 [L] 결정의 짝,
#      round 3 에서 static 을, round 4 에서 인스턴스 필드를 더했다).
#      최상위 공개 변수 한 줄(`DeviceFix? lastSpot;`)이면 판정에 쓴 좌표가
#      라이브러리 밖에서 읽히는데, 결과 타입 파수꾼은 StadiumVisitResult 의
#      몸통만 보므로 그것을 놓쳤다(검증자 재현, 시험 644개·analyze 초록불).
#      round 3 이 같은 자리의 구멍 둘을 더 막았다: (a) 두 칸 들여쓴
#      `static DeviceFix? lastSpot;` 은 열 0 만 보던 옛 검사에 아예 보이지
#      않았고 결과 타입 파수꾼도 `final` 줄만 봐서 놓쳤다 — 그 필드는
#      `StadiumVisitResult.lastSpot!.lat` 으로 라이브러리 밖에서 읽힌다;
#      (b) `Provider<List<DeviceFix>>` 는 허용 규칙이 provider 타입 이름만 보고
#      담긴 것을 보지 않아 통과했다.
#      round 4 가 막은 것은 **클래스의 인스턴스 필드**다: 검사가 static 만
#      보고 있어서 아래가 통과했고(훅 4종·analyze·시험 660개 초록불),
#      검증자가 탐침으로 라이브러리 밖에서 실 좌표를 읽어 냈다.
#        class SpotLog { final List<DeviceFix> seen = []; void add(...) ... }
#        final spotLogProvider = Provider<SpotLog>((ref) => SpotLog());
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
#
#      **"담을 수 없는 타입"** 은 (i) 값이 변하지 않는 dart:core 기본형
#      (bool·double·int·num·String·Duration·DateTime) 과 (ii) **이 폴더가
#      스스로 선언한 타입 이름들**의 합이다. 뒤엣것을 허용해도 고리가 닫히는
#      까닭은, 그 타입의 필드가 다시 이 검사를 지나기 때문이다 —
#      `Provider<SpotLog>` 는 통과해도 `SpotLog` 안의 `List<DeviceFix>` 에서
#      막힌다. 반대로 폴더 밖의 이름은 통과하지 못하므로
#      `Provider<StringBuffer>`·`Provider<List>` 같은 "홑 식별자인데 변경
#      가능한 통"이 함께 닫힌다(round 3 의 홑 식별자 규칙에 남아 있던
#      구멍이다).
#
#      round 4 는 여기서 **오탐 하나도 풀었다**: 이름이 `Provider` 로 끝나지
#      않는 읽기 전용 provider(`final gateRef = Provider<int>((ref) => 1);`)가
#      exit 2 였다. 안전을 만드는 것은 변수 **이름**이 아니라 오른쪽에 오는
#      **생성자**라, 이름 조건을 지우고 생성자와 타입 인자만 본다.
#
#      선언 한 줄이 80칸을 넘겨 `dart format` 이 `=` 뒤에서 자른 모양은
#      **통과해야 한다** — 사람이 고른 모양이 아니라 포매터가 만드는 모양이라,
#      막으면 이름이 긴 provider 를 하나 더하는 것만으로 까닭 없이 커밋이
#      막힌다(round 3 이 오탐으로 재현). 그래서 이 검사는 grep 이 아니라 awk
#      로 돌며 `=` 로 끝나는 줄을 다음 줄과 이어 붙여서 본다.
#
#      **이 검사가 보는 자리**: 열 0 의 선언, 어느 깊이든 `static` 으로
#      시작하는 선언, 그리고 **클래스·enum·mixin 몸통 안의 두 칸 들여쓴
#      선언**. 클래스 안인지를 세는 것은 열 0 의 `class`/`enum`/`mixin` 줄과
#      열 0 의 `}` 다 — 그래서 최상위 함수 몸통의 지역 변수(같은 두 칸
#      들여쓰기)는 보지 않는다.
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
# **이 검사들이 막지 않는 것.** dart:core 는 막을 수 없다 — import 없이 서는
# 유일한 라이브러리이고 `print` 가 거기 있다(검사 5 가 이름으로만 받는다).
# 그리고 판정 API 자체가 신탁이라 반복 질의로 좌표가 좁혀지는 성질은 어떤
# 검사로도 없앨 수 없다 (`.wellbegun/decisions.md` 2026-09-04 `[L]`,
# test/probe/coord_oracle_probe_test.dart).
#
# 위반은 stderr 에 찍고 exit 2 (Claude Code PostToolUse 훅이 읽는 신호).
set -u
cd "$(dirname "$0")/../.." || exit 1

fail=0

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

  # 허용 목록의 유일한 폴더 밖 문에 붙는 짝 검사 — 그 파일에 `export` 가
  # 있으면 이 폴더의 import 를 하나도 건드리지 않고 새 이름이 이 계층에 선다
  # (Dart 의 import 는 전이되지 않지만 export 는 전이된다).
  DOOR="lib/content/kst.dart"
  if [ -f "$DOOR" ]; then
    door_hits=$(grep -nE "^[[:space:]]*export[[:space:]]+[\"']" "$DOOR" 2>/dev/null)
    if [ -n "$door_hits" ]; then
      {
        echo "$DOOR 이 무언가를 재수출합니다 — 이 파일은 $LOC_DIR 허용 목록의 유일한 폴더 밖 문이라, 그 재수출은 곧 위 허용 목록에 이름을 몰래 더하는 것입니다:"
        echo "$door_hits"
      } >&2
      fail=2
    fi
  fi
fi

# 4) 좌표를 다루는 계층에 값을 담아 둘 자리를 두지 않는다.
if [ -d "$LOC_DIR" ]; then
  # 이 폴더가 스스로 선언하는 타입 이름들 — 허용 타입 집합의 절반이다.
  declared=$(grep -rhoE --include='*.dart' \
    '^(abstract +)?(class|enum|mixin|typedef|extension type) +[A-Za-z_][A-Za-z0-9_]*' \
    "$LOC_DIR" 2>/dev/null | awk '{ print $NF }' | sort -u | paste -sd'|' -)
  TYPES='bool|double|int|num|String|Duration|DateTime'
  [ -n "$declared" ] && TYPES="$TYPES|$declared"

  allow='^final [A-Za-z0-9_$]+ = Provider([.]autoDispose)?([.]family)?<('"$TYPES"')[?]?([[:space:]]*,[[:space:]]*('"$TYPES"')[?]?)*>[(]'

  top_hits=$(find "$LOC_DIR" -type f -name '*.dart' | sort | while read -r dart_file; do
    awk -v ALLOW="$allow" -v TYPES="$TYPES" -v FNAME="$dart_file" '
      BEGIN { n = split(TYPES, t, "|"); for (i = 1; i <= n; i++) ok[t[i]] = 1 }

      # 선언의 앞부분(수식어 + 타입 + 이름)만 잘라 온다 — 괄호·꺾쇠 밖의
      # 첫 ";" 나 "=" 까지다. "=>" 와 "==" 는 선언의 끝이 아니므로 빈 문자열을
      # 돌려준다(표현식 본문 메서드·게터가 여기서 빠진다).
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
      function fieldOk(s,   arr, n, i, type) {
        n = topTokens(s, arr)
        if (n < 2) return 1                       # 이름 하나뿐 — 선언이 아니다
        if (arr[n] ~ /[(]/) return 1              # 메서드·생성자
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

      function scan(cur, ln,   ind, body, decl) {
        # (a) 최상위 선언 — 열 0 에서 시작하고 괄호 없이 이름 뒤에 "=" 나 ";"
        #     가 오는 줄. 함수 선언·표현식 본문 함수는 이름 뒤에 "(" 가 오므로
        #     걸리지 않고, class·enum·library·import 는 그 자리에 "{" 나
        #     따옴표가 온다. typedef 는 값을 담지 않는 선언이라 이름으로 뺀다.
        if (cur ~ /^[A-Za-z_][A-Za-z0-9_<>?,. ]* [A-Za-z_$][A-Za-z0-9_$]* *(=|;)/ &&
            cur !~ /^(const|typedef) / && cur !~ ALLOW) {
          printf "%s:%d:%s\n", FNAME, ln, cur
        }

        # 열 0 의 class/enum/mixin 줄과 열 0 의 "}" 로 클래스 몸통을 센다.
        if (cur ~ /^(abstract +)?(class|enum|mixin|extension) /) inClass = 1
        else if (cur ~ /^}/) inClass = 0

        # (b)·(c) 클래스 몸통의 선언 — 두 칸 들여쓴 줄과, 깊이와 무관하게
        #     static 으로 시작하는 줄.
        ind = match(cur, /[^ ]/) - 1
        if (ind < 0) return
        body = substr(cur, ind + 1)
        if (body !~ /^[A-Za-z_$]/) return
        if (!(body ~ /^static /) && !(inClass && ind == 2)) return
        decl = declPart(body)
        if (decl != "" && !fieldOk(decl)) printf "%s:%d:%s\n", FNAME, ln, cur
      }

      {
        # 줄 잇기: "=" 로 끝나는 줄은 다음 줄과 이어 붙여서 본다 (`dart format`
        # 이 80칸을 넘길 때 만드는 모양을 오탐하지 않기 위해서다).
        if (pending != "") {
          cur = $0
          sub(/^[[:space:]]+/, "", cur)
          cur = pending " " cur
        } else {
          cur = $0
          ln = FNR
        }
        pending = ""
        if (cur ~ /=[[:space:]]*$/) { pending = cur; next }
        scan(cur, ln)
      }
      END { if (pending != "") scan(pending, ln) }
    ' "$dart_file"
  done)

  if [ -n "$top_hits" ]; then
    {
      echo "$LOC_DIR 에 값을 담아 둘 자리가 있습니다 (판정에 쓴 좌표가 라이브러리 밖에서 읽히는 자리다 — const 이거나, 담을 수 없는 타입의 final 필드이거나, 그런 타입 인자를 받는 읽기 전용 provider 여야 합니다):"
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
