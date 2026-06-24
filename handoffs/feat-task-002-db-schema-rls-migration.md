# Handoff: feat/task-002-db-schema-rls-migration — @arden

## 2026-06-23

- [x] task-002 (deep) DB 스키마 + RLS + migration (teams/stadiums/games/restaurants/planb_places/profiles/stamps)

### 마지막 커밋
- feat(task-002): DB 스키마 + RLS + migration (7테이블)

### 진행
- ✅ Step 1~6: SQL migration 7파일 작성 (`supabase/migrations/001~007_*.sql`)
- ✅ Step 7: `scripts/migrate.sh` (docker exec 경유) + 맥미니 실행 성공, 재실행 멱등 확인
- ✅ Step 8: DoD 검증 — 7테이블 생성, RLS t, 정책 10개, service_role upsert 성공, anon INSERT 거부, auth trigger 존재

### 결정
- **migrate.sh = docker exec 방식**: 맥미니에 psql 네이티브 미설치 → `supabase-db` 컨테이너 psql 경유. → DECISIONS 승격 대상
- **DATABASE_URL 불필요**: docker exec 이므로 env 없이 컨테이너명만으로 충분. `.env.example`은 참고용으로 유지.

### 블로커
- 없음
