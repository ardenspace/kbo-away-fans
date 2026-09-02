#!/usr/bin/env bash
# 백엔드 SDK import(firebase_*·cloud_firestore·cloud_functions·google_sign_in·
# 카카오)가 lib/backend/·lib/analytics/ 밖에 나타나면 실패한다 — 이 프로젝트
# 전용 신설 스크립트 (step 1.9, spec.md Enforcement plan).
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

hits=$(grep -rnE --include='*.dart' \
  'package:(firebase_|cloud_firestore|cloud_functions|google_sign_in|kakao)' lib 2>/dev/null \
  | grep -vE '^lib/(backend|analytics)/')

if [ -n "$hits" ]; then
  {
    echo "백엔드 SDK import(firebase_*/cloud_firestore/cloud_functions/google_sign_in/kakao) 가 lib/backend/·lib/analytics/ 밖에 있습니다:"
    echo "$hits"
  } >&2
  exit 2
fi
exit 0
