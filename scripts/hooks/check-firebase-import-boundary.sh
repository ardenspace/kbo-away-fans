#!/usr/bin/env bash
# SDK import 가 전용 계층 밖에 나타나면 실패한다 — 이 프로젝트 전용 신설
# 스크립트 (step 1.9, spec.md Enforcement plan). 짝이 둘이다:
#
#   - 백엔드 SDK(firebase_*·cloud_firestore·cloud_functions·google_sign_in·
#     카카오) ↔ lib/backend/·lib/analytics/ (step 1.9)
#   - 위치 권한 플러그인(permission_handler) ↔ lib/location/location.dart
#     (step 2.5)
#   - 좌표 플러그인(geolocator) ↔ lib/location/visit_check.dart (step 4.1)
#
# 사이클 1이 지도 SDK·날씨에 세운 경계("SDK import 는 전용 계층 안에만")를
# 백엔드에도 같은 방식으로 강제한다(lib/backend/REGISTRY.md 규칙 1,
# lib/backend/CLAUDE.md "SDK import 는 이 폴더 안에만" 절 — 카카오 SDK도 같은
# 경계 대상으로 명시한다).
# lib/analytics/ 는 사이클 1의 분석 래퍼라 예외로 남는다.
#
# 잡는 패턴은 .wellbegun/plan.md step 2.2 boundary test(firebase_*·
# cloud_firestore)와 step 2.3 boundary test(package:kakao)의 grep 두 줄을 합친 뒤,
# lib/backend/REGISTRY.md 가 경계라고 **서술하는** 나머지 둘(`google_sign_in`·
# `cloud_functions`)까지 넓힌 것이다 — 로스터가 "여기까지"라고 적어 둔 import 는
# 검사도 함께 잡아야 그 문장이 참이 된다(같은 유형을 넓힌 선례: 커밋 1a15383 이
# README 의 "카카오 SDK 경계" 서술에 맞춰 패턴을 넓혔다):
#   grep -rnE "package:(firebase_|cloud_firestore|cloud_functions|google_sign_in|kakao)" \
#     lib --include='*.dart' | grep -vE '^lib/(backend|analytics)/'
#
# 위반은 stderr 에 찍고 exit 2 (Claude Code PostToolUse 훅이 읽는 신호).
set -u
cd "$(dirname "$0")/../.." || exit 1

fail=0

hits=$(grep -rnE --include='*.dart' \
  'package:(firebase_|cloud_firestore|cloud_functions|google_sign_in|kakao)' lib 2>/dev/null \
  | grep -vE '^lib/(backend|analytics)/')

if [ -n "$hits" ]; then
  {
    echo "백엔드 SDK import(firebase_*/cloud_firestore/cloud_functions/google_sign_in/kakao) 가 lib/backend/·lib/analytics/ 밖에 있습니다:"
    echo "$hits"
  } >&2
  fail=2
fi

# 위치 권한 플러그인은 파일 하나에만 둔다 (step 2.5).
#
# 여기는 폴더가 아니라 **파일**이 경계다 — lib/location/location.dart 의 첫
# 문단이 "이 import 는 lib/ 안에서 이 파일에만 둔다"라고 서술하고,
# lib/location/CLAUDE.md 가 같은 규칙을 폴더의 read-first 로 적는다. 위 짝을
# 넓힌 것과 같은 까닭이다(커밋 acac310): 로스터가 경계라고 서술하는 import 는
# 검사도 함께 잡아야 그 문장이 참이 된다. 폴더가 아니라 파일로 좁혀도 4.1·5.2
# 가 이 폴더에 파일을 더할 때 걸리적거리지 않는다 — 새 파일은 플러그인을
# 직접 부르지 않고 이 파일이 내보내는 타입을 쓰면 된다.
location_hits=$(grep -rnE --include='*.dart' 'package:permission_handler' lib 2>/dev/null \
  | grep -vE '^lib/location/location\.dart:')

if [ -n "$location_hits" ]; then
  {
    echo "위치 권한 플러그인 import(permission_handler) 가 lib/location/location.dart 밖에 있습니다:"
    echo "$location_hits"
  } >&2
  fail=2
fi

# 좌표를 읽는 플러그인도 파일 하나에만 둔다 (step 4.1).
#
# 위 짝과 같은 규칙이지만 **다른 파일**이 경계인 것에는 까닭이 있다.
# lib/location/visit_check.dart 가 기기의 좌표를 실제로 읽는 자리를
# private 함수 하나(_readDeviceFix)로 두고, 그 라이브러리 안에서 판정까지
# 끝낸 뒤 좌표가 없는 결과만 내보낸다. 좌표를 얻는 통로를 그 파일 안에
# 가둬 두는 것이 "기기가 어디에 있었는지는 서버로 올리지 않는다"(XL 결정)를
# 사람의 주의력이 아니라 **구조**로 지키는 방법이다 — geolocator import 가
# 다른 파일로 새면 그 파일이 좌표를 얻어 어디로든 넘길 수 있게 되므로,
# 그 순간 이 검사가 막는다. (permission_handler 를 location.dart 로 못 박은
# step 2.5 의 판단과 같은 유형이고, 두 플러그인이 서로 다른 파일에 사는 것은
# 각자가 지키는 것이 다르기 때문이다: 권한 상태의 단일 접점 ↔ 좌표의 단일
# 통로.)
fix_hits=$(grep -rnE --include='*.dart' 'package:geolocator' lib 2>/dev/null \
  | grep -vE '^lib/location/visit_check\.dart:')

if [ -n "$fix_hits" ]; then
  {
    echo "좌표 플러그인 import(geolocator) 가 lib/location/visit_check.dart 밖에 있습니다:"
    echo "$fix_hits"
  } >&2
  fail=2
fi

exit $fail
