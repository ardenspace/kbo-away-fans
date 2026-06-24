# DECISIONS

프로젝트의 굳은 결정 로그. task 의 spec/handoff 에서 land 시 승격된다. (pslog decision-truth-loop)

---

## 2026-06-22 · task-001 — 백엔드 인프라

> 출처: [docs/EXECUTION-PLAN.md](docs/EXECUTION-PLAN.md) E1, [docs/tasks/task-001/spec.md](docs/tasks/task-001/spec.md)

- **E1 — 백엔드 = Supabase 셀프호스팅(맥미니 Docker)**. 호스티드 무료티어의 7일 잠자기·한도·비용을 피하려 맥미니 자원 사용. 앱 코드는 호스티드와 동일(Supabase SDK) — URL·키 env 교체만으로 전환 가능(비종속).
- **노출 = Cloudflare Tunnel**(`kbo` 튠넬, `kbo-api.ardenspace.com`). 포트포워딩·DDNS 불필요, 인바운드 0, TLS는 Cloudflare edge 종단. cloudflared·zone 기보유.
- **튠넬 분리** — 기존 `chak`와 별개 `kbo` 튠넬(장애 격리).
- **Studio 비공개** — cloudflared ingress 를 API 경로(`/rest /auth /storage /realtime /functions`)만 allowlist. Studio(`/`)는 외부 404, 로컬 `localhost:8300`(Kong basic-auth)만.
- **크롤러 DB 접근 = Postgres 직결**(`127.0.0.1:5434`), 앱은 Kong/PostgREST 경유.
- **포트** — Kong `127.0.0.1:8300`, Postgres `127.0.0.1:5434` (맥미니 기존 점유 8000/8080/8081/8200/5433 회피).
- **키 격리(E10)** — 앱=`ANON_KEY`, 크롤러=`SERVICE_ROLE_KEY`. service_role 키는 앱에 미포함. 시크릿은 `infra/supabase/.env`(gitignore).
- **자동기동/백업 = launchd** — cloudflared·pg_dump 백업 모두 LaunchAgent. (cron 은 macOS Full Disk Access 제약으로 비대화형 등록 실패 → launchd 타이머 채택.)

---

## 2026-06-23 · task-002 — DB 스키마 + RLS

> 출처: [docs/tasks/task-002/spec.md](docs/tasks/task-002/spec.md), [handoffs/feat-task-002-db-schema-rls-migration.md](handoffs/feat-task-002-db-schema-rls-migration.md)

- **스키마 7테이블**: `teams` / `stadiums` / `games` / `restaurants` / `planb_places` / `profiles` / `stamps`. 모두 `public` 스키마.
- **RLS 전략**: 콘텐츠 테이블(teams·stadiums·games·restaurants·planb_places) = public SELECT, 쓰기 정책 없음(앱 anon 쓰기 불가). `profiles`·`stamps` = `auth.uid()` owner-scoped. service_role은 RLS 자동 우회 → 크롤러·시드 스크립트 별도 정책 불필요.
- **pick_type = text + CHECK**: `'player'|'fan'|'editor'`. enum 대신 text CHECK 채택 — v1.5(LLM선수픽·팬제보픽) 값 추가 시 ALTER TYPE 불필요.
- **구장 가이드 = stadiums 컬럼**: `parking_info`, `seating_info`, `route_info`, `convenience_info` 4컬럼 직접 추가. 별도 테이블 JOIN 없이 단순화.
- **game_id = text UNIQUE**: 크롤러 upsert·dedup 키. 실제 형식은 task-005(크롤러)에서 확정.
- **auth trigger**: `handle_new_user()` — 가입 시 `profiles` 자동 생성. task-009(카카오 OAuth) 때 자동 동작.
- **migrate.sh = docker exec 방식**: 맥미니에 psql 네이티브 미설치 → `supabase-db` 컨테이너 psql 경유. `SUPABASE_DB_CONTAINER` env로 컨테이너명 변경 가능.
