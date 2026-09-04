#!/usr/bin/env bash
# Dart 소스에서 **주석을 걷어 내는 규칙** — 이 저장소의 훅들이 함께 쓰는 한
# 자리다 (step 4.1 fresh 검증 round 9).
#
# ─────────────────────────────────────────────────────────────────────────
# 왜 이 파일이 생겼는가.
# ─────────────────────────────────────────────────────────────────────────
#
# round 9 의 거부 사유 셋 중 둘이 같은 뿌리였다: **검사가 소스 텍스트만 보고
# 주석을 가리지 못한다.** 그래서 이 저장소의 관례대로 계층 경계를 doc 주석에
# 적기만 해도 커밋과 CI 가 막혔다. 실측으로 재현한 것만 적는다.
#
#   · `check-firebase-import-boundary.sh` — `lib/features/badges/
#     stadium_visit.dart` 의 doc 주석에
#     `/// 경계: 좌표 플러그인(package:geolocator)은 …` 한 줄을 넣으면
#     `flutter analyze` 는 무지적인데 훅이 exit 2 였다. 오류 메시지도
#     "import 가 밖에 있습니다"라고 말해 고칠 길을 잘못 가리켰다 — 걸린 것은
#     import 가 아니라 주석이었다.
#   · `check-no-location-upload.sh` 의 검사 5) — 주석 제외가 "줄 머리의 `//`"
#     하나뿐이라, 블록 주석(`/* … print(x) … */`)과 코드 뒤 꼬리 주석
#     (`const int kProbe = 1; // print(x) 금지`)이 exit 2 였다. 그 검사의
#     헤더와 `.wellbegun/decisions.md` 2026-09-04 `[S]` 는 "주석 줄은
#     뺀다(이 파일들이 규칙 자체를 서술하는 자리다)"라고 적고 있었으므로,
#     오탐이 그 문장까지 함께 거짓으로 만들고 있었다.
#   · 같은 검사의 2)·2-a)·2-c) 도 같은 모양이었다(구현자가 스스로 공격해
#     찾았다): `lib/location/` 의 파일에 블록 주석으로 감싼 `import
#     'package:http/http.dart';` 세 줄을 두면 검사 2) 가 exit 2 였고,
#     `lib/content/kst.dart` 에 블록 주석으로 감싼 `export` 줄을 두면 2-a) 가,
#     블록 주석 안의 줄이 문자로 시작하면(`gameDateOf 는 …`) 2-c) 가 각각
#     exit 2 였다.
#
# 직전 라운드가 **선언 머리를 읽는 규칙**을 훅 안에서 한 자리로 모은 것과 같은
# 종류의 문제다. 주석을 걷어 내는 규칙도 여기 한 번만 적고, 부르는 쪽은 전부
# 이 파일을 통한다. **같은 개념을 두 자리에 따로 적으면 어긋남이 다시 생긴다.**
#
# ─────────────────────────────────────────────────────────────────────────
# 무엇을 하고 무엇은 하지 않는가.
# ─────────────────────────────────────────────────────────────────────────
#
# 하는 일: 파일을 한 번 훑으면서 줄 주석(`//`, `///`)과 블록 주석(`/* */`,
# 중첩까지)을 지우고 **줄 수와 줄 번호를 그대로 둔 사본**을 만든다. 그래서
# 부르는 쪽의 `grep -n`·`awk FNR` 이 원본과 같은 줄 번호를 낸다. 블록 주석은
# 지우는 대신 **공백 하나로 접는다** — 토막 사이의 주석이 두 토막을 붙여
# 버리면 부르는 쪽이 선언을 읽지 못하기 때문이다(`final/*c*/int x`).
#
# 하지 않는 일: **문자열 리터럴의 내용은 건드리지 않는다.** 검사 2) 가 import
# 의 URI 를 그 문자열에서 읽어야 하기 때문이다. 대신 문자열을 **알아보기는**
# 한다 — 그러지 않으면 `'https://…'` 의 `//` 나 `'/*'` 를 주석 표지로 잘못
# 읽는다. 실측으로 확인했다: `const a = 'https://example.com//path';` ·
# `const b = '/* not a comment */';` · `const c = "he said \"print(\" ok";` ·
# `const d = r'raw \ print( ';` 와 세 겹 문자열 안의 `//`·`/*`·`print(` 가
# 전부 사본에 그대로 남는다.
#
# 알아보는 문자열은 넷이다: 홑따옴표·겹따옴표, 그 각각의 세 겹
# (`'''`·`"""`, 줄을 넘긴다), 그리고 raw 접두어(`r'…'`) — raw 안에서는
# 역슬래시가 이스케이프가 아니다.
#
# **문자열을 알아보는 규칙이 이 저장소에 두 자리 있는 것은 목적이 다르기
# 때문이다.** 여기서는 "주석 표지가 문자열 안에 있는가"를 가리려고 보고,
# `check-no-location-upload.sh` 의 검사 4) 는 "문장을 끊는 `;`·`{` 가 문자열
# 안에 있는가"를 가리려고 본다. 둘을 하나로 합치려면 문자열 내용을 지워야
# 하는데, 그러면 검사 2) 가 URI 를 읽지 못한다. (같은 유형의 구분: 같은
# 스크립트의 `DECL_MODIFIERS` 와 필드 수식어 집합도 이름이 겹치지만 다른
# 개념이라고 그 자리에 적혀 있다.)
#
# 닫히지 않은 블록 주석이나 문자열로 파일이 끝나면 **조용히 통과하는 대신
# 실패한다**(exit 1). 그 경우 파일의 나머지가 통째로 지워져 검사들이 아무것도
# 보지 못하게 되는데, 그것이 이 저장소가 여러 번 고쳐 온 "검사가 조용히
# 헛도는" 모양이기 때문이다. 그런 파일은 `flutter analyze` 도 함께 빨간불이다.
#
# ─────────────────────────────────────────────────────────────────────────
# 쓰는 법.
# ─────────────────────────────────────────────────────────────────────────
#
#   hook_dir=$(cd "$(dirname "$0")" && pwd)
#   . "$hook_dir/dart-source.sh"
#   MIRROR=$(mktemp -d) || exit 1
#   trap 'rm -rf "$MIRROR"' EXIT
#   dart_source_mirror "$MIRROR" lib || fail=2
#
# 그 뒤로는 `$MIRROR/<원본과 같은 상대 경로>` 를 읽는다. `grep -rn` 을 쓸
# 때는 `(cd "$MIRROR" && grep -rn … lib)` 로 부르면 출력의 경로가 원본과
# 같은 모양으로 나온다.

