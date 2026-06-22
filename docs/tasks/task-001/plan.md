# task-001 plan   (spec: ./spec.md)

**아키텍처 한 줄**: 공식 `supabase/docker` 풀스택을 맥미니에 비충돌 포트(Kong 8300 / PG 127.0.0.1:5434)로 띄우고, 신규 `kbo` Cloudflare Tunnel로 `kbo-api.ardenspace.com → localhost:8300` 노출. 재부팅 자동기동 + pg_dump 백업.

**파일 구조 (신규):**
```
infra/supabase/
  docker-compose.yml      # 공식 베이스 + 포트 오버라이드
  .env                    # 시크릿 (gitignore)
  .env.example            # 키 이름만 (commit)
  volumes/                # PG 데이터 등 (gitignore)
infra/cloudflared/
  kbo-config.yml          # kbo 튠넬 ingress (kbo-api → localhost:8300)
scripts/backup/
  pg_dump.sh              # 백업 스크립트
README-infra.md           # 기동/접속/키 위치 문서
.gitignore                # .env, volumes 추가
```

## Step 분해

- [ ] **Step 1 — compose + 시크릿 구성**
  공식 supabase/docker 받아 `infra/supabase/`로. Kong 8000→8300, PG 노출 127.0.0.1:5434로 오버라이드. JWT_SECRET 생성 → ANON_KEY/SERVICE_ROLE_KEY 발급, POSTGRES_PASSWORD·DASHBOARD 시크릿 → `.env`. `.env.example`(키 이름만) + `.gitignore`(`.env`, `volumes/`).
  - 검증: `docker compose -f infra/supabase/docker-compose.yml config -q` (구문 유효) + `.env` git 추적 안 됨(`git check-ignore infra/supabase/.env`)
  - 롤백: 디렉토리 삭제

- [ ] **Step 2 — 기동 + 내부 헬스**
  `docker compose up -d`. 전 컨테이너 healthy 대기.
  - 검증: `docker compose ps`(모두 healthy) + `curl -s -H "apikey: $ANON_KEY" http://localhost:8300/rest/v1/` 유효 응답 + 8300/5434가 기존 점유와 비충돌 재확인
  - 롤백: `docker compose down`(볼륨 보존)

- [ ] **Step 3 — 로컬 접근 확인 (PG + Studio)**
  Postgres 127.0.0.1:5434 psql 연결, Studio 로컬 접속 확인(공개 라우팅 없음).
  - 검증: `psql postgresql://postgres:***@127.0.0.1:5434/postgres -c '\l'` 성공 + Studio 로컬 URL 200, 외부 노출 경로 없음 확인
  - 롤백: 해당 없음(읽기 확인)

- [ ] **Step 4 — kbo 튠넬 생성 + 외부 노출**
  `cloudflared tunnel create kbo` → creds json. `cloudflared tunnel route dns kbo kbo-api.ardenspace.com`. `infra/cloudflared/kbo-config.yml`(ingress: kbo-api → localhost:8300, 그 외 404). 튠넬 기동.
  - 검증: 외부망/폰에서 `curl -s -H "apikey: $ANON_KEY" https://kbo-api.ardenspace.com/rest/v1/` 유효 응답 + `/`(Studio) 비노출(404)
  - 롤백: `cloudflared tunnel delete kbo` + DNS 레코드 제거

- [ ] **Step 5 — 자동 기동 (재부팅 내성)**
  docker compose `restart: unless-stopped` 확인 + Docker Desktop 로그인 시작. cloudflared `kbo`를 launchd 서비스로 등록(기존 chak 패턴 따라).
  - 검증: `launchctl list | grep cloudflared`(또는 등록 확인) + `docker inspect` restart policy 확인. (가능하면 재부팅 1회 실검)
  - 롤백: launchd unload + restart policy no

- [ ] **Step 6 — 백업 스크립트 + cron**
  `scripts/backup/pg_dump.sh`(127.0.0.1:5434 → 타임스탬프 덤프, 보존 N개). crontab 1일 1회 등록.
  - 검증: 스크립트 1회 실행 → 덤프 파일 생성 확인 + `crontab -l`에 등록됨
  - 롤백: cron 제거 + 스크립트 삭제

- [ ] **Step 7 — 문서 + handoff**
  `README-infra.md`(기동/접속/키 위치/앱·크롤러가 anon vs service_role 어디서 읽는지). handoff `### 결정`/`### 다음` 갱신.
  - 검증: README대로 따라 재기동 가능(자기검증 통독)
  - 롤백: 문서 되돌림

## 끝 검증 (DoD = spec §2)
- 코드 리뷰: 시크릿 커밋 안 됨(`.env` gitignore), 포트 비충돌, Studio 비공개
- e2e: 폰에서 `https://kbo-api.ardenspace.com/rest/v1/` 응답 + 재부팅 후 자동 복구 + pg_dump 1회 성공

## 보안 메모
- `.env`·creds json·cert.pem·volumes 절대 commit 금지. service_role 키는 크롤러(.env)만, 앱은 anon 키만.
