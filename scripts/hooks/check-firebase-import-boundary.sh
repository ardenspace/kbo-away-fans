#!/usr/bin/env bash
# SDK import 가 전용 계층 밖에 나타나면 실패한다 — 이 프로젝트 전용 신설
# 스크립트 (step 1.9, spec.md Enforcement plan). 짝이 둘이다:
#
#   - 백엔드 SDK(firebase_*·cloud_firestore·cloud_functions·google_sign_in·
#     카카오) ↔ lib/backend/·lib/analytics/ (step 1.9)
#   - 위치 권한 플러그인(permission_handler) ↔ lib/location/location.dart
#     (step 2.5)
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

exit $fail
