#!/usr/bin/env bash
# 토큰 파일 밖의 raw 디자인 값을 잡는다 — wellbegun 참조 스크립트의 Dart/Flutter 각색.
# 규칙: lib/design/ (tokens.dart, team_themes.dart) 밖의 lib/ 코드에서
#   - raw hex 색 (Color(0x...), #rrggbb)
#   - raw 치수 리터럴 (EdgeInsets/Radius/BorderRadius.circular/SizedBox/fontSize 의 숫자)
# 를 검출하면 stderr 에 위반을 찍고 exit 2 (Claude Code PostToolUse 훅이 읽는 신호).
# wiring(PostToolUse + pre-commit)은 step 1.6 에서 한다.
set -u
cd "$(dirname "$0")/../.." || exit 1

TOKEN_DIR="${TOKEN_DIR:-lib/design}"
read -ra dirs <<< "${SEARCH_DIRS:-lib}"

patterns=(
  'Color\(0x[0-9a-fA-F]+'                            # raw hex 색 생성자
  'Color\.from(ARGB|RGBO)\('                         # ARGB/RGBO 색 생성자
  '0x[fF]{2}[0-9a-fA-F]{6}'                          # 간접 hex (const int c = 0xFF...; alpha FF 접두)
  '#[0-9a-fA-F]{6}'                                  # 문자열/주석 속 hex 색
  # 3자리 축약 hex — a-f 문자가 하나 이상일 때만 (#123 같은 이슈 번호 오탐 방지)
  '#([0-9][0-9][a-fA-F]|[0-9][a-fA-F][0-9a-fA-F]|[a-fA-F][0-9a-fA-F][0-9a-fA-F])([^0-9a-fA-F]|$)'
  'EdgeInsets\.(all|only|symmetric|fromLTRB)\([^)]*[0-9]'
  '(BorderRadius|Radius)\.circular\([^)]*[0-9]'
  'SizedBox\([^)]*: *[0-9]'
  'fontSize: *[0-9]'
  'Curves\.[a-zA-Z]'                                 # raw 커브 — motion.* 토큰 경유 강제
)
regex=$(IFS='|'; echo "${patterns[*]}")

hits=$(grep -rnE --include='*.dart' "$regex" "${dirs[@]}" 2>/dev/null \
  | grep -v "^$TOKEN_DIR/" \
  | grep -vE '\.g\.dart:|\.freezed\.dart:')

if [ -n "$hits" ]; then
  {
    echo "Hardcoded design values found (use tokens from $TOKEN_DIR):"
    echo "$hits"
  } >&2
  exit 2
fi
exit 0
