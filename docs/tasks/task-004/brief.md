# task-004 brief — 10구장 콘텐츠 큐레이션·시딩

- **왜**: task-003에서 잠실만 채움. 나머지 8구장 + 전체 가이드 채워야 앱이 실질적으로 동작 (E8).
- **무엇**:
  - `restaurants.json` — 8개 구장 각 2건 이상 추가 (pick_type·source_url 필수)
  - `planb_places.json` — 8개 구장 각 1건 이상 추가
  - `stadiums.json` — 전체 9구장 가이드 컬럼 채움 (parking_info / seating_info / route_info / convenience_info)
- **out**: 앱 코드, 스크립트 수정 없음. JSON 파일만.

## 완료조건 (DoD)

- ☐ restaurants: 9구장 × 최소 2건 (총 18건+), pick_type·source_url 전부 있음
- ☐ planb_places: 9구장 × 최소 1건 (총 9건+)
- ☐ stadiums: 9구장 전부 가이드 4컬럼 비어있지 않음
- ☐ `python3 scripts/seed.py` 성공
- ☐ `SELECT COUNT(*) FROM public.restaurants` → 18 이상

## 영향파일

`scripts/seed/data/restaurants.json`, `scripts/seed/data/planb_places.json`, `scripts/seed/data/stadiums.json`

## 검증

```bash
python3 scripts/seed.py
docker exec supabase-db psql -U postgres -d postgres \
  -c "SELECT s.name, COUNT(r.id) FROM public.stadiums s LEFT JOIN public.restaurants r ON r.stadium_id=s.id GROUP BY s.name ORDER BY s.name;"
```
