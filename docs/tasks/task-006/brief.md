# task-006 brief — 크롤러 운영 (cron 2단주기 + 텔레그램 알림 + graceful)

- **왜**: task-005가 만든 단발 `crawler.pipeline.run()`을 맥미니에서 무인 운영. KBO 일정 잦은 변동(우천취소·연기·더블헤더)을 자동 reconcile. (PLAN task-006 · E4·E5)

- **무엇**: `pipeline.run()`을 운영 래퍼로 감싼다.
  1. **2단 주기** (E4) — ⓐ **daily**: 1일 1회, 향후 14일 범위 재크롤(reschedule/취소 reconcile). ⓑ **gameday**: 매분 깨우되 래퍼가 *오늘 경기 윈도우*(첫경기 30분전 ~ 막경기 종료 1h후) 안일 때만 오늘분 크롤, 밖이면 즉시 no-op 종료.
  2. **graceful** (E5) — `pipeline.run()` 예외(네트워크/파싱/HTML변경)를 잡아 **DB 무변경 + non-zero exit**. 크롤 죽어도 앱은 캐시된 DB로 동작(별도 코드 불필요).
  3. **텔레그램 실패 알림** (E5) — 실패 시에만 1건 전송(성공·no-op은 무알림, 노이즈 0). 봇 토큰/chat_id env. 알림 자체 실패는 best-effort(크래시 안 함).
  4. **중복 실행 방지** (동시성) — `fcntl.flock` 비차단 락. 매분 gameday 실행이 느린 크롤과 겹치면 2번째는 즉시 스킵.
  - **스케줄러 = launchd LaunchAgent** (cron 아님). 이유: 맥미니 인프라 선례 — task-001 backup/cloudflared가 launchd("macOS FDA 이슈 회피"). 일관성 유지. plist의 `StartCalendarInterval`(daily) + `StartInterval 60`(gameday).
  - **(out / YAGNI)**: 성공 heartbeat 알림 ✗, 동적 crontab 재작성 ✗, on-demand 앱 조회(task-010) ✗, pipeline 코어 로직 변경 ✗.

- **완료조건(DoD)**:
  - ☐ **graceful (T8)** — fetch 404/예외 강제 시 래퍼 non-zero exit + 텔레그램 알림 1건 + `games` 행수 무변경, 재실행 시 정상
  - ☐ **윈도우 게이트** — 오늘 경기 `scheduled_at` 기반 윈도우 안/밖 판정 단위테스트 통과(경기 없는 날 = 밖)
  - ☐ **flock** — 락 잡힌 상태서 2번째 실행 즉시 스킵(크롤 미수행)
  - ☐ **알림 best-effort** — 텔레그램 env 누락 시 경고 로그만, 크래시 없음
  - ☐ **설치 가능** — daily/gameday plist 2개 + 설치 주석(backup plist 패턴), `.env.example`에 텔레그램 키 추가, README 운영 섹션

- **영향파일**: `crawler/ops.py`(신규 래퍼: mode=daily|gameday, flock, 윈도우, graceful), `crawler/notify.py`(신규 텔레그램), `crawler/config.py`(텔레그램 env), `crawler/db.py`(오늘 경기 조회 1함수), `infra/crawler/com.kbo.crawler.{daily,gameday}.plist`(신규), `.env.example`, `crawler/README.md`, 테스트

- **검증**: `crawler/.venv/bin/python -m pytest crawler/` (윈도우·flock·graceful·notify 단위) + 수동 1회 `python -m crawler.ops --mode daily` 무알림 정상 종료
