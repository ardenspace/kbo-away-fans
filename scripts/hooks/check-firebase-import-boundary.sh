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
# **세 검사 다 주석은 보지 않는다** (round 9 에서 고쳤다). 그 전에는 소스
# **텍스트**만 보아서, 이 저장소의 관례대로 계층 경계를 doc 주석에 적기만 해도
# exit 2 였다 — 실측: `lib/features/badges/stadium_visit.dart` 의 doc 주석에
# `/// 경계: 좌표 플러그인(package:geolocator)은 판정 계층 한 파일에만 있다.`
# 한 줄을 넣으면 `flutter analyze` 는 무지적인데 이 훅이 exit 2 였고, 오류
# 메시지는 "import 가 밖에 있습니다"라고 말해 고칠 길을 잘못 가리켰다(걸린
# 것은 import 가 아니라 주석이었다). 이 훅은 CI 에도 걸려 있으므로 그 오탐이
# 로컬 커밋뿐 아니라 CI 도 막았다. 4.1 자신이 `stadium_visit.dart` 와
# `lib/location/location.dart` 에 그런 문단을 쓰는데, 그 둘이 그때도 통과한
# 것은 `package:` 접두어를 우연히 빼고 적었기 때문이다.
#
# 주석을 걷어 내는 규칙은 `scripts/hooks/dart-source.sh` **한 자리**에 있다 —
# 짝 훅(`check-no-location-upload.sh`)도 같은 자리를 쓴다. 같은 개념을 두 자리에
# 따로 적으면 어긋남이 다시 생긴다.
#
# 위반은 stderr 에 찍고 exit 2 (Claude Code PostToolUse 훅이 읽는 신호).
set -u
hook_dir=$(cd "$(dirname "$0")" && pwd) || exit 1
cd "$hook_dir/../.." || exit 1
. "$hook_dir/dart-source.sh" || exit 1

fail=0

# 주석만 걷어 낸 사본을 만들어 그 위에서 grep 한다. 사본을 만들지 못하면
# **조용히 통과하는 대신** 여기서 fail 이 선다 (dart_source_mirror 가 까닭을
# stderr 에 적는다).
MIRROR=$(mktemp -d) || exit 1
trap 'rm -rf "$MIRROR"' EXIT
dart_source_mirror "$MIRROR" lib || fail=2

# 사본 위의 grep. 경로가 원본과 같은 모양으로 나오도록 사본 안에서 돈다.
#
# grep 의 종료 상태 2 이상(사본을 읽지 못함 등)은 **드러낸다** — 그것을 버리면
# 검사가 조용히 통과한다(이 저장소가 round 6·7 에서 두 번 고친 모양이다).
# 종료 상태를 함수 밖으로 들고 나오지 않고 표지 줄로 내는 것은, 부르는 쪽이
# 명령 치환(`$( )`)이라 함수 안의 대입이 밖으로 나오지 못하기 때문이다.
mirror_grep() {
  local pattern=$1 out status
  out=$( (cd "$MIRROR" || exit 9; grep -rnE --include='*.dart' "$pattern" lib) 2>/dev/null )
  status=$?
  if [ "$status" -gt 1 ]; then
    printf 'GREPFAIL\t%s\n' "$pattern"
    return 0
  fi
  printf '%s' "$out"
}

# 표지 줄이 섞였으면 그 자리에서 멈춘다.
guard_grepfail() {
  local raw=$1 failed
  failed=$(printf '%s\n' "$raw" | sed -n 's/^GREPFAIL\t//p')
  if [ -n "$failed" ]; then
    {
      echo "주석을 걷어 낸 사본에서 grep 이 실패했습니다 — 검사가 조용히 통과하는 대신 여기서 멈춥니다. 패턴:"
      echo "$failed"
    } >&2
    return 1
  fi
  return 0
}

backend_raw=$(mirror_grep 'package:(firebase_|cloud_firestore|cloud_functions|google_sign_in|kakao)')
guard_grepfail "$backend_raw" || fail=2
hits=$(printf '%s' "$backend_raw" | grep -v '^GREPFAIL	' | grep -vE '^lib/(backend|analytics)/')

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
location_raw=$(mirror_grep 'package:permission_handler')
guard_grepfail "$location_raw" || fail=2
location_hits=$(printf '%s' "$location_raw" | grep -v '^GREPFAIL	' | grep -vE '^lib/location/location\.dart:')

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
fix_raw=$(mirror_grep 'package:geolocator')
guard_grepfail "$fix_raw" || fail=2
fix_hits=$(printf '%s' "$fix_raw" | grep -v '^GREPFAIL	' | grep -vE '^lib/location/visit_check\.dart:')

if [ -n "$fix_hits" ]; then
  {
    echo "좌표 플러그인 import(geolocator) 가 lib/location/visit_check.dart 밖에 있습니다:"
    echo "$fix_hits"
  } >&2
  fail=2
fi

exit $fail
