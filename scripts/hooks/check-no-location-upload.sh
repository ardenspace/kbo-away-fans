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
#   2) lib/location/ 이 **업로드 계층 둘**을 import 하지 않는다
#      (step 2.5 에서 lib/backend/, 2026-09-04 round 3 에서 lib/analytics/).
#      2.5 가 위치 계층을 새로 열었고 4.1·5.2 가 그 안에 좌표를 읽는 자리를
#      짓는다. 그 폴더에는 1) 을 그대로 넓힐 수 없다(좌표가 정당하다) — 대신
#      좌표가 서버로 나갈 수 있는 길인 업로드 계층 호출을 막는다.
#      lib/analytics/ 를 뒤늦게 더한 것은 그 폴더가 **두 번째 업로드 계층**인데
#      짝 훅(check-firebase-import-boundary.sh)이 firebase SDK 경계에서 그
#      폴더를 명시적으로 면제하기 때문이다: 4.1 round 3 의 지휘자가
#      `import '../analytics/analytics.dart';` 한 줄과
#      `logPlaceTap(stadiumId: '${position.latitude},${position.longitude}',
#      category: 'x')` 로 실 좌표를 구글 서버로 보내고 훅 4종·analyze·시험
#      657개가 전부 초록불인 것을 재현했다(분석 래퍼의 화이트리스트는 파라미터
#      **키**만 보고 값은 보지 않는다).
#
#   3) lib/location/ 이 값을 밖으로 내보낼 수 있는 패키지를 import 하지
#      않는다 (2026-09-04 [L] 결정의 짝, round 3 에서 넓혔다).
#      2) 만으로는 이 폴더 안에서 `package:http` 로 좌표를 직접 보내는 길이
#      열려 있었다 — 검증자가 재현했고 훅 4종이 전부 exit 0 이었다. 이 폴더의
#      코드가 하는 일은 "판정 하나를 참·거짓으로 답하는 것"뿐이라 바깥으로
#      값을 내보내는 패키지를 쓸 자리가 없고, 그래서 그 집합을 통째로 막는다.
#      firebase_*·cloud_* 는 짝인 check-firebase-import-boundary.sh 가 이미
#      lib/backend/·lib/analytics/ 밖 전체에서 막으므로 여기서 다시 세지
#      않는다(같은 위반을 두 번 찍지 않기 위해서다).
#
#   4) lib/location/ 에 값을 담아 둘 자리를 두지 않는다 — 최상위 변수도,
#      클래스 안의 static 저장소도 (같은 [L] 결정의 짝, round 3 에서 넓혔다).
#      최상위 공개 변수 한 줄(`DeviceFix? lastSpot;`)이면 판정에 쓴 좌표가
#      라이브러리 밖에서 읽히는데, 결과 타입 파수꾼은 StadiumVisitResult 의
#      몸통만 보므로 그것을 놓쳤다(검증자 재현, 시험 644개·analyze 초록불).
#      round 3 이 같은 자리의 구멍 둘을 더 막았다: (a) 두 칸 들여쓴
#      `static DeviceFix? lastSpot;` 은 열 0 만 보던 옛 검사에 아예 보이지
#      않았고 결과 타입 파수꾼도 `final` 줄만 봐서 놓쳤다 — 그 필드는
#      `StadiumVisitResult.lastSpot!.lat` 으로 라이브러리 밖에서 읽힌다;
#      (b) `Provider<List<DeviceFix>>` 는 허용 규칙이 provider 타입 이름만 보고
#      담긴 것을 보지 않아 통과했다.
#      허용하는 예외는 셋이다: `const`(컴파일 시각 값이라 실행 중에 얻은
#      좌표를 담을 수 없다), `static const`(같은 까닭), 그리고 이 계층의 공개
#      표면인 읽기 전용 provider — 다만 그 타입 인자가 **홑 식별자**여야 한다
#      (`Provider<LocationPermissionGateway>` 는 통과, `Provider<List<...>>` 는
#      통과하지 못한다: 변경 가능한 통이 곧 좌표를 담아 둘 자리다).
#      StateProvider·NotifierProvider 처럼 **상태를 들고 있는** provider 도
#      통과하지 못한다. 5.2(홈 상단 현재 위치)가 다른 모양의 provider 를
#      필요로 하면 이 검사를 의도적으로 넓히고 ADR 을 남긴다. 그것이 이 검사의
#      목적이다: 반출 경로를 만드는 변경이 눈에 띄게 하는 것.
#
#      선언 한 줄이 80칸을 넘겨 `dart format` 이 `=` 뒤에서 자른 모양은
#      **통과해야 한다** — 사람이 고른 모양이 아니라 포매터가 만드는 모양이라,
#      막으면 이름이 긴 provider 를 하나 더하는 것만으로 까닭 없이 커밋이
#      막힌다(round 3 이 오탐으로 재현). 그래서 이 검사는 grep 이 아니라 awk
#      로 돌며 `=` 로 끝나는 줄을 다음 줄과 이어 붙여서 본다.
#
#   5) lib/location/ 이 좌표를 콘솔·기기 로그에 적지 않는다 (round 3 신설).
#      "어디에도 적지 않는다"는 약속에서 import 검사가 닿지 못하는 자리가 하나
#      남는다: `print` 는 dart:core 라 import 가 없고, `debugPrint` 는 이 계층이
#      정당하게 쓰는 flutter/foundation 이 함께 내보낸다. 이 폴더의 코드는
#      판정 하나를 답할 뿐이라 찍을 것이 없으므로 **직접 호출**을 막는다.
#      한계는 정직하게 적어 둔다: 이 검사가 잡는 것은 이름을 그대로 부르는
#      줄뿐이고, 함수를 변수에 담아 부르는 우회는 잡지 못한다(3)·4) 와 달리 이
#      검사만으로 "적을 수 없다"가 되지는 않는다 — 눈에 띄게 할 뿐이다).
#
# **이 검사들이 막지 않는 것.** dart:core·dart:async·flutter/foundation 은
# 막지 않는다 — 앞의 둘은 언어의 바닥이고(Future·Completer 없이는 이 계층이
# 서지 않는다), 셋째는 3) 이 dart:io 를 막으면서 `Platform.isAndroid` 의
# 대체(`defaultTargetPlatform`)로 지목한 자리다. 그리고 판정 API 자체가
# 신탁이라 반복 질의로 좌표가 좁혀지는 성질은 어떤 검사로도 없앨 수 없다
# (`.wellbegun/decisions.md` 2026-09-04 `[L]`, test/probe/coord_oracle_probe_test.dart).
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

