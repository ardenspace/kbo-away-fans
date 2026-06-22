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
