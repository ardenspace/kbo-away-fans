#!/usr/bin/env bash
# firebase_*·cloud_firestore import 가 lib/backend/·lib/analytics/ 밖에
# 나타나면 실패한다 — 이 프로젝트 전용 신설 스크립트 (step 1.9,
# spec.md Enforcement plan).
#
# 사이클 1이 지도 SDK·날씨에 세운 경계("SDK import 는 전용 계층 안에만")를
# 백엔드에도 같은 방식으로 강제한다(lib/backend/REGISTRY.md 규칙 1,
# lib/backend/CLAUDE.md "SDK import 는 이 폴더 안에만" 절).
# lib/analytics/ 는 사이클 1의 분석 래퍼라 예외로 남는다.
#
# 잡는 패턴과 예외 경로는 .wellbegun/plan.md step 2.2 boundary test 의 grep
# 한 줄과 같다:
#   grep -rnE "package:(firebase_|cloud_firestore)" lib --include='*.dart' \
#     | grep -vE '^lib/(backend|analytics)/'
#
# 위반은 stderr 에 찍고 exit 2 (Claude Code PostToolUse 훅이 읽는 신호).
set -u
cd "$(dirname "$0")/../.." || exit 1

hits=$(grep -rnE --include='*.dart' 'package:(firebase_|cloud_firestore)' lib 2>/dev/null \
  | grep -vE '^lib/(backend|analytics)/')

if [ -n "$hits" ]; then
  {
    echo "firebase_*/cloud_firestore import 가 lib/backend/·lib/analytics/ 밖에 있습니다:"
    echo "$hits"
  } >&2
  exit 2
fi
exit 0
