# Handoff: feat/task-010-schedule — @arden

## 2026-07-01

- [ ] task-010 (deep) 응원팀 설정 → 원정 일정 화면 (필터 + on-demand 조회) (E2·E3·E4, T1)

### 진행
- 브랜치 feat/task-009-login 위에서 분기 (auth 게이트 + profiles 의존).
- PLAN.md task-010 줄에 (deep) 마커 백필 (무게=heavy 확정).
- ✅ spec.md → plan.md 승인.
- ✅ Step 1 teams_provider · Step 2 favorite_team_provider(영속+테마sync) · Step 3 팀선택 화면+라우트 ·
  Step 4 game+away_games_provider · Step 5 일정 화면 실구현 · Step 6 home 정리.
- ✅ 각 Step analyze 0 issues. 전체 flutter test 5 pass (테마 T11 회귀 없음).
- ✅ 끝검증 코드 리뷰(브랜치 diff 전체) — 고칠 결함 없음. analyze 0 / test 5 재확인.
- ✅ 구현 커밋 (초록불 상태 보존).
- ⏳ e2e(사용자 시뮬레이터 게이트) 대기 — task-009 e2e ops 게이트와 같은 종류. task-010은 계속 열림.

### 다음
- 사용자 e2e(로그인→팀선택→저장→재시작유지→away필터→구장이동→테마전환). 검증 통과 시 PLAN task-010 체크.
- 검증용: 내 팀이 away 인 미래 games 행 필요(크롤 실데이터 or 시드).
- 후속: task-011 구장 가이드 화면 — 이 화면의 `/stadium/:id` 라우트 위에 얹음.

### 결정
- **응원팀 진실원천 = profiles.favorite_team_id (클라우드)**. CurrentTeam(abbr)은 테마 파생 런타임 캐시.
  FavoriteTeam 상태→CurrentTeam sync(초기로드는 Future.microtask, select는 직접). → DECISIONS
- **"on-demand 1회 조회" = 화면 열 때 DB 최신 1회 fetch** (autoDispose). 앱이 크롤 트리거 안 함 —
  크롤러가 1분주기 유지. 당겨서새로고침 = ref.invalidate. → DECISIONS
- **원정 판정 = away_team_id == 내 팀** (games의 home/away 직접).
- **팀 선택 쓰기 = 낙관적**(로컬·테마 먼저, profiles update 실패 시 롤백+스낵바).
- **미설정 유저 = 일정/홈 진입 시 팀선택 유도**(온보딩 강제 안 함).

### 블로커
- task-009 e2e 미검증 (별개 트랙). task-010은 그 위에 쌓되, task-009 검증서 수정 나오면 물려받음.

## 2026-07-01 · e2e 검증

- ✅ **통과**: 이메일 로그인 계정으로 NC 다이노스 선택→저장 → `profiles.favorite_team_id = NC` DB 확인(진실원천) → 앱 재시작 유지 → away 일정(NC 7/3~7/9 등) 렌더 → 테마 NC색 전환. 구장 이동(→task-011)·당겨서새로고침 정상.
- 검증 데이터: 크롤 실데이터(미래 원정 35경기, 10팀 전부 보유) 사용.
