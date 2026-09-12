---
status: approved
cycle: 3
---

# kbo-away-fans — spec (사이클 3)

## Resolved decisions

| decision | grade | choice | ADR |
|---|---|---|---|
| 팀·기본 테마의 전역 소유권 | L | 앱 루트 Riverpod 상태가 하나의 `AppVisualTheme`을 만들고 `MaterialApp`·탭 Navigator·route·sheet·overlay가 모두 이를 상속 | see decisions.md 2026-09-12 |
| 팀 없음 프로필과 설정 저장 | L | `favoriteTeamId`를 nullable로 바꾸고 `defaultThemeFamily`(A/B), `brightnessPreference`(auto/light/dark)를 사용자 문서에 저장; 기기 prefs는 계정 귀속 첫 프레임 캐시 | see decisions.md 2026-09-12 |
| 자동 밝기와 수동 override | M | KST 07:00–18:59는 밝음, 나머지는 어두움; light/dark 수동값은 auto로 복귀할 때까지 우선 | see decisions.md 2026-09-12 |
| 실시간 원정 상태 판정 | M | `cancelled > live > nearby > moving > postGame > preGame > idle` 우선순위의 순수 feature 모델; 신호가 없거나 실패하면 idle | see decisions.md 2026-09-12 |

## Registries — cycle 3 extensions

### Design tokens

토큰 원본은 `lib/design/tokens.dart`, 팀 원본은 `lib/design/team_themes.dart`다.

| name | purpose | concrete values / location | use when |
|---|---|---|---|
| `neutral.*` | 공통 쿨톤 배경·표면·잉크 | light bg `#EEF3FB`, surface `#F9FBFF`, ink `#15213A`, muted `#68738A`, line `#D8E0ED`; dark bg `#11162B`, surface `#1A2140`, ink `#F8F7FF`, muted `#B8C0D4`, line `#313A5C` | 앱 본체 모든 표면(스플래시 제외) |
| `defaultTheme.a.*` | 팀 없음 A 계열 | light: primary `#9381FF`, secondary `#FFD8BE`, bg `#F8F7FF`; dark: primary `#9381FF`, secondary `#FFD8BE`, bg `#5141AA`; 전경은 대비 토큰 | 팀 없음 + A 선택 |
| `defaultTheme.b.*` | 팀 없음 B 계열 | light: primary `#4A69CE`, secondary `#ECFFBE`, bg `#E5F8F0`; dark: primary `#4A69CE`, secondary `#ECFFBE`, bg `#314B9D`; 전경은 대비 토큰 | 팀 없음 + B 선택 |
| `semantic.*` | 성공·경고·취소 의미 우선 | 기존 success/warning/danger 유지, 테마색으로 치환 금지 | 상태 전달 |
| `journey.*` | 약한 티켓 혼합·경로·도착·라이브 연출 수치 | ticket end = primary 70% + secondary 30%, tint 6–8%, 기존 MotionTokens/reduced motion 사용 | 실시간 홈 상태 비주얼 |

### Shared components

| name | purpose | location | use when |
|---|---|---|---|
| `AppVisualTheme` | 앱 전역 최종 색 역할과 ThemeData를 단일 값으로 표현 | `lib/design/app_theme.dart` | `MaterialApp`부터 모든 route/overlay까지; 실제 루트 소유·배선은 plan 3.1 |
| `ThemedSurface` | 쿨톤 surface + 선택적 팀 tint의 표준 카드 | `lib/ui/shared/themed_surface.dart` | 두 화면 이상 카드 표면 |
| `JourneyTicket` | 약한 primary→30% secondary 티켓 | `lib/ui/shared/journey_ticket.dart` | 홈 경기 전·취소 상태 |
| `JourneyStatusVisual` | 이동·도착·라이브·취소 상태의 사건 중심 비주얼 | `lib/ui/shared/journey_status_visual.dart` | 홈 실시간 여정 |
| `ThemeSettingsSheet` | A/B 계열과 auto/light/dark 설정 | `lib/ui/shared/theme_settings_sheet.dart` | 설정 진입점 |

기존 `TeamThemeScope`는 목적지/경기 보조 맥락용으로만 남기고 앱 최종 테마를 소유하지 않는다.

### Backend common layers

| name | purpose | location | use when |
|---|---|---|---|
| `UserDataStore` profile theme fields | nullable favorite team과 기본 계열·밝기 설정의 원본 및 patch | `lib/backend/user_data.dart` | 프로필 생성·팀/테마 설정 변경 |

### DB schema

| entity | delta | defined in | ownership notes |
|---|---|---|---|
| `users/{uid}` | `favoriteTeamId: teamId?`, `defaultThemeFamily: a|b`, `brightnessPreference: auto|light|dark`; `profileThemeKey` 제거 | `docs/firestore-schema.md`, `firestore.rules` | profile/theme slice only; 기존 문서는 읽기 시 favoriteTeamId와 A/auto 기본값으로 호환 |

### Promotion candidate disposition

- 앱 전역 응원팀 테마 브리지 — L, 승격 (`AppVisualTheme`).
- 실시간 원정 상태 모델 — M, feature-level 공통 순수 모델로 승격.
- 쿨톤 표면 셸 — M, `ThemedSurface`로 승격.
- 분위기/모션 설정 경계 — M, 앱 테마 설정과 접근성 정책에 승격.

## Implementer discretion

- provider/notifier의 내부 클래스 분할과 private helper 이름
- 상태별 한국어 세부 카피와 아이콘 선택
- 테스트 fixture 및 golden 사용 여부
- 07:00/19:00 경계 외의 전환 애니메이션 내부 구현
- 한 화면에서만 쓰는 장식 painter의 파일 분리

## Enforcement plan

- 기존 `check-hardcoded-values.sh`, `check-registry-sync.sh`, 위치·Firebase 경계 검사를 pre-commit에서 유지한다.
- phase 1에서 `git config core.hooksPath scripts/hooks`를 복구하고 실제 위반 fixture로 차단을 확인한다.
- cycle 3 전역 테마 seam 테스트는 `MaterialApp`, 중첩 Navigator, sheet, overlay가 같은 `AppVisualTheme`을 읽는지 검증한다.
- `flutter analyze`, 전체 `flutter test`, `git diff --check`를 최종 게이트로 사용한다.