# 2) 좌표를 다루는 계층이 업로드 계층 둘에 닿지 않는다 (lib/location/CLAUDE.md
# 의 같은 규칙). 백엔드로 넘길 판정 결과가 있으면 두 계층을 잇는 자리는
# 부르는 쪽(feature)이지 이 폴더가 아니다. 상대 경로('../backend/...')와
# 패키지 경로('package:kbo_away_fans/backend/...') 를 한 패턴으로 잡는다 —
# 여는 따옴표는 홑([']) 과 겹(["]) 을 모두 받는다(Dart 는 둘 다 유효한 문자열
# 구분자라 `prefer_single_quotes` 가 없다면 이 grep 만으로는 겹따옴표 import 가
# 새 나간다).
LOC_DIR="lib/location"

if [ -d "$LOC_DIR" ]; then
  loc_hits=$(grep -rnE --include='*.dart' \
    "^[[:space:]]*(import|export)[[:space:]]+[\"'][^\"']*(backend|analytics)/" "$LOC_DIR" 2>/dev/null)
  if [ -n "$loc_hits" ]; then
    {
      echo "$LOC_DIR 이 업로드 계층(lib/backend/·lib/analytics/)을 import 합니다 (좌표가 서버로 나갈 길을 만들지 않는다):"
      echo "$loc_hits"
    } >&2
    fail=2
  fi
fi

# 3) 좌표를 다루는 계층이 값을 내보낼 수 있는 패키지를 들이지 않는다.
#
# 잡는 집합은 네 갈래다. 네트워크(dart:io 의 HttpClient · http · dio ·
# web_socket_channel · grpc · googleapis · dart:html · package:web), 기기에
# 적히는 자리(shared_preferences · path_provider · hive · sqflite ·
# flutter_secure_storage · package:file — dart:io 는 File 로 양쪽에 걸친다),
# 다른 앱으로 값을 넘기는 둘(share_plus · url_launcher), 그리고 프로세스
# 경계를 넘는 자리(dart:isolate 의 SendPort · dart:developer 의 log ·
# dart:ffi · dart:js_interop · flutter 의 services — MethodChannel 로 네이티브에
# 임의 값을 넘기고 Clipboard 도 거기 있다).
#
# flutter/services.dart 를 막으면서 material·widgets·cupertino 도 함께 막는
# 까닭은 그 셋이 services.dart 를 **재수출**하기 때문이다 — 하나만 막으면
# `import 'package:flutter/material.dart';` 한 줄로 Clipboard·MethodChannel 이
# 그대로 돌아온다. 이 계층에는 위젯이 없으므로(화면은 lib/features/ 가 짓고
# 이 폴더가 내보내는 타입만 소비한다) 넷 다 쓸 자리가 없다.
#
# dart:io 를 막으면 `Platform.isAndroid` 같은 정당한 쓰임도 함께 막히는데,
# 그 자리는 flutter/foundation 의 defaultTargetPlatform 으로 쓴다.
if [ -d "$LOC_DIR" ]; then
  out_pattern='^[[:space:]]*(import|export)[[:space:]]+["'"'"']('
  out_pattern="${out_pattern}dart:(io|html|isolate|developer|ffi|js_interop)"
  out_pattern="${out_pattern}|package:(http|dio|web_socket_channel|grpc|googleapis"
  out_pattern="${out_pattern}|shared_preferences|path_provider|hive|sqflite"
  out_pattern="${out_pattern}|flutter_secure_storage|share_plus|url_launcher"
  out_pattern="${out_pattern}|file/|web/"
  out_pattern="${out_pattern}|flutter/(services|material|widgets|cupertino)\.dart))"

  out_hits=$(grep -rnE --include='*.dart' "$out_pattern" "$LOC_DIR" 2>/dev/null)
  if [ -n "$out_hits" ]; then
    {
      echo "$LOC_DIR 이 값을 밖으로 내보낼 수 있는 패키지를 import 합니다 (이 계층은 판정만 하고 아무것도 보내지 않는다):"
      echo "$out_hits"
    } >&2
    fail=2
  fi
