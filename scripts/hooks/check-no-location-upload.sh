#!/usr/bin/env bash
# "기기가 어디에 있었는지는 서버로 올리지 않는다"는 개인정보 약속
# (decisions.md 의 데이터 소유권 XL 결정, lib/backend/CLAUDE.md 와
# lib/location/CLAUDE.md 의 같은 절)을 사람의 주의력이 아니라 검사로 지킨다 —
# 이 프로젝트 전용 신설 스크립트 (step 1.9, spec.md Enforcement plan).
#
# 검사는 넷이고 방향이 다르다:
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
#   2) lib/location/ 이 lib/backend/ 를 import 하지 않는다 (step 2.5).
#      2.5 가 위치 계층을 새로 열었고 4.1·5.2 가 그 안에 좌표를 읽는 자리를
#      짓는다. 그 폴더에는 1) 을 그대로 넓힐 수 없다(좌표가 정당하다) — 대신
#      좌표가 서버로 나갈 수 있는 유일한 길인 업로드 계층 호출을 막는다.
#
#   3) lib/location/ 이 값을 밖으로 내보낼 수 있는 패키지를 import 하지
#      않는다 (2026-09-04 [L] 결정의 짝).
#      2) 만으로는 이 폴더 안에서 `package:http` 로 좌표를 직접 보내는 길이
#      열려 있었다 — 검증자가 재현했고 훅 4종이 전부 exit 0 이었다. 이 폴더의
#      코드가 하는 일은 "판정 하나를 참·거짓으로 답하는 것"뿐이라 바깥으로
#      값을 내보내는 패키지를 쓸 자리가 없고, 그래서 그 집합을 통째로 막는다.
#      firebase_*·cloud_* 는 짝인 check-firebase-import-boundary.sh 가 이미
#      lib/backend/·lib/analytics/ 밖 전체에서 막으므로 여기서 다시 세지
#      않는다(같은 위반을 두 번 찍지 않기 위해서다).
#
#   4) lib/location/ 에 최상위 변수를 두지 않는다 (같은 [L] 결정의 짝).
#      최상위 공개 변수 한 줄(`DeviceFix? lastSpot;`)이면 판정에 쓴 좌표가
#      라이브러리 밖에서 읽히는데, 결과 타입 파수꾼은 StadiumVisitResult 의
#      몸통만 보므로 그것을 놓쳤다(검증자 재현, 시험 644개·analyze 초록불).
#      허용하는 예외는 둘뿐이다: `const`(컴파일 시각 값이라 실행 중에 얻은
#      좌표를 담을 수 없다)와 이 계층의 공개 표면인 읽기 전용 provider
#      (`final xProvider = Provider<...>`). StateProvider·NotifierProvider 처럼
#      **상태를 들고 있는** provider 는 통과하지 못한다 — 그것이 곧 좌표를
#      담아 둘 자리이기 때문이다. 5.2(홈 상단 현재 위치)가 다른 모양의
#      provider 를 필요로 하면 이 검사를 의도적으로 넓히고 ADR 을 남긴다.
#      그것이 이 검사의 목적이다: 반출 경로를 만드는 변경이 눈에 띄게 하는 것.
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

# 2) 좌표를 다루는 계층이 업로드 계층에 닿지 않는다 (lib/location/CLAUDE.md
# 의 같은 규칙). 백엔드로 넘길 판정 결과가 있으면 두 계층을 잇는 자리는
# 부르는 쪽(feature)이지 이 폴더가 아니다. 상대 경로('../backend/...')와
# 패키지 경로('package:kbo_away_fans/backend/...') 를 한 패턴으로 잡는다 —
# 여는 따옴표는 홑([']) 과 겹(["]) 을 모두 받는다(Dart 는 둘 다 유효한 문자열
# 구분자라 `prefer_single_quotes` 가 없다면 이 grep 만으로는 겹따옴표 import 가
# 새 나간다).
LOC_DIR="lib/location"

