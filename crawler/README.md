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

## 설계 메모

- 소스 = KBO 공식(`GetScheduleList`), JSON 응답. 네이버는 폴백 후보(미사용).
- `game_id` = `YYYYMMDD + away_abbr + home_abbr + dh` (자체 합성, 소스 비종속, 더블헤더 dedup).
- 구장은 **소스 구장 컬럼**을 별칭 매핑(홈팀 역참조 아님 — 잠실 공용/LG 미시드 회피).
- 미등록 팀/구장(2군장·울산·청주 등)은 skip + 로그.
