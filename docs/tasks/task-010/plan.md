# task-010 plan   (spec: ./spec.md)

**아키텍처 한 줄:** Riverpod(codegen) 데이터 레이어 — `teamsProvider`(전체 팀) ·
`favoriteTeamProvider`(profiles 원천, CurrentTeam 테마 sync) · `awayGamesProvider`(games away 필터) —
위에 팀선택 화면 + 원정 일정 화면을 얹고 라우터에 연결.

## 파일 구조

신규:
- `app/lib/features/team/team.dart` — Team 모델 (id·abbr·name·shortName·색)
- `app/lib/features/team/teams_provider.dart` — 전체 팀 1회 로드(keepAlive) + abbr/id 해소
- `app/lib/features/team/favorite_team_provider.dart` — profiles 원천 로드/쓰기 + CurrentTeam sync
- `app/lib/features/team/team_select_screen.dart` — 10팀 그리드 선택 UI
- `app/lib/features/schedule/game.dart` — Game 모델 (+ 상대팀·구장 join 필드)
- `app/lib/features/schedule/away_games_provider.dart` — away 필터·upcoming 조회(autoDispose)

수정:
- `app/lib/features/schedule/schedule_screen.dart` — placeholder → 실구현
- `app/lib/router/router.dart` — `/team-select` 라우트 추가
- `app/lib/router/home_screen.dart` — 미설정 안내/진입 정리
- `app/lib/shared/theme/team_theme_provider.dart` — 영속 sync 연결 (주석대로 task-010 연결점)

각 Step 검증(공통): `cd app && dart run build_runner build --delete-conflicting-outputs && flutter analyze`
롤백(공통): 해당 Step 신규파일 삭제 / 수정파일 `git checkout` — 스키마 불변이라 데이터 영향 없음.

## Step 분해

- [ ] **Step 1 — Team 모델 + teamsProvider**
  - `team.dart` 모델(불변), `teams_provider.dart`: `teams` 전체 select(keepAlive), abbr→Team·id→Team 헬퍼.
  - 검증: build_runner + analyze 0 issues.

- [ ] **Step 2 — favoriteTeamProvider + 영속 sync**
  - `favorite_team_provider.dart`: ① 로그인 후 `profiles.favorite_team_id` 조회→Team 해소(async),
    ② `setFavoriteTeam(teamId)` = profiles update + `CurrentTeam.select(abbr)`(낙관적, 실패 롤백),
    ③ 로드 성공 시 abbr 를 `CurrentTeam` 에 sync. `team_theme_provider` 연결점 주석 해소.
  - 검증: build_runner + analyze. 기존 `team_theme_test` 통과(테마 회귀 없음).

- [ ] **Step 3 — 팀 선택 화면 + 라우트**
  - `team_select_screen.dart`: `teamsProvider` 그리드(팀 색·약칭), 탭 시 `setFavoriteTeam` → 뒤로/일정.
  - `router.dart` 에 `/team-select` 추가. 현재 응원팀이면 체크 표시.
  - 검증: build_runner + analyze.

- [ ] **Step 4 — Game 모델 + awayGamesProvider**
  - `game.dart`: Game(+ homeTeam·stadium 표시 필드, status enum). 
  - `away_games_provider.dart`: `FutureProvider.autoDispose` — games where `away_team_id=내팀`
    AND `scheduled_at>=오늘0시`, join home team·stadium, `scheduled_at` asc.
  - 검증: build_runner + analyze.

- [ ] **Step 5 — 원정 일정 화면 실구현**
  - `schedule_screen.dart`: `awayGamesProvider` watch → 로딩/에러+재시도/빈상태/리스트.
    경기카드[일시·vs 홈팀·구장·status배지] 탭→`context.go('/stadium/:id')`.
    당겨서새로고침=`ref.invalidate`. AppBar 액션=팀 변경(`/team-select`).
  - 미설정(favorite null) 유저 진입 시 팀 선택 유도.
  - 검증: build_runner + analyze.

- [ ] **Step 6 — 진입 정리 + 회귀 확인**
  - `home_screen.dart`: 응원팀 미설정/설정 상태 안내 정리, 일정·팀설정 진입.
  - 끝검증 전 자체 점검: 테마 전환(T11)·라우팅 회귀 없음.
  - 검증: build_runner + analyze + `flutter test`.

## 끝 검증 (Step 후, 별도 게이트)

- 코드 리뷰(브랜치 diff 전체) + 수정.
- e2e: 시뮬레이터 — 로그인→팀 선택→profiles 저장 확인→재시작 후 유지→원정 일정 away만 뜸→
  카드 탭 구장 이동→테마 전환. (검증용 games 데이터: 크롤 실데이터 or 시드 한두 건)
