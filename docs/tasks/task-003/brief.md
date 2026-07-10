# task-003 brief — 시딩 도구: seed 스크립트 + 포맷 + 1구장 샘플

- **왜**: 10구장 콘텐츠(맛집·플랜B·가이드) 수작업 시딩(E8) 기반. task-004에서 실제 데이터 파일만 채우면 바로 DB 반영 가능해야 함.
- **무엇**:
  - `scripts/seed/data/` — JSON 포맷 데이터 파일 4종 (teams / stadiums / restaurants / planb_places)
  - `scripts/seed.py` — JSON 읽어 `kbo-supabase-db` 컨테이너 psql로 upsert (멱등)
  - 잠실야구장 샘플 데이터 1구장 (teams 2건·stadium 1건·restaurant 2건·planb 1건)
- **out**: 실제 10구장 데이터(task-004), 크롤러·앱 코드와 무관

## 완료조건 (DoD)

- ☐ `scripts/seed/data/teams.json` — KBO 10구단 전체 (abbr·color 포함)
- ☐ `scripts/seed/data/stadiums.json` — 10구장 전체 (좌표 필수, 가이드 컬럼은 빈 문자열 허용)
- ☐ `scripts/seed/data/restaurants.json` — 잠실 샘플 2건 이상 (pick_type·source_url 필수)
- ☐ `scripts/seed/data/planb_places.json` — 잠실 샘플 1건 이상
- ☐ `scripts/seed.py` 실행 → DB에 데이터 반영, 재실행 시 오류 없음 (upsert 멱등)
- ☐ `docker exec kbo-supabase-db psql -U postgres -d postgres -c "SELECT name FROM public.teams"` → 10구단 출력

## 영향파일

`scripts/seed.py`, `scripts/seed/data/*.json`

## 검증

```bash
python3 scripts/seed.py
docker exec kbo-supabase-db psql -U postgres -d postgres \
  -c "SELECT name FROM public.teams ORDER BY name;" \
  -c "SELECT name, city FROM public.stadiums ORDER BY name;"
```
