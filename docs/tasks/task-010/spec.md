# task-010 spec — 응원팀 설정 → 원정 일정 화면   확정일: 2026-07-01

> heavy (deep). 백링크: PLAN [task-010] · 실행계획 E2·E3·E4 · T1.

## 1. 배경 / 문제

로그인(task-009)까지 끝나면 유저는 인증만 된 빈 상태다. 앱의 첫 가치인
**"내 팀 원정 경기가 언제 어디냐"** 를 아직 못 본다. 지금:
- `profiles.favorite_team_id` 컬럼·RLS는 있으나 **쓰는 코드가 없음** (가입 시 null).
- `CurrentTeam` provider(런타임 abbr)는 있으나 **영속화 안 됨** — 앱 재시작 시 중립 테마로 리셋.
- `games` 테이블은 크롤러가 채우지만 **앱이 읽는 화면이 없음** (`schedule_screen` 은 placeholder).

## 2. 목표 / 비목표

**목표 (DoD):**
- ☐ 응원팀을 고르면 `profiles.favorite_team_id` 에 저장되고, 앱 재시작/재로그인 후에도 유지된다.
- ☐ 응원팀 선택 시 테마 컬러도 전환된다 (`CurrentTeam` 연동, T11 회귀 없음).
- ☐ 원정 일정 화면이 **내 팀이 away 인 경기만** 필터해 다가오는 순으로 보여준다 (T1: 홈/원정 구분 정확).
- ☐ 각 경기 카드에 상대(홈)팀·구장·일시·상태(예정/취소/연기)가 뜬다.
- ☐ 화면 열 때 DB 최신 상태를 1회 조회한다 (on-demand). 재진입/당겨서새로고침 시 갱신.
- ☐ 응원팀 미설정 유저는 일정 진입 시 팀 선택으로 유도된다.

**비목표 (YAGNI):**
- 구장 가이드·맛집·플랜B 화면 (task-011·012·013). 여기선 경기 카드 탭 → 구장 라우트 **연결만**(이동), 내용은 placeholder 유지.
- 과거 경기 히스토리/달력 뷰. 다가오는 경기 리스트만.
- 푸시 알림, 경기 D-day 카운트다운.
- 실시간 스코어. status 텍스트만.

## 3. 설계(안)

### 데이터 흐름
```
profiles.favorite_team_id (uuid, 진실의 원천, 클라우드)
        │  load (로그인 후 1회)               ▲ write (팀 선택 시)
        ▼                                     │
  favoriteTeamProvider (async, teams join)    │
        │ sync abbr →                         │
        ▼                                     │
  CurrentTeam (런타임 abbr, 테마용) ───────────┘ (select 시 양쪽 쓰기)
```

- **진실의 원천 = `profiles.favorite_team_id`** (uuid). `CurrentTeam`(abbr)은 테마 파생용 런타임 캐시.
- **teams 매핑**: `teamsProvider` (전체 팀 1회 로드, keepAlive) 로 abbr↔id↔색 해소. 선택 UI 목록도 여기서.
- **로드**: 로그인 후 `favoriteTeamProvider` 가 `profiles` 행 조회 → team 있으면 abbr 를 `CurrentTeam` 에 sync.
- **쓰기**: `setFavoriteTeam(teamId)` → `profiles` update → `CurrentTeam.select(abbr)`. (낙관적: 로컬 먼저, DB 실패 시 롤백·토스트)

### 화면 / 플로우
- **팀 선택**: 10팀 그리드(팀 색/약칭). 미설정이면 일정 진입 시 이 화면으로. 설정 변경은 일정 화면 AppBar 액션으로 재진입.
- **원정 일정**: `games` where `away_team_id = 내팀` AND `scheduled_at >= 오늘0시`, `scheduled_at` 오름차순.
  join: home team(상대), stadium(원정지). 카드 = [일시 · vs 홈팀 · 구장 · status배지]. 탭 → `/stadium/:id`.
- **상태**: 로딩 스피너 / 빈 리스트("예정된 원정 경기가 없어요") / 에러+재시도.

### on-demand 조회 (E4 해석)
- "on-demand 1회 조회" = **화면 열 때 DB에서 최신 games 1회 fetch** (크롤러가 유지하는 최신 상태를 읽음).
  앱이 크롤을 *트리거*하지 않는다 — 크롤러(task-006)가 경기일 1분 주기로 이미 갱신 중.
- 구현 = `FutureProvider.autoDispose` (화면 dispose 시 폐기 → 재진입 = 재조회). 당겨서새로고침 = `ref.invalidate`.

## 4. 대안 & 결정 ★

| 결정점 | 대안 | 채택 | 이유 |
|---|---|---|---|
| 응원팀 진실원천 | (a) 로컬만 / (b) profiles 클라우드 / (c) 양쪽, 클라우드 우선 | **(c)** | E3=재설치·기기변경 생존. CurrentTeam은 테마 동기 파생이라 유지, profiles가 원천. |
| on-demand 의미 | (a) 화면 열 때 DB 재조회 / (b) 앱이 크롤 트리거 | **(a)** | E4: 크롤러가 이미 1분주기 유지. 앱 트리거는 차단·복잡성↑, 불필요. |
| 원정 판정 | (a) away_team_id=내팀 / (b) stadium.team≠내팀 | **(a)** | games에 home/away 명시 — 직접·정확(T1). |
| 미설정 유저 | (a) 온보딩 강제 / (b) 일정 진입 시 유도 | **(b)** | 강제 온보딩은 과함. 일정 보려 할 때 자연 유도. |
| 쓰기 동기화 | (a) DB먼저 후 로컬 / (b) 낙관적(로컬먼저) | **(b)** | 테마 전환 즉답 UX. 실패 시 롤백+토스트. |

→ 채택 결정은 PR 때 DECISIONS.md 승격.

## 5. 영향 / 리스크

- **계약 변경 없음** — 기존 스키마(profiles/games/teams/stadiums) 읽기·쓰기만. migration 없음.
- 신규 파일: `features/schedule/` (providers, 일정 화면, 경기카드), `features/team/`(팀선택 + favorite provider), 가능하면 `shared/data/teams_provider`.
- 수정: `schedule_screen.dart`(placeholder→실구현), `team_theme_provider`(영속 sync 연결), `router.dart`(팀선택 라우트), `home_screen`(미설정 안내).
- 리스크: ① `CurrentTeam` 영속 연결이 task-008 테마(T11)를 깨면 회귀 → 끝검증에서 확인. ② games 시드 데이터 없으면 빈 화면 — dev 검증용 시드 필요(아래 의존).
- 롤백: 브랜치 폐기. 스키마 불변이라 데이터 영향 없음.

## 6. 의존 / 사인오프

- **의존**: task-009(auth 게이트·profiles 자동생성) — 같은 브랜치 베이스. task-002(스키마)·task-005/006(games 크롤). 
- **검증 데이터**: 내 팀이 away 인 미래 games 행 필요. 크롤러 실데이터 or 시드 한두 건. (e2e 단계에서 확인)
- **물려받는 곳**: task-011·012·013 이 일정 카드 → 구장/맛집/플랜B 진입을 이 화면 위에 얹음. on-demand·라우팅 패턴을 여기서 정함.
- **사인오프**: @arden (솔로). spec 승인 → plan.
