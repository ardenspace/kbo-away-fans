# task-005 spec — 일정 크롤러 코어   확정일: 2026-06-25

> heavy(deep). PLAN [task-005] · 실행계획 E4. 후속 task-006(운영: cron/알림)과 분리.

## 1. 배경 / 문제

KBO는 공식 오픈 API가 없고 일정이 우천으로 자주 바뀐다(취소/연기/더블헤더). 앱의 일정·우천 플랜B 흐름(task-010·013, T1/T3)이 전부 `games` 테이블을 먹는데, 지금 이 테이블을 채우는 주체가 없다. 외부 소스에서 일정을 긁어 `games`에 신뢰 가능하게 적재하는 **코어 파이프라인**이 필요하다.

## 2. 목표 / 비목표

**목표 (이번 task의 DoD)**
- [ ] 날짜 범위(또는 월)를 받아 KBO 일정을 1회 스크랩 → 파싱 → `games` upsert 하는 **단발 실행 가능한 파이썬 모듈** (`crawler/`).
- [ ] 각 경기를 결정적 `game_id`로 식별 → 같은 경기 재크롤 시 **중복 row 0** (dedup), 상태만 갱신(예정→취소/연기 reconcile).
- [ ] 팀/구장 텍스트 → DB `teams`/`stadiums` uuid 매핑 (홈팀 → 구장).
- [ ] service-role 키로만 write (E10). anon은 못 씀.
- [ ] 검증: 임의 1주 크롤 → `games`가 KBO 실제 일정과 일치, game_id 중복 0 (T2). "예정"→"취소" 케이스 재크롤 시 상태 갱신 (T3).

**비목표 (out)**
- ⏸ cron / 2단 주기 / 텔레그램 실패알림 / flock 중복방지 / graceful 운영 → **task-006**.
- ⏸ 경기 결과·스코어·라인업 (일정/상태만).
- ⏸ 앱 on-demand 조회 (앱 쪽 task-010).
- ⏸ LLM 추출 파이프라인 (V1.5).

## 3. 설계(안)

**파이프라인**: `fetch(date_range) → parse → reconcile/map → upsert(games)`

- **데이터 모델**: 기존 `games`(003) 그대로. 키 = `game_id text UNIQUE`. 컬럼: home_team_id, away_team_id, stadium_id, scheduled_at(timestamptz, KST→UTC), status('scheduled'|'in_progress'|'finished'|'cancelled'|'postponed').
- **game_id 포맷** = `YYYYMMDD + away_abbr + home_abbr + dh_index` (예: `20260405OBLG0`). 더블헤더는 dh_index 0/1로 분리 → 자연 dedup. KBO 공식 game_id와 동형이고 `teams.abbr`(OB/LG/SK/HT/LT…레거시 코드)와 정렬됨.
- **매핑**: 소스 팀명/코드 → `teams.abbr` → team_id. **stadium_id = 홈팀의 구장** (`stadiums.team_id`로 역참조; 중립구장 예외는 §5 리스크). 시작 시 teams/stadiums 한 번 로드해 dict 캐시.
- **upsert**: supabase-py `.upsert(rows, on_conflict='game_id')`. status는 매 크롤 덮어씀 → reconcile.
- **상태 매핑**: 소스 라벨(예정/경기전/취소/우천취소/서스펜디드/종료…) → 5개 enum으로 정규화하는 테이블.
- **위치/스택**: `crawler/` (Python). `requests`(or httpx) + 파서, `supabase` 클라이언트, `.env`로 URL/service_role 키. 단발 진입점 `python -m crawler --from YYYY-MM-DD --to YYYY-MM-DD`.

## 4. 대안 & 결정 ★ (PR 때 DECISIONS 승격)

**D1 — 일정 소스**
| 안 | 장 | 단 |
|---|---|---|
| **A. KBO 공식** (koreabaseball.com schedule.aspx, POST/ASP.NET) | 정확도 1위(정보 집약이 제품 본체, T2). game_id·팀코드 공식 | ASP.NET POST(viewstate)·동적페이지라 파싱 까다로움, HTML 변경 취약 |
| B. 네이버 스포츠 | 파싱 쉬움(정형 응답) | 결측/부정확 사례 보고됨, 비공식 endpoint 변동 |
| C. Statiz 등 | 과거데이터 풍부 | 일정 신선도·매너 불확실 |

→ **결정: A(KBO 공식)**. 제품 가치가 "정보 정확/집약"이라 소스 정확도 우선. 단 HTML 취약성은 task-006 graceful+알림(E5)으로 방어. *정확한 요청 shape(POST 파라미터/응답 구조)는 plan Step 1에서 실측 스파이크로 확정* — 죽었으면 B로 폴백.

**D2 — game_id 생성 주체**: 소스의 공식 game_id를 신뢰하지 않고 **우리가 (날짜+away+home+dh)로 합성**. 이유: 소스 비종속(B 폴백 시에도 동일 키 유지), 더블헤더 dh_index 우리 규칙으로 통제.

**D3 — Kiwoom 코드 불일치**: KBO 공식은 키움=`WO`, 우리 `teams.abbr`=`KW`. → **매핑 테이블에 별칭**(`WO→KW`, 그 외 SSG `SK`, KIA `HT` 등도 명시)로 흡수. abbr 자체는 안 바꿈(앱·시드 영향 회피).

## 5. 영향 / 리스크

- **계약(트리거①)**: `games` 테이블에 **쓰기** 진입(첫 writer). 스키마 변경 없음(003 그대로 사용) → migration 불필요. service-role 키 신규 사용처(crawler) — `.env.example`에 키 항목 추가.
- **리스크**:
  - 중립구장/제3구장 개최(올스타·특별경기) → 홈팀 역참조가 틀릴 수 있음 → V1은 정규시즌만 대상, 예외는 로그만 남기고 skip(과엔지니어링 금지).
  - 소스 HTML/응답 변경 → 깨짐. 코어는 "파싱 실패 시 예외+0건 적재 안 함"까지만, 알림·graceful은 task-006.
  - 타임존: 소스 KST → DB는 timestamptz(UTC 저장). 변환 단일 지점.
- **롤백**: 코드 add-only(앱 무영향). 잘못 적재 시 `game_id` 기준 삭제/재크롤. 스키마 롤백 불필요.

## 6. 의존 / 사인오프

- **이 결과물 대기(트리거③)**: task-006(운영 래핑 — 이 코어 진입점을 cron+알림으로 감쌈), task-010(일정 화면 — `games` 데이터 소비).
- **선행 충족**: task-002(games 스키마)·task-003/004(teams/stadiums 시드) 완료 → 매핑 대상 존재.
- **사인오프**: @arden (솔로). spec 승인 → plan.md.
