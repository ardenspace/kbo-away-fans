#!/usr/bin/env bash
# 로스터 관리 폴더의 실제 파일과 그 폴더 REGISTRY.md의 행이 어긋나면 실패한다
# — wellbegun 참조 스크립트(check-registry-sync.sh)의 이 프로젝트 각색.
#
# 짝 (spec.md Enforcement plan 기준):
#   - lib/ui/shared/          ↔ lib/ui/shared/REGISTRY.md
#   - content-pipeline/common/ ↔ content-pipeline/REGISTRY.md
#   - lib/backend/            ↔ lib/backend/REGISTRY.md (step 1.9 추가)
#
# REGISTRY 형식 규약: location 열에 저장소 기준 경로를 백틱으로 감싸 적는다
# (예: `lib/ui/shared/place_card.dart`, `content-pipeline/common/validate.mjs`).
# 검사는 양방향 — 두 방향 모두 레지스트리의 **표 행(| 로 시작하는 줄)만** 본다
# (산문 속 백틱 언급은 등록으로 치지 않는다):
#   1) 폴더의 파일(최상위, 디렉터리 제외; REGISTRY.md/CLAUDE.md 메타 파일 제외)이
#      표 행에 `basename` 또는 /basename 형태로 등장하지 않으면 FAIL
#   2) 표 행에 백틱으로 적힌 관리 폴더 경로가 실제 파일로 없으면 FAIL
# 위반은 stderr에 찍고 exit 2 (Claude Code PostToolUse 훅이 읽는 신호).
# wiring(pre-commit)은 step 1.6 에서 두 짝으로 시작했고, step 1.9 가
# lib/backend/ 짝을 더했다.
set -u
cd "$(dirname "$0")/../.." || exit 1

PAIRS=(
  "lib/ui/shared:lib/ui/shared/REGISTRY.md"
  "content-pipeline/common:content-pipeline/REGISTRY.md"
  "lib/backend:lib/backend/REGISTRY.md"
)

fail=0
for pair in "${PAIRS[@]}"; do
  dir="${pair%%:*}"; reg="${pair##*:}"
  [ -d "$dir" ] || continue

  if [ ! -f "$reg" ]; then
    echo "FAIL: registry $reg 이 없습니다 ($dir 의 로스터)" >&2
    fail=2
    continue
  fi

  # 1) 폴더 → 레지스트리: 파일이 로스터에 있어야 한다.
  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [ "$base" = "$(basename "$reg")" ] && continue
    [ "$base" = "CLAUDE.md" ] && continue
    # 표의 행(| 로 시작하는 줄)에서만 백틱/경로 고정 문자열 매칭 —
    # 산문 속 백틱 언급은 등록으로 인정하지 않는다.
    rows=$(grep -E '^[[:space:]]*\|' "$reg" 2>/dev/null)
    printf '%s\n' "$rows" | grep -qF -- "\`$base\`" \
      || printf '%s\n' "$rows" | grep -qF -- "/$base" \
      || {
        echo "FAIL: $base 이 $dir 에 있지만 $reg 로스터에 없습니다 (\`$base\` 또는 경로로 행 추가)" >&2
        fail=2
      }
  done

  # 2) 레지스트리 → 폴더: 로스터(표의 행)의 관리 폴더 경로가 실제로 존재해야 한다.
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    [ -e "$path" ] || {
      echo "FAIL: $reg 에 \`$path\` 행이 있지만 파일이 없습니다 (행 삭제 또는 파일 생성)" >&2
      fail=2
    }
  done < <(grep -E '^[[:space:]]*\|' "$reg" 2>/dev/null \
    | grep -oE "\`$dir/[^\`]+\`" | tr -d '\`' | sort -u)
done
exit $fail
