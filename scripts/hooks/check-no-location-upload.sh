#!/usr/bin/env bash
# "기기가 어디에 있었는지는 서버로 올리지 않는다"는 개인정보 약속
# (decisions.md 의 데이터 소유권 XL 결정, lib/backend/CLAUDE.md 와
# lib/location/CLAUDE.md 의 같은 절)을 사람의 주의력이 아니라 검사로 지킨다 —
# 이 프로젝트 전용 신설 스크립트 (step 1.9, spec.md Enforcement plan).
#
# 검사는 둘이고 방향이 다르다:
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
# 패키지 경로('package:kbo_away_fans/backend/...') 를 한 패턴으로 잡는다.
LOC_DIR="lib/location"

if [ -d "$LOC_DIR" ]; then
  loc_hits=$(grep -rnE --include='*.dart' \
    "^[[:space:]]*(import|export)[[:space:]]+'[^']*backend/" "$LOC_DIR" 2>/dev/null)
  if [ -n "$loc_hits" ]; then
    {
      echo "$LOC_DIR 이 업로드 계층(lib/backend/)을 import 합니다 (좌표가 서버로 나갈 길을 만들지 않는다):"
      echo "$loc_hits"
    } >&2
    fail=2
  fi
fi

exit $fail
