# 인프라 — Supabase 셀프호스팅 (task-001)

맥미니에서 Supabase 풀스택을 Docker로 돌리고 Cloudflare Tunnel로 노출한다. (결정: [docs/EXECUTION-PLAN.md](docs/EXECUTION-PLAN.md) E1, [docs/tasks/task-001/spec.md](docs/tasks/task-001/spec.md))

## 구성

```
[폰/외부] ─https─▶ Cloudflare ─tunnel(kbo)─▶ cloudflared ─▶ Kong(127.0.0.1:8300)
                                                               ├ /rest/v1     → PostgREST
                                                               ├ /auth/v1     → GoTrue
                                                               ├ /storage/v1  → Storage
                                                               └ /realtime/v1 → Realtime
                                            Postgres 127.0.0.1:5434 (크롤러/마이그레이션 직결)
                                            Studio  127.0.0.1:8300/ (basic-auth, 외부 미노출)
```

- 공개 엔드포인트: **`https://kbo-api.ardenspace.com`** (API 경로만, Studio 등 그 외 경로는 404)
- 로컬 전용: Postgres `127.0.0.1:5434`, Studio `http://localhost:8300/` (계정 `arden`)

## 포트 (맥미니 점유 회피)

| 포트 | 용도 | 바인딩 |
|---|---|---|
| 8300 | Kong API gateway | 127.0.0.1 |
| 5434 | Postgres 직결 | 127.0.0.1 |

기존 점유(8000 app-chak, 8080 llama, 8081 pslog, 8200 auto-shorts, 5433 pslog-pg)와 비충돌.

## 키 (E10 격리)

`infra/supabase/.env` (gitignore — **절대 커밋 금지**). `.env.example`는 키 이름만.
- **앱(Flutter)** → `ANON_KEY` + `SUPABASE_PUBLIC_URL`
- **크롤러** → `SERVICE_ROLE_KEY` (또는 Postgres 직결 `127.0.0.1:5434`)
- service_role 키는 앱에 절대 넣지 않는다.

## 운영

```bash
# 기동 / 중지 / 상태
cd infra/supabase && docker compose up -d
docker compose ps
docker compose down            # 볼륨 보존

# 튠넬 (LaunchAgent: com.kbo.cloudflared — 로그인 시 자동기동)
launchctl list | grep kbo.cloudflared
tail -f ~/Library/Logs/kbo-cloudflared.log

# 백업 (LaunchAgent: com.kbo.backup — 매일 04:00, cron 아닌 launchd 타이머)
launchctl kickstart gui/$(id -u)/com.kbo.backup    # 수동 즉시 백업
ls -lt backups/                                     # 덤프 (gitignore, 최신 14개 보존)
```

### 백업 복구
```bash
gzcat backups/kbo-pg-<ts>.sql.gz | docker exec -i kbo-supabase-db psql -U postgres -d postgres
```

### 자동기동 (재부팅 내성)
- Docker Desktop: 로그인 시 자동 시작(기존 설정) + compose 11개 `restart: unless-stopped`
- cloudflared `kbo`: `~/Library/LaunchAgents/com.kbo.cloudflared.plist` (RunAtLoad + KeepAlive)
- 백업: `~/Library/LaunchAgents/com.kbo.backup.plist`
- plist 원본은 `infra/cloudflared/`, `infra/backup/`에 보관 (재설치는 각 plist 헤더 주석 참고)

## 호스티드 전환
호스티드 Supabase로 옮기려면 앱/크롤러의 URL·키 env만 교체하면 됨(코드 동일, E1 비종속).
