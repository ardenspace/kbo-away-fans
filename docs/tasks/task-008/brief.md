# task-008 brief — 팀별 테마 컬러 전환

- **왜**: 응원팀을 바꾸면 앱 전체 테마 컬러가 그 팀 색으로 전환 (PLAN task-008, E9·T11). 게임화 매력 요소.
- **무엇**:
  - `app/lib/shared/theme/team_colors.dart` — 10팀 `abbr → (primary, secondary)` 정적 색 맵 (`scripts/seed/data/teams.json` 와 일치). 팀 미선택 시 쓸 중립 기본색 포함.
  - `app/lib/shared/theme/team_theme.dart` — `(primary, secondary) → ThemeData` 팩토리 (`ColorScheme.fromSeed` 기반, Material 3).
  - `app/lib/shared/theme/team_theme_provider.dart` — Riverpod: 현재 팀 abbr 상태(`StateProvider`/Notifier) + 그로부터 파생되는 `ThemeData` provider. 기본값 = 중립(미선택).
  - `app/lib/main.dart` — `MaterialApp.router` 에 `theme:` 를 provider 와 연결.
- **out (비목표)**: 응원팀 **선택 UI**(task-010), 선택값 영속화/프로필 저장(task-009·010), DB에서 색 fetch(정적이라 불필요), 다크모드.
- **완료조건(DoD)**:
  - ☐ 10팀 색 토큰 정의, `teams.json` 값과 일치 (abbr 키)
  - ☐ 현재 팀 provider 값을 바꾸면 `MaterialApp` 테마 primary 가 그 팀 색으로 전환 (위젯 테스트로 검증)
  - ☐ 팀 미선택(기본) 상태에서도 앱이 정상 렌더 (중립 테마)
  - ☐ 기존 화면(schedule/stadium/stamp) 빌드 안 깨짐
  - ☐ `flutter analyze` 무경고
- **영향파일**: `app/lib/shared/theme/{team_colors,team_theme,team_theme_provider}.dart` (신규), `app/lib/main.dart` (수정), `app/test/team_theme_test.dart` (신규)
- **검증**: `cd app && flutter analyze && flutter test`
