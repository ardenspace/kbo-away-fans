---
cycle: 3
date: 2026-09-12
---

# Registry audit — before cycle 3

## Roster ↔ code drift

- **Design tokens:** 확인된 드리프트 없음. `ColorTokens`·`TextTokens`·`RainTokens`·
  `SplashTokens`·`BadgeTokens`·`BadgeTierTokens`·`MotionTokens`·`ProfileTokens`와
  `TeamThemes` 10종이 현재 코드와 사이클 1·2 로스터의 합에 맞는다.
- **Shared components:** 확인된 드리프트 없음. `lib/ui/shared/REGISTRY.md`의 21개
  경로가 실제 파일과 일치하고 `check-registry-sync.sh`가 통과한다.
- **Backend common layers:** 확인된 드리프트 없음. `lib/backend/REGISTRY.md`의 경로가
  실제 파일과 일치하고 `check-registry-sync.sh`가 통과한다.
- **DB schema / content pipeline:** 확인된 드리프트 없음. 네 JSON 산출물이 현재
  스키마로 검증되고 content pipeline 61개 테스트가 통과한다.

이번 감사에서 로스터를 고칠 항목은 없었다. 사용자가 작업 중인 홈 헤더 변경과
`visualizations/`의 미추적 디자인 파일은 보존했으며 감사 커밋은 만들지 않았다.

## Enforcement status

- `scripts/hooks/check-hardcoded-values.sh`: pass (exit 0)
- `scripts/hooks/check-registry-sync.sh`: pass (exit 0)
- `scripts/hooks/check-no-location-upload.sh`: pass (exit 0)
- `scripts/hooks/check-firebase-import-boundary.sh`: pass (exit 0)
- `flutter analyze`: pass — 지적 사항 없음
- `flutter test`: pass — 928개 통과, 1개 skip
- `node content-pipeline/common/validate.mjs`: pass — 산출물 4종 통과
- `npm --prefix content-pipeline test`: pass — 61개 통과
- pre-commit 설치 상태: **FAIL** — 저장소 안의 `scripts/hooks/pre-commit`은 있으나
  이 clone의 `core.hooksPath`가 설정되어 있지 않다. 새 사이클의 기반 단계에서
  `git config core.hooksPath scripts/hooks`로 복구하고 실제 위반 커밋 차단을 확인한다.

> 첫 content pipeline 실행은 `content-pipeline/node_modules`가 없어 `ajv` import에서
> 실패했다. `npm ci --prefix content-pipeline` 후 위 두 검사를 다시 실행해 통과했다.
> 의존성 설치 문제이며 코드·계약 실패는 아니다.

## Promotion candidates (input to wellspec delta step 2)

- **앱 전역 응원팀 테마 브리지** — `TeamThemeScope`는 일부 위젯만 직접 읽고
  `MaterialApp.ThemeData`는 고정 팔레트라, AppBar·하단 탭·버튼·시트·선택 상태가
  화면마다 `ColorTokens` 또는 팀 색을 따로 고른다. `lib/app.dart`,
  `lib/ui/shared/main_tab_scaffold.dart`, `lib/ui/shared/team_themed_app_bar.dart`,
  `lib/features/*/*_screen.dart` 전반에서 보인다. 응원팀을 앱 테마의 주체로 삼는
  공통 경계가 design tokens/shared components 로 승격될 후보.
- **실시간 원정 상태 모델** — 다음 경기·취소·날씨·위치 신호를
  `lib/features/home/home_screen.dart`가 직접 조합하고 있다. 경기 전/이동 중/구장
  근처/경기 중/경기 후/우천 취소를 여러 화면과 모션이 함께 소비하려면 우선순위와
  시간 경계를 한 값으로 내보내는 feature-level 공통 모델 후보.
- **쿨톤 표면 셸** — 테두리 있는 중립 카드가 `scratch_card.dart`,
  `visit_status_notice.dart`, `home_screen.dart`, `stadium_picker.dart` 등에서 각각
  `Container`/`BoxDecoration`으로 조립된다. 새 쿨톤 surface·팀색 tint·선택/강조
  상태를 일관되게 적용할 shared component 또는 명명된 decoration token 후보.
- **분위기/모션 설정 경계** — 현재 `WeatherBackdrop`과 각 애니메이션은 독립적으로
  움직이고, 시간대 분위기 끄기·모션 감소·배터리 절약을 한곳에서 전달하는 계약이
  없다. 앱 설정과 여러 상태 비주얼이 함께 소비할 공통 설정/정책 후보.