DART_SOURCE_AWK='
  BEGIN { blockDepth = 0; openStr = ""; openRaw = 0 }
  {
    line = $0
    len = length(line)
    out = ""
    i = 1
    while (i <= len) {
      if (blockDepth > 0) {                       # 블록 주석 안 (중첩을 센다)
        two = substr(line, i, 2)
        if (two == "*/") { blockDepth--; i += 2; continue }
        if (two == "/*") { blockDepth++; i += 2; continue }
        i++
        continue
      }
      if (openStr != "") {                        # 줄을 넘긴 세 겹 문자열 안
        c = substr(line, i, 1)
        if (!openRaw && c == "\\") { out = out substr(line, i, 2); i += 2; continue }
        if (substr(line, i, length(openStr)) == openStr) {
          out = out openStr; i += length(openStr); openStr = ""; openRaw = 0
          continue
        }
        out = out c; i++
        continue
      }
      two = substr(line, i, 2)
      if (two == "//") break                      # 줄 주석 — 나머지를 버린다
      # 블록 주석은 **공백 하나로** 접는다 — 토막 사이에 있던 주석이 두 토막을
      # 붙여 버리지 않도록 (`final/*c*/int x` 가 `finalint x` 가 되면 부르는
      # 쪽이 선언을 읽지 못한다).
      if (two == "/*") { blockDepth = 1; i += 2; out = out " "; continue }

      c = substr(line, i, 1)
      raw = 0
      if (c == "r" && (substr(line, i + 1, 1) == "\047" || substr(line, i + 1, 1) == "\"") \
          && (i == 1 || substr(line, i - 1, 1) !~ /[A-Za-z0-9_$]/)) {
        out = out c; i++
        c = substr(line, i, 1)
        raw = 1
      }
      if (c == "\047" || c == "\"") {
        q3 = c c c
        if (substr(line, i, 3) == q3) {           # 세 겹 — 줄을 넘길 수 있다
          openStr = q3; openRaw = raw
          out = out q3; i += 3
          continue
        }
        out = out c; i++                          # 한 줄 문자열
        while (i <= len) {
          d = substr(line, i, 1)
          if (!raw && d == "\\") { out = out substr(line, i, 2); i += 2; continue }
          out = out d; i++
          if (d == c) break
        }
        continue
      }
      out = out c; i++
    }
    print out
  }
  END {
    if (blockDepth > 0 || openStr != "") {
      printf "%s\n", (blockDepth > 0 \
        ? "닫히지 않은 블록 주석으로 파일이 끝났습니다" \
        : "닫히지 않은 문자열로 파일이 끝났습니다") > "/dev/stderr"
      exit 1
    }
  }
'

# 주어진 자리들 아래의 `*.dart` 를 주석만 걷어 낸 사본으로 $1 아래에 만든다.
# 상대 경로는 원본 그대로 둔다 — 부르는 쪽이 원본 경로로 메시지를 낼 수 있다.
#
# awk 가 실패하거나 사본이 하나도 생기지 않으면 **조용히 통과하는 대신**
# stderr 에 적고 2 를 돌려준다. 그 침묵이 이 저장소가 round 6·7 에서 두 번
# 고친 모양이다.
dart_source_mirror() {
  local mirror=$1
  shift
  local rc=0 count=0 root f out
  for root in "$@"; do
    if [ ! -e "$root" ]; then
      echo "dart_source_mirror: $root 이 없습니다." >&2
      rc=2
      continue
    fi
    while IFS= read -r f; do
      out="$mirror/$f"
      if ! mkdir -p "$(dirname "$out")"; then
        echo "dart_source_mirror: $out 의 자리를 만들지 못했습니다." >&2
        rc=2
        continue
      fi
      if awk "$DART_SOURCE_AWK" "$f" > "$out"; then
        count=$((count + 1))
      else
        echo "dart_source_mirror: $f 에서 주석을 걷어 내지 못했습니다 — 검사가 조용히 통과하는 대신 여기서 멈춥니다." >&2
        rc=2
      fi
    done < <(find "$root" -type f -name '*.dart' | sort)
  done
  if [ "$count" -eq 0 ]; then
    echo "dart_source_mirror: 사본이 하나도 생기지 않았습니다 ($*) — 아래 검사들이 이 사본을 보고 있으므로 여기서 멈춥니다." >&2
    rc=2
  fi
  return $rc
}
