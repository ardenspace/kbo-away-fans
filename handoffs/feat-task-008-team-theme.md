# Handoff: feat/task-008-team-theme — @arden

## 2026-06-26

- [x] task-008 팀별 테마 컬러 전환

### 다음
- task-009(deep) 로그인 또는 task-010 응원팀 설정 — task-010에서 `CurrentTeam` notifier에 설정 UI/영속화 연결.

### 마지막 커밋
- 테마 시스템 구현: team_colors/team_theme/team_theme_provider + main.dart 연결. analyze 무경고, test 5개 통과.

### 결정
- 테마 폴더는 PLAN의 `app/lib/theme/` 가 아니라 실제 스캐폴드 위치 `app/lib/shared/theme/` 사용 (task-007 선례).
- 팀 색은 정적 브랜드색 → DB fetch 없이 Dart 상수 맵으로 미러(`scripts/seed/data/teams.json` 와 일치, 키=abbr).
