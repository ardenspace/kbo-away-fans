# crawler — KBO 일정 크롤러 코어 (task-005)

KBO 공식 일정을 긁어 Supabase `games` 테이블에 upsert 하는 단발 파이프라인.
운영(cron 2단 주기·텔레그램 알림·graceful)은 **task-006** 이 이 모듈을 감싼다.

## 구조

```
fetch → parse → map → upsert
fetch.py     KBO 공식 GetScheduleList(월 단위 JSON) 요청
parse.py     raw rows → RawGame (날짜·시각·어웨이·홈·구장·상태)
mapping.py   short_name→team, 구장 별칭→stadium, 상태 정규화, game_id 합성, KST→UTC
db.py        Postgres 직결 — teams/stadiums 로드 + games upsert
pipeline.py  run(from,to) 결선
__main__.py  CLI
```

## 설정 (.env — repo 루트)

크롤러는 **Postgres 직결**(DECISIONS task-001 E1). 기존 `DATABASE_URL` 을 그대로 쓴다
(`.env.example` 에 이미 있음 — 별도 키 추가 불필요):

```dotenv
# 맥미니 셀프호스팅 Postgres (infra/supabase/.env POSTGRES_PASSWORD)
DATABASE_URL=postgres://postgres:<password>@127.0.0.1:5434/postgres
```

postgres 슈퍼유저로 접속 → RLS 우회하여 콘텐츠 테이블 write. 앱은 Kong/anon 경유(키격리 E10).

## 실행

```bash
crawler/.venv/bin/python -m crawler --from 2026-06-08 --to 2026-06-14
```

의존성: `crawler/.venv` (requirements.txt — requests, supabase, python-dotenv).

## 운영 (task-006 — cron 2단주기 + 텔레그램 알림 + graceful)

단발 `pipeline.run()` 을 `crawler/ops.py` 가 무인 운영으로 감싼다.

### 2단 주기 (E4)

| 모드 | 주기 | 범위 | plist |
|---|---|---|---|
| `daily` | 매일 04:30 (1일 1회) | 오늘 ~ +14일 재크롤(reschedule/취소 reconcile) | `com.kbo.crawler.daily.plist` |
| `gameday` | 매분(`StartInterval 60`) | 오늘분 — 단, **경기 윈도우**(첫경기 30분전 ~ 막경기 종료 1h후) 안에서만. 밖이면 즉시 no-op | `com.kbo.crawler.gameday.plist` |

매분 깨워도 윈도우 밖이면 요청 0, 안이면 1요청뿐 → 차단 무관(E4). `fcntl.flock` 으로 daily·gameday 중복 실행 방지.

### graceful + 알림 (E5)

- `run()` 예외(네트워크·파싱·HTML 변경) → **DB 무변경 + exit 1 + 텔레그램 알림 1건**. 크롤이 죽어도 앱은 캐시된 DB 로 동작.
- 성공·no-op 은 무알림(노이즈 0). 텔레그램 env 미설정/전송실패는 best-effort(크래시 안 함).

### 설정 (.env — repo 루트)

```dotenv
# 크롤 실패 알림 (없으면 알림만 스킵, 크롤은 정상). 봇=@BotFather, chat_id=받을 대화 ID
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
```

### 실행 / 설치

```bash
# 수동 1회
crawler/.venv/bin/python -m crawler.ops --mode daily
crawler/.venv/bin/python -m crawler.ops --mode gameday

# launchd 등록 (cron 대신 — task-001 backup/cloudflared 선례, macOS FDA 회피)
cp infra/crawler/com.kbo.crawler.daily.plist   ~/Library/LaunchAgents/
cp infra/crawler/com.kbo.crawler.gameday.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kbo.crawler.daily.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kbo.crawler.gameday.plist
# 로그: ~/Library/Logs/kbo-crawler.log
```

## 설계 메모

- 소스 = KBO 공식(`GetScheduleList`), JSON 응답. 네이버는 폴백 후보(미사용).
- `game_id` = `YYYYMMDD + away_abbr + home_abbr + dh` (자체 합성, 소스 비종속, 더블헤더 dedup).
- 구장은 **소스 구장 컬럼**을 별칭 매핑(홈팀 역참조 아님 — 잠실 공용/LG 미시드 회피).
- 미등록 팀/구장(2군장·울산·청주 등)은 skip + 로그.