if [ -d "$LOC_DIR" ]; then
  loc_hits=$(grep -rnE --include='*.dart' \
    "^[[:space:]]*(import|export)[[:space:]]+[\"'][^\"']*backend/" "$LOC_DIR" 2>/dev/null)
  if [ -n "$loc_hits" ]; then
    {
      echo "$LOC_DIR 이 업로드 계층(lib/backend/)을 import 합니다 (좌표가 서버로 나갈 길을 만들지 않는다):"
      echo "$loc_hits"
    } >&2
    fail=2
  fi
fi

# 3) 좌표를 다루는 계층이 값을 내보낼 수 있는 패키지를 들이지 않는다.
#
# 잡는 집합은 두 갈래다. 네트워크(dart:io 의 HttpClient · http · dio ·
# web_socket_channel · grpc · googleapis · dart:html)와 기기에 적히는 자리
# (shared_preferences · path_provider · hive · sqflite · flutter_secure_storage
# — dart:io 는 File 로 양쪽에 걸친다). 마지막 둘(share_plus · url_launcher)은
# 서버가 아니라 **다른 앱**에 값을 넘기는 길이라 함께 막는다. 이 저장소가
# 실제로 쓰는 것(http · shared_preferences · path_provider · share_plus ·
# url_launcher)과 이 계층에 흔히 들어올 만한 것을 함께 본다.
#
# dart:io 를 막으면 `Platform.isAndroid` 같은 정당한 쓰임도 함께 막히는데,
# 그 자리는 flutter/foundation 의 defaultTargetPlatform 으로 쓴다.
if [ -d "$LOC_DIR" ]; then
  out_pattern='^[[:space:]]*(import|export)[[:space:]]+["'"'"']('
  out_pattern="${out_pattern}dart:(io|html)"
  out_pattern="${out_pattern}|package:(http|dio|web_socket_channel|grpc|googleapis"
  out_pattern="${out_pattern}|shared_preferences|path_provider|hive|sqflite"
  out_pattern="${out_pattern}|flutter_secure_storage|share_plus|url_launcher))"

  out_hits=$(grep -rnE --include='*.dart' "$out_pattern" "$LOC_DIR" 2>/dev/null)
  if [ -n "$out_hits" ]; then
    {
      echo "$LOC_DIR 이 값을 밖으로 내보낼 수 있는 패키지를 import 합니다 (이 계층은 판정만 하고 아무것도 보내지 않는다):"
      echo "$out_hits"
    } >&2
    fail=2
  fi
fi

# 4) 좌표를 다루는 계층에 최상위 변수를 두지 않는다.
#
# "최상위 변수 선언" 은 열 0 에서 시작하고, 괄호 없이 이름 뒤에 '=' 나 ';' 가
# 오는 줄로 잡는다 — 함수 선언(`Future<DeviceFix?> _readDeviceFix() async {`)과
# 표현식 본문 함수(`double _radians(double d) => ...`)는 이름 뒤에 '(' 가 오므로
# 걸리지 않고, class·enum·library·import 는 그 자리에 '{' 나 따옴표가 온다.
# typedef 는 형태가 변수와 같아 이름으로 뺀다(값을 담지 않는 선언이다).
#
# 남는 것이 곧 값을 담는 자리이고, 허용은 위 4) 주석의 둘뿐이다.
if [ -d "$LOC_DIR" ]; then
  top_hits=$(grep -rnE --include='*.dart' \
    '^[A-Za-z_][A-Za-z0-9_<>?,. ]* [A-Za-z_$][A-Za-z0-9_$]* *(=|;)' "$LOC_DIR" 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:(const |typedef )' \
    | grep -vE '^[^:]+:[0-9]+:final [A-Za-z0-9_$]*Provider = Provider<')
  if [ -n "$top_hits" ]; then
    {
      echo "$LOC_DIR 에 최상위 변수가 있습니다 (판정에 쓴 좌표가 라이브러리 밖에서 읽히는 자리다 — const 이거나 읽기 전용 provider 여야 합니다):"
      echo "$top_hits"
    } >&2
    fail=2
  fi
fi

exit $fail
