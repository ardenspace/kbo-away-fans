#!/usr/bin/env bash
# lib/backend/ 안에서 위도·경도로 읽히는 필드명이 나타나면 실패한다 —
# 이 프로젝트 전용 신설 스크립트 (step 1.9, spec.md Enforcement plan).
#
# "기기가 어디에 있었는지는 서버에 올리지 않는다"는 개인정보 약속
# (decisions.md 의 데이터 소유권 XL 결정, lib/backend/CLAUDE.md 의 "기기가
# 어디에 있었는지는 올리지 않는다" 절)을 사람의 주의력이 아니라 검사로 지킨다.
#
# 잡는 단어: lat, lng, latitude, longitude, coord — lib/backend/CLAUDE.md 가
# 명시한 필드명 목록과 같다. \b 단어 경계로 잡아서 "calculate"·"translate"
# 같은 부분 문자열을 오탐하지 않는다(Dart 식별자 문자는 [A-Za-z0-9_] 뿐이라
# \b 는 그 앞뒤가 식별자 문자가 아닐 때만 걸린다).
#
# 검색 범위는 lib/backend/ 전체다 — 정당한 좌표 사용(지도·구장 거리 계산)은
# 전부 이 폴더 밖(lib/ui/shared/stadium_map_view.dart 등)에서 일어나므로
# "업로드 경로"만 따로 좁히지 않아도 깨끗한 트리는 매치가 없다.
# 위반은 stderr 에 찍고 exit 2 (Claude Code PostToolUse 훅이 읽는 신호).
set -u
cd "$(dirname "$0")/../.." || exit 1

DIR="lib/backend"
pattern='\b(lat|lng|latitude|longitude|coord)\b'

[ -d "$DIR" ] || exit 0

hits=$(grep -rniE --include='*.dart' "$pattern" "$DIR" 2>/dev/null)

if [ -n "$hits" ]; then
  {
    echo "위치 필드로 읽히는 이름이 $DIR 에 있습니다 (기기의 지점은 서버로 올리지 않는다):"
    echo "$hits"
  } >&2
  exit 2
fi
exit 0