fi

# 4) 좌표를 다루는 계층에 값을 담아 둘 자리를 두지 않는다.
#
# 보는 자리가 둘이다.
#   (a) 최상위 선언: 열 0 에서 시작하고 괄호 없이 이름 뒤에 '=' 나 ';' 가
#       오는 줄 — 함수 선언(`Future<DeviceFix?> _readDeviceFix() async {`)과
#       표현식 본문 함수(`double _radians(double d) => ...`)는 이름 뒤에 '(' 가
#       오므로 걸리지 않고, class·enum·library·import 는 그 자리에 '{' 나
#       따옴표가 온다. typedef 는 형태가 변수와 같아 이름으로 뺀다(값을 담지
#       않는 선언이다).
#   (b) 클래스 안의 static 저장소: 들여쓴 `static` 선언 중 이름 뒤에 '=' 나
#       ';' 가 오는 줄. static 메서드(`static X _fromPlatform(Y y) => ...`)는
#       그 전에 '(' 가 오므로 걸리지 않는다. static 필드는 인스턴스와 무관하게
#       `타입이름.필드` 로 라이브러리 밖에서 읽히므로 최상위 변수와 같은
#       자리다.
#
# 줄 잇기: `=` 로 끝나는 줄은 다음 줄과 이어 붙여서 본다 (`dart format` 이
# 80칸을 넘길 때 만드는 모양을 오탐하지 않기 위해서다).
if [ -d "$LOC_DIR" ]; then
  allow='^final [A-Za-z0-9_$]*Provider = Provider([.]autoDispose)?([.]family)?<[A-Za-z_][A-Za-z0-9_]*[?]?([[:space:]]*,[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[?]?)*>[(]'

  top_hits=$(find "$LOC_DIR" -type f -name '*.dart' | sort | while read -r dart_file; do
    awk -v ALLOW="$allow" -v FNAME="$dart_file" '
      function scan(cur, ln) {
        # (a) 최상위 변수
        if (cur ~ /^[A-Za-z_][A-Za-z0-9_<>?,. ]* [A-Za-z_$][A-Za-z0-9_$]* *(=|;)/ &&
            cur !~ /^(const|typedef) / && cur !~ ALLOW) {
          printf "%s:%d:%s\n", FNAME, ln, cur
        }
        # (b) 클래스 안의 static 저장소
        if (cur ~ /^[[:space:]]+static [^(]*[A-Za-z0-9_$][[:space:]]*(=|;)/ &&
            cur !~ /^[[:space:]]+static const /) {
          printf "%s:%d:%s\n", FNAME, ln, cur
        }
      }
      {
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
      echo "$LOC_DIR 에 값을 담아 둘 자리가 있습니다 (판정에 쓴 좌표가 라이브러리 밖에서 읽히는 자리다 — const 이거나 홑 식별자 타입의 읽기 전용 provider 여야 합니다):"
      echo "$top_hits"
    } >&2
    fail=2
  fi
fi

# 5) 좌표를 콘솔·기기 로그에 적지 않는다.
#
# `print` 는 dart:core 라 import 가 없고 `debugPrint` 는 이 계층이 정당하게
# 쓰는 flutter/foundation 이 함께 내보내므로, 3) 의 import 검사가 닿지 못한다.
# 주석 줄은 뺀다(이 파일들이 규칙 자체를 서술하는 자리다).
if [ -d "$LOC_DIR" ]; then
  log_hits=$(grep -rnE --include='*.dart' \
    '(^|[^A-Za-z0-9_$.])(print|debugPrint)[[:space:]]*\(' "$LOC_DIR" 2>/dev/null \
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
