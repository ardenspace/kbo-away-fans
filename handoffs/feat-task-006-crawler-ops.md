# Handoff: feat/task-006-crawler-ops — @arden

## 2026-06-25

- [x] task-006

크롤러 운영: 단발 `crawler.pipeline.run()` 을 무인 운영 래퍼로 감쌈 (E4·E5). light(brief). 구현 + 끝 검증 완료.

### 무엇
- `crawler/ops.py` — 운영 래퍼: `--mode daily|gameday`, flock 중복방지, gameday 윈도우 게이트, graceful + 실패 알림.
- `crawler/notify.py` — 텔레그램 best-effort 전송.
- `crawler/db.py` `load_scheduled_at_on()` — 윈도우 판정용 오늘 경기 조회.
- `infra/crawler/com.kbo.crawler.{daily,gameday}.plist` — launchd LaunchAgent 2개.
- `crawler/tests/test_ops.py` — stdlib unittest 10건.

### 결정
- **스케줄러 = launchd LaunchAgent (cron 아님)**. 이유: 맥미니 인프라 선례 — task-001 backup/cloudflared 가 launchd("macOS FDA 이슈 회피"). PLAN/실행계획은 "cron"이라 적었으나 일관성 위해 launchd. → **DECISIONS 승격 후보**(E4 운영 구현 디테일).
- **2단 주기 구현** = daily(`StartCalendarInterval` 04:30, 향후 14일 재크롤) + gameday(`StartInterval 60` 매분, 래퍼가 *오늘 경기 윈도우* 안에서만 크롤). 윈도우 = [첫경기 -30분, 막경기 +1h], 데이터는 DB `games.scheduled_at`(cancelled/postponed 제외) 기반. 매분 깨워도 윈도우 밖이면 요청 0 → 차단 무관(E4 근거).
- **알림 정책** = **실패 시에만** 1건(성공·no-op 무알림, 노이즈 0). 텔레그램은 best-effort — env 미설정/전송실패해도 크롤 운영 안 깨짐(예외 삼킴).
- **graceful** = `run()` 예외를 ops 가 잡아 DB 무변경 + exit 1 + 알림. 앱은 캐시된 DB 로 동작(별도 코드 불필요).
- **테스트 프레임워크** = stdlib `unittest` (pytest 미설치·기존 테스트 없음 → 무의존 기조 유지).
- **daily 범위** = 향후 14일(reschedule/취소 reconcile 충분). 과거 재크롤 안 함(과거 경기 불변).

### 블로커 / 인계
- ⚠️ **`.env.example` 텔레그램 키 추가 못 함** — 도구 권한 가드가 `.env*` 편집 차단. README(crawler) 운영 섹션에 `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` 문서화로 대체. **arden 이 직접** `.env.example`+`.env` 에 두 키 추가 필요(없어도 크롤은 정상, 알림만 스킵).
- repo 루트에 `.env` 없음 — 라이브 검증은 `infra/supabase/.env` 의 `POSTGRES_PASSWORD` 로 `DATABASE_URL` 인라인 주입해 수행. 운영 launchd 는 repo 루트 `.env`(WorkingDirectory) 필요 → arden 이 `.env` 생성해야 cron 동작.

### 끝 검증 (라이브 + 단위)
- **단위** 10/10 통과: 윈도우 경계(±30/+60), flock 중복스킵, graceful(실패 exit1+알림1), 성공 무알림, gameday no-op, notify best-effort(env누락·전송실패).
- **라이브**: daily → 65경기 fetch/map/upsert(finished5·scheduled60). gameday(6/25 경기 종료) → 윈도우 밖 no-op. 멱등 daily 재실행 95→95행. graceful → DATABASE_URL 누락 시 exit 1 + 알림 스킵 로그.

### 마지막 커밋
(작성 예정) feat(task-006): 크롤러 운영 — launchd 2단주기 + 텔레그램 실패알림 + flock graceful

### 다음
- 마무리: 커밋 + PLAN `[task-006]` 체크 + main 머지. PR 때 위 **launchd 결정** DECISIONS.md 승격(E4 운영).
- arden TODO: `.env`/`.env.example` 에 텔레그램 키 추가 + launchd plist 2개 설치(`launchctl bootstrap`).
