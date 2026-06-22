# Handoff: feat/task-001-supabase-selfhost — @arden

## 2026-06-22

- [ ] task-001 (deep) 맥미니 Supabase 셀프호스팅(Docker) + 도메인/리버스프록시/TLS (E1)

### 마지막 커밋
- (아직 — 끝 검증 후 커밋 예정)

### 다음
- 끝 검증(코드리뷰+e2e) 통과 확인 → 커밋·푸시 → PLAN task-001 체크

### 진행
- ✅ Step 1: 공식 supabase/docker 베이스 → `infra/supabase/`, 시크릿·JWT 생성(.env, gitignore), 포트 오버라이드. 호스트 노출 `127.0.0.1:5434`(db)·`127.0.0.1:8300`(kong)만.
- ✅ Step 2: `docker compose up -d` — 11개 컨테이너 전부 healthy. REST `/rest/v1/` HTTP 200(anon key). auth/는 Kong이 apikey 요구(정상).
- ✅ Step 3: Postgres 17.6 로컬 직결 OK, 5434·8300 둘 다 127.0.0.1 바인딩 확인. Studio는 Kong basic-auth(arden) 뒤 — 로컬만.
- ✅ Step 4: kbo 튠넬 생성(id 91b64af0…) + DNS `kbo-api.ardenspace.com`. 공인 `/rest/v1/`→401(키없음, Kong 도달=성공), `/`→404(Studio 차단). 폰 LTE 테스트 사용자 확인됨.
- ✅ Step 5: cloudflared LaunchAgent(`com.kbo.cloudflared`) — RunAtLoad+KeepAlive(죽이면 재기동 확인). Docker는 로그인 자동시작 기존 설정+restart:unless-stopped.
- ✅ Step 6: pg_dump 백업 스크립트 + **launchd 타이머**(매일 04:00). kickstart 1회 성공, gzip 무결.
- ✅ Step 7: `README-infra.md` 작성.

### 블로커
- 없음. (남은 건 끝 검증 + 커밋)

### 결정 (→ DECISIONS 2026-06-22 승격됨)
- **override 머지 함정**: docker compose는 `ports`를 교체가 아니라 *concatenate* → override.yml 방식은 0.0.0.0 매핑(5432/8443)이 안 지워지고 중복 생김. → override 폐기, **vendored compose 직접 편집**으로 전환.
- **db 직결 노출**(127.0.0.1:5434): supavisor 풀러 대신 db 직결을 크롤러/마이그레이션 경로로(spec D6). supavisor 호스트 노출 제거.
- **Studio 비공개 방식**(spec D5 구체화): kong을 127.0.0.1:8300에 바인딩 + Step 4에서 cloudflared ingress를 API 경로(/rest /auth /storage /realtime /functions)만 allowlist → Studio(`/`)는 외부 미노출, 로컬 localhost:8300로만 접근.
- **DNS 오라우팅 정정**: `cloudflared tunnel route dns kbo …`가 config.yml 기본 튠넬(chak)로 잘못 걸림 → kbo UUID 명시 + `--overwrite-dns`로 정정.
- **cron → launchd 타이머**(plan에서 변경): macOS는 비대화형 `crontab` 수정에 Full Disk Access 필요해 등록 실패 → 백업을 `com.kbo.backup` LaunchAgent(StartCalendarInterval 04:00)로 대체. cloudflared LaunchAgent와 일관.
