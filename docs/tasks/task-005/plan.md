# task-005 plan   (spec: ./spec.md)

## 아키텍처

단발 파이프라인 `fetch → parse → map → upsert`. CLI 진입점에서 날짜범위 받아 1회 실행. 운영 래핑(cron/알림)은 task-006이 이 모듈을 import해 감쌈 → 코어는 순수·테스트 가능하게 유지.

## 파일 구조 (전부 신규, `crawler/`)

```
crawler/
  __init__.py
  __main__.py        # CLI: --from/--to → pipeline.run()
  config.py          # .env 로드: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
  fetch.py           # KBO 공식 일정 HTTP 요청 (date range → raw)
  parse.py           # raw → [RawGame(date,time,away,home,status_label)]
  mapping.py         # abbr 별칭, status 정규화, game_id 합성, KST→UTC
  db.py              # supabase 클라이언트, teams/stadiums 캐시 로드, games upsert
  pipeline.py        # run(from,to): fetch→parse→map→upsert, 집계 리턴
  requirements.txt   # requests, supabase, python-dotenv (+ tz)
  fixtures/          # 실측 응답 스냅샷(테스트·파서 개발용)
.env.example         # (수정) service-role 키 항목 추가
```

## Step 분해

- [ ] **Step 1 — 스파이크 + 스캐폴드**: `crawler/` 골격 + deps + `config.py`(env). KBO schedule.aspx 실제 요청(POST 파라미터/응답)을 실측해 1개 날짜 일정 raw를 받아 `fixtures/`에 저장. D1 폴백 판단(공식 죽었으면 네이버로 전환, handoff `### 결정` 기록).
  - 검증: `python -m crawler.fetch --from <오늘> --to <오늘>` 가 비지 않은 raw 반환. `python -m py_compile crawler/*.py` 통과.
- [ ] **Step 2 — 파서**: raw → 정규화 RawGame 리스트(날짜·시작시각·away·home·status_label·dh 여부). fixture로 개발.
  - 검증: fixture 파싱 → 알려진 그날 경기 수/팀 매칭 (smoke: `python -m crawler.parse fixtures/<file>`). py_compile 통과.
- [ ] **Step 3 — 매핑 + game_id + DB 로드**: abbr 별칭표(WO→KW, SSG=SK, KIA=HT…), status_label→enum 표, 홈팀→stadium_id 역참조, `game_id` 합성(YYYYMMDD+away+home+dh), KST→UTC. `db.py`에서 teams/stadiums dict 캐시 로드.
  - 검증: 임의 RawGame → 올바른 game_id/uuid/UTC 생성 확인(smoke 스크립트). py_compile 통과.
- [ ] **Step 4 — upsert + 파이프라인 + CLI**: `db.upsert_games(on_conflict='game_id')`, `pipeline.run()` 결선, `__main__` CLI. service-role로만 write.
  - 검증: `python -m crawler --from <D> --to <D+6>` 실행 → 에러 없이 "N건 upsert" 출력, py_compile 통과.

## 끝 검증 (구현 완료 후, 숲 단위 1회)

- 코드 리뷰(브랜치 diff 전체) + 수정.
- **DoD/e2e**:
  - T2: 1주 크롤 실행 → DB `games`가 KBO 실제 일정과 일치 + `SELECT game_id,count(*) ... GROUP BY HAVING count>1` = 0행(중복 0).
  - T3: 한 경기 status를 'scheduled'로 둔 뒤 재크롤(취소 케이스/수동 fixture) → 상태 갱신 확인.
  - 키 격리: anon 키로는 upsert 거부됨(RLS) 확인.

## 롤백

전부 add-only(앱·스키마 무영향). 잘못 적재 시 `game_id` 기준 DELETE 후 재크롤. 브랜치 폐기로 코드 롤백.
