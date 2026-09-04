#!/usr/bin/env bash
# Dart 소스에서 **주석을 걷어 내는 규칙** — 이 저장소의 훅들이 함께 쓰는 한
# 자리다 (step 4.1 fresh 검증 round 9 에서 생겼고, round 10 이 훑는 규칙을
# 다시 세웠다).
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
# round 10 이 이 파일에서 고친 것.
# ─────────────────────────────────────────────────────────────────────────
#
# round 9 가 세운 첫 판의 훑는 규칙은 문자열을 **한 줄 안에서 여는 따옴표와
# 같은 다음 따옴표까지**로 읽었다. 그래서 문자열 보간(`${…}`) 안에 **같은
# 따옴표의 문자열이 중첩되면** 여는 문자열이 그 안쪽 따옴표에서 닫힌 것으로
# 읽혔고, 그 뒤에 오는 `//` 를 줄 주석으로 보아 **그 줄의 나머지를 잘라
# 냈다.** 검증자 재현:
#
#     원본: final v = '${a ?? 'https://a.b'}/x';
#     첫 판의 사본: final v = '${a ?? 'https:
#
# 이것은 **이 저장소가 실제로 쓰는 모양**이다:
# `lib/features/home/home_screen.dart:228`·`:403` 과
# `test/features/home/next_away_game_test.dart:252` 가 같은 중첩 보간이다(그
# 파일들에 `//` 가 없어 그때 잘리지 않았을 뿐이다). 검증자가 그 잘림으로
# `check-no-location-upload.sh` 의 검사 5)·4)(b) 가 실제 위반을 놓치는 것을
# 확인했다.
#
# 그래서 훑는 규칙을 **상태 더미(stack)** 로 다시 세웠다. 문자열 안의 `${` 는
# 코드 자리를 다시 열고(그 안에서 문자열·주석·중괄호를 다시 센다), 짝이 맞는
# `}` 에서 문자열로 돌아온다. 깊이 제한은 없다.
#
# ─────────────────────────────────────────────────────────────────────────
# 무엇을 하고 무엇은 하지 않는가 — **아래 목록은 전부 실측이다.**
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
# 한다 — 그러지 않으면 `'https://…'` 의 `//` 나 `'/*'` 를 주석
# 표지로 잘못 읽는다.
#
# **바르게 다루는 것** (하나씩 넣어 사본을 눈으로 확인했고, BSD awk 와 mawk 가
# 같은 답을 냈다):
#
#   · 홑따옴표·겹따옴표 문자열, 그 각각의 세 겹(`'''`·`"""`, 줄을
#     넘긴다), raw 접두어(`r'…'`, 역슬래시가 이스케이프가 아니다).
#   · 문자열 안의 `//`·`/*`·`*/`·`print(` — 그대로 남는다.
#   · 이스케이프: `'it\'s'` · `"he said \"x\""` · `'a\\'`
#     (역슬래시로 끝나는 문자열).
#   · **중첩 보간**: `'${a ?? 'https://a.b'}/x'` ·
#     `'a${'b${'c'}d'}e'` (깊이 제한 없음).
#   · 보간 안의 코드: 중괄호(`'${ {'k': 1}.length }'`),
#     닫는 중괄호를 담은 문자열(`'${f('}')}'`), 블록 주석
#     (`'${ /* } */ a}'`), raw 문자열(`'${r'x'}'`).
#   · 이스케이프한 보간 표지: `'\${notInterp}//still string'` 는
#     통째로 문자열이다.
#   · raw 문자열 안의 `${…}` 는 보간이 아니다 (Dart 가 그렇다).
#   · 주석 안의 문자열 표지: `// 주석 안의 '따옴표` · `/* ' 와 " */`.
#   · 블록 주석의 중첩(`/* /* x */ */`)과 코드 사이 접힘(`final/*c*/int x` →
#     `final int x`).
#   · 나란한 문자열(`'a' 'b'`), 빈 문자열(`''`),
#     세 겹 안의 홑따옴표(`'''a'b'''`).
#   · 나눗셈과 주석이 붙은 자리(`x = a / /* c */ b;`).
#
# **다루지 못하는 것 — 그리고 그것이 어떻게 드러나는가.** 조용히 자르는 갈래는
# 없다. 셋 다 stderr 에 줄 번호와 함께 적고 exit 1 이며, `dart_source_mirror`
# 가 그것을 받아 exit 2 로 세운다(검사가 그 사본을 보고 통과하는 일이 없다).
#
#   1. **닫히지 않은 블록 주석으로 파일이 끝났다** → "닫히지 않은 블록 주석으로
#      파일이 끝났습니다".
#   2. **닫히지 않은 문자열로 파일이 끝났다** → "닫히지 않은 문자열로 파일이
#      끝났습니다". 한 줄짜리 문자열이 그 줄에서 닫히지 않으면 뒤의 줄들을
#      계속 문자열로 읽다가 여기서 걸린다(첫 판은 그 줄 끝에서 조용히
#      털어 버렸다).
#   3. **한 줄짜리 문자열의 보간 안에 줄 주석이 있다**
#      (`final v = '${a // c}';`) → "한 줄짜리 문자열의 보간 안에서
#      줄 주석을 만났습니다". 그 줄 주석은 닫는 따옴표까지 함께 먹어 버리므로
#      Dart 로도 성립하지 않는 입력이고, 사본에서도 그 줄의 나머지가 사라진다.
#      **세 겹 문자열의 보간 안에 있는 줄 주석은 성립하는 Dart 이고 여기서
#      걸리지 않는다** — 그 경우에는 줄의 나머지만 버리고 다음 줄에서 같은
#      보간을 이어 읽는다(실측).
#
#   위 셋 다 `flutter analyze` 가 함께 빨간불이거나(1·2·3) 애초에 성립하지 않는
#   입력이다. 그리고 셋 다 **파일 이름과 함께** 적힌다.
#
#   그밖에 이 규칙이 **알아보지 못하는 Dart 문법은 실측으로 찾지 못했다.** 다만
#   이것은 Dart 파서가 아니라 문자 훑기라서, 위 목록 밖의 성립하지 않는 입력이
#   들어오면 사본이 어긋날 수 있다. 그때 어긋남은 위 셋 중 하나로 나오거나
#   (따옴표·중괄호의 짝이 깨지면 파일 끝까지 먹는다), 사본이 원본보다 **덜**
#   지워진 모양으로 나온다 — 검사가 못 보는 쪽이 아니라 더 보는 쪽이다.
#
# 알아보는 문자열은 넷이다: 홑따옴표·겹따옴표, 그 각각의 세 겹
# (`'''`·`"""`, 줄을 넘긴다), 그리고 raw 접두어(`r'…'`).
#
# **문자열을 알아보는 규칙이 이 저장소에 두 자리 있는 것은 목적이 다르기
# 때문이다.** 여기서는 "주석 표지가 문자열 안에 있는가"를 가리려고 보고,
# `check-no-location-upload.sh` 의 검사 4) 는 "문장을 끊는 `;`·`{` 가 문자열
# 안에 있는가"를 가리려고 본다. 둘을 하나로 합치려면 문자열 내용을 지워야
# 하는데, 그러면 검사 2) 가 URI 를 읽지 못한다. (같은 유형의 구분: 같은
# 스크립트의 `DECL_MODIFIERS` 와 필드 수식어 집합도 이름이 겹치지만 다른
# 개념이라고 그 자리에 적혀 있다.)
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
  # 상태 더미. kind[k] 는 "B"(블록 주석) · "S"(문자열) · "I"(보간 안의 코드).
  # 더미가 비면 파일 최상위의 코드 자리다.
  BEGIN { top = 0; abort = 0 }

  function push(k) { top++; kind[top] = k; quote[top] = ""; raw[top] = 0; brace[top] = 0 }

  # 가장 안쪽 문자열이 세 겹인가 — 줄 주석을 만났을 때 이 줄만 버려도 되는지를
  # 가른다 (세 겹은 다음 줄에서 같은 보간을 이어 읽을 수 있다).
  function innerStringIsTriple(   k) {
    for (k = top; k >= 1; k--) if (kind[k] == "S") return (length(quote[k]) == 3)
    return 0
  }

  function bail(msg) {
    printf "%s:%d: %s\n", FILENAME, FNR, msg > "/dev/stderr"
    abort = 1
    exit 1
  }

  {
    line = $0
    len = length(line)
    out = ""
    i = 1
    while (i <= len) {
      state = (top > 0) ? kind[top] : "C"

      if (state == "B") {                         # 블록 주석 안 (중첩을 센다)
        two = substr(line, i, 2)
        if (two == "*/") { top--; i += 2; continue }
        if (two == "/*") { push("B"); i += 2; continue }
        i++
        continue
      }

      if (state == "S") {                         # 문자열 안 — 내용은 그대로 둔다
        c = substr(line, i, 1)
        if (!raw[top] && c == "\\") { out = out substr(line, i, 2); i += 2; continue }
        q = quote[top]
        if (substr(line, i, length(q)) == q) {
          out = out q; i += length(q); top--
          continue
        }
        if (!raw[top] && c == "$" && substr(line, i + 1, 1) == "{") {
          out = out "${"; i += 2; push("I"); brace[top] = 1
          continue
        }
        out = out c; i++
        continue
      }

      # 여기부터는 코드 자리다 — 파일 최상위("C") 이거나 보간 안("I").
      two = substr(line, i, 2)
      if (two == "//") {                          # 줄 주석 — 나머지를 버린다
        if (top > 0 && !innerStringIsTriple()) {
          bail("한 줄짜리 문자열의 보간 안에서 줄 주석을 만났습니다 — 닫는 따옴표까지 함께 사라집니다")
        }
        break
      }
      # 블록 주석은 **공백 하나로** 접는다 — 토막 사이에 있던 주석이 두 토막을
      # 붙여 버리지 않도록 (`final/*c*/int x` 가 `finalint x` 가 되면 부르는
      # 쪽이 선언을 읽지 못한다).
      if (two == "/*") { push("B"); i += 2; out = out " "; continue }

      c = substr(line, i, 1)
      if (state == "I") {                         # 보간의 짝을 센다
        if (c == "{") { brace[top]++; out = out c; i++; continue }
        if (c == "}") {
          if (brace[top] <= 1) { top--; out = out c; i++; continue }
          brace[top]--; out = out c; i++
          continue
        }
      }

      isRaw = 0
      if (c == "r" && (substr(line, i + 1, 1) == "\047" || substr(line, i + 1, 1) == "\"") \
          && (i == 1 || substr(line, i - 1, 1) !~ /[A-Za-z0-9_$]/)) {
        out = out c; i++
        c = substr(line, i, 1)
        isRaw = 1
      }
      if (c == "\047" || c == "\"") {
        q3 = c c c
        if (substr(line, i, 3) == q3) {           # 세 겹 — 줄을 넘길 수 있다
          push("S"); quote[top] = q3; raw[top] = isRaw
          out = out q3; i += 3
          continue
        }
        push("S"); quote[top] = c; raw[top] = isRaw
        out = out c; i++
        continue
      }
      out = out c; i++
    }
    print out
  }

  END {
    if (abort) exit 1
    if (top > 0) {
      for (k = top; k >= 1; k--) {
        if (kind[k] == "B") { why = "닫히지 않은 블록 주석으로 파일이 끝났습니다"; break }
        if (kind[k] == "S") { why = "닫히지 않은 문자열로 파일이 끝났습니다"; break }
      }
      if (why == "") why = "닫히지 않은 문자열 보간으로 파일이 끝났습니다"
      printf "%s: %s\n", FILENAME, why > "/dev/stderr"
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
