# Handoff: feat/task-003-seed-tool — @arden

## 2026-06-23

- [x] task-003 시딩 도구: seed 스크립트 + 포맷 + 1구장 샘플 (E8)

### 마지막 커밋
- feat(task-003): seed 스크립트 + JSON 포맷 + 잠실 샘플

### 진행
- ✅ scripts/seed/data/teams.json — 10구단 (abbr·color)
- ✅ scripts/seed/data/stadiums.json — 9구장 (잠실 두산 primary)
- ✅ scripts/seed/data/restaurants.json — 잠실 샘플 2건
- ✅ scripts/seed/data/planb_places.json — 잠실 샘플 1건
- ✅ scripts/seed.py — docker exec psql upsert, 재실행 멱등 확인
- ✅ DoD: 10구단/9구장 SELECT 확인

### 결정
- **UNIQUE 제약 = seed.py setup 단계에서 추가**: migration 003이 아닌 seed.py에서 pg_constraint 존재 체크 후 추가. → DECISIONS 승격 대상
- **잠실야구장 team_id = 두산(OB)**: 두산·LG 공동홈이지만 단일 FK → 두산을 primary로 등록. 앱은 games 경유로 stadium을 찾으므로 team_id 실사용 없음.

### 블로커
- 없음
