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
- **migrate.sh = docker exec 방식**: 맥미니에 psql 네이티브 미설치 → `kbo-supabase-db` 컨테이너 psql 경유. `SUPABASE_DB_CONTAINER` env로 컨테이너명 변경 가능.

---

## 2026-06-25 · task-005 — 일정 크롤러 코어

> 출처: [docs/tasks/task-005/spec.md](docs/tasks/task-005/spec.md), [handoffs/feat-task-005-crawler-core.md](handoffs/feat-task-005-crawler-core.md)

- **일정 소스 = KBO 공식 `GetScheduleList`** (`POST /ws/Schedule.asmx/GetScheduleList`, `leId=1&srIdList=0,9,6&seasonId&gameMonth`). 스파이크 결과 viewstate 스크래핑이 아니라 **월 단위 JSON**(rows[].row[] 셀배열) 반환 → 파싱 안정. 네이버는 폴백 후보였으나 미사용. (E4 D1 확정)
- **`game_id` = `YYYYMMDD + away_abbr + home_abbr + dh`** (예 `20260602HHOB0`). 소스 game_id 안 믿고 **자체 합성** → 소스 비종속(폴백 시도 동일 키), 더블헤더는 dh 0/1 로 분리해 자연 dedup. `teams.abbr`(OB/LG/SK/HT… 레거시 코드) 사용.
- **구장 매핑 = 소스 구장 컬럼 별칭표** (홈팀 역참조 아님). 이유: 잠실 공용인데 stadiums 시드가 잠실=두산 1행뿐(LG 미시드) → 역참조 깨짐 + 소스가 구장 직접 제공. 짧은명(잠실)→공식명(잠실야구장). 미등록 구장(2군장·울산·청주 등)은 skip+로그(V1 YAGNI).
- **팀 매핑 = `teams.short_name` 직접** (play 셀이 한글 short_name "한화/두산/키움" 사용). abbr 별칭(키움 WO≠KW)은 game_id 합성에만 국한.
- **상태 정규화**: 끝셀 라벨 "취소"→`cancelled`, "연기"/"서스"→`postponed`, 그 외는 점수 유무로 `finished`/`scheduled`. KST→UTC 단일 지점 변환.
- **DB 접근 = Postgres 직결(psycopg2, 127.0.0.1:5434)** — task-001 E1 "크롤러=Postgres 직결" 준수. postgres 슈퍼유저로 RLS 우회. 기존 `DATABASE_URL` 사용. (운영 cron/2단주기/텔레그램 알림/graceful 은 task-006.)

---

## 2026-07-01 · task-009 — 로그인 (이메일 + 카카오 OAuth)

> 출처: [docs/tasks/task-009/spec.md](docs/tasks/task-009/spec.md), [handoffs/feat-task-009-login.md](handoffs/feat-task-009-login.md)

- **provider = 이메일 + 카카오**(E2). 카카오는 GoTrue 웹 OAuth(`signInWithOAuth` + 커스텀 스킴 콜백 `kboaway://login-callback`) — 네이티브 KakaoTalk SDK 아님. 앱 코드 간단, infra는 `GOTRUE_EXTERNAL_KAKAO_*` env만.
- **이메일 확인 = autoconfirm**(`ENABLE_EMAIL_AUTOCONFIRM`) — SMTP 없는 v1 dogfood, 가입 즉시 세션.
- **auth 게이트 = go_router redirect + refreshListenable** — 별도 스트림 구독(router provider 재빌드 안 함), `client.auth.currentSession` 동기 판정.
- **시크릿 격리 = compose만 커밋, 실제 키/적용은 ops 문서로 맥미니에서** — `infra/supabase/.env`는 gitignore + 툴 접근 차단. 셋업 절차는 `docs/tasks/task-009/ops-kakao-setup.md`.
- **카카오 v1 보류(블로커)** — 카카오계정(이메일) 동의항목이 비즈앱(사업자등록) 심사 필요 → 개인앱에서 활성화 불가, GoTrue가 email 스코프 기본 요청해 KOE205. 닉네임·프로필사진 동의항목은 활성화 완료. **개인사업자 등록증 보유 → 비즈앱 전환 시 재개 가능.** v1 auth는 이메일 로그인(autoconfirm)으로 검증 완료.

---

## 2026-07-01 · task-010 — 응원팀 설정 + 원정 일정

> 출처: [docs/tasks/task-010/spec.md](docs/tasks/task-010/spec.md), [handoffs/feat-task-010-schedule.md](handoffs/feat-task-010-schedule.md)

- **응원팀 진실원천 = `profiles.favorite_team_id`(클라우드)**. CurrentTeam(abbr)은 테마 파생 런타임 캐시. FavoriteTeam 상태→CurrentTeam sync(초기로드 `Future.microtask`, select는 직접).
- **"on-demand 1회 조회" = 화면 열 때 DB 최신 1회 fetch**(autoDispose). 앱이 크롤 트리거 안 함(크롤러 주기 유지). 당겨서새로고침 = `ref.invalidate`.
- **원정 판정 = `away_team_id == 내 팀`**(games의 home/away 직접).
- **팀 선택 쓰기 = 낙관적**(로컬·테마 먼저, `profiles` update 실패 시 롤백 + 스낵바).
- **미설정 유저 = 일정/홈 진입 시 팀선택 유도**(온보딩 강제 안 함).

---

## 2026-07-01 · task-012 — 맛집·플랜B (task-013이 물려받음)

> 출처: [handoffs/feat-task-012-places.md](handoffs/feat-task-012-places.md), [handoffs/feat-task-013-planb.md](handoffs/feat-task-013-planb.md)

- **맛집·플랜B = 별도 라우트 `/places/:stadiumId` + 탭 2개(맛집|플랜B)**. 구장 화면 내 섹션 아님 — 이유: task-013 우천취소→플랜B 딥링크를 `?tab=planb`로 깔끔히 재사용. 구장 화면은 가이드에 집중.
- **출처 노출 = `source_url` 외부 브라우저(url_launcher)**. 원출처 신뢰·저작권 안전.
- **우천취소 CTA = 취소/연기 카드 내부 인라인 행**(별도 배너/다이얼로그 아님) — 어느 경기가 취소인지 맥락과 붙어야 명확. 트리거 = `cancelled` + `postponed` 둘 다(status에 우천 구분 필드 없음 → "경기 안 열림"으로 동일 취급).
