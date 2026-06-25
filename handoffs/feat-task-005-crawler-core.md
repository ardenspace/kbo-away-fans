# Handoff: feat/task-005-crawler-core — @arden

## 2026-06-25

- [ ] task-005

크롤러 코어: KBO 일정 스크랩 → 파싱 → `game_id` upsert → dedup (E4). spec→plan→구현 완료, 끝 검증 통과.

### 마지막 커밋
feat(task-005): KBO 일정 크롤러 코어 — fetch/parse/map/upsert + 직결 DB

### 결정
- **소스(D1)** = KBO 공식 `GetScheduleList`. 스파이크 결과 viewstate 스크래핑이 아니라 **월 단위 JSON** 반환 → 파싱 안정. 네이버 폴백 불필요. → DECISIONS 승격 후보.
- **구장 매핑** = spec 의 "홈팀→구장 역참조" 대신 **소스 구장 컬럼을 별칭 매핑**으로 변경. 이유: ① 잠실 공용인데 stadiums 시드가 잠실=두산 1행뿐(LG 미시드) → 역참조 깨짐 ② 소스가 구장 직접 제공. 짧은명(잠실)→공식명(잠실야구장) 별칭표. → DECISIONS 승격 후보.
- **팀 매핑 단순화** = play 셀이 한글 short_name 사용 → `teams.short_name` 직접 매핑. abbr 별칭(키움 WO/KW)은 game_id 합성에만 국한 → D3 사실상 무력화.
- **DB 접근** = **Postgres 직결(127.0.0.1:5434, psycopg2)** — DECISIONS task-001(E1) "크롤러=Postgres 직결" 준수. (초안은 Kong+service-role 로 갔다가 락드 결정 충돌 발견 → 직결로 수정. seed.py 와 일관, Kong 비의존.) postgres 슈퍼유저 = RLS 우회. 기존 `DATABASE_URL` 사용 → 별도 env 추가 불필요.
- **미등록 구장**(2군장·울산·청주 등) = skip + 로그 (V1 YAGNI).

### 블로커 / 인계
- 크롤러는 `DATABASE_URL`(.env.example 기존 항목) 사용 — 별도 키 추가 불필요(직결 전환으로 .env 차단 이슈 해소).
- 끝 검증(직결): T2(30건·중복0), T3(reconcile: scheduled→재크롤→cancelled), 멱등(행수 30 유지) 통과. 키격리는 직결이 슈퍼유저라 크롤러 무관, 앱 anon write 거부는 task-002 RLS 로 확인됨.

### 다음
- 마무리: 커밋 + PLAN [task-005] 체크 + main 머지. PR 때 위 D1·구장매핑 결정 DECISIONS.md 승격.
- 후속 task-006: 이 `crawler.pipeline.run()` 을 cron 2단 주기 + 텔레그램 알림 + flock + graceful 로 감쌈.
