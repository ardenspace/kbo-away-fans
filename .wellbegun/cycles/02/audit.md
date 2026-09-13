---
cycle: 2
date: 2026-09-01
---

# Registry audit — before cycle 2

## Roster ↔ code drift
드리프트는 전부 같은 방향이었습니다. 코드에는 있는데 `spec.md` 로스터에만 빠진
항목들이며, 반대 방향(로스터에 있는데 코드가 사라진 항목)은 없었습니다.
사이클 1 진행 중에 폴더별 `REGISTRY.md` 는 같은 커밋에서 갱신되었지만
상위 로스터인 `spec.md` 까지는 되돌려 반영되지 않은 것이 원인입니다.

- **Design tokens**: `RainTokens`(`rain.*`)·`SplashTokens`(`splash.*`) 두 그룹이
  `lib/design/tokens.dart` 에 있는데 로스터에 없었습니다 → 로스터에 두 행 추가.
- **Shared components**: `map_links`·`kCategoryLabels`(`category_labels.dart`)·
  `TeamBadge` 세 항목이 `lib/ui/shared/REGISTRY.md` 에만 있고 `spec.md` 로스터에는
  없었습니다 → 로스터에 세 행 추가.
- **Backend common layers (콘텐츠 파이프라인)**: `crawl-schedule.mjs`(일정 크롤러)·
  `build-places.mjs`(장소 병합기)가 `content-pipeline/REGISTRY.md` 에만 있었습니다
  → 로스터에 두 행 추가.
- **DB schema (JSON 계약)**: `common.defs.schema.json`(팀·구장 안정 id 로스터의
  단일 원본)이 로스터에 없었습니다 → 로스터에 한 행 추가.

## Enforcement status
전체 코드베이스 기준으로 실행했습니다. 실패한 검사는 없습니다.

- `scripts/hooks/check-hardcoded-values.sh` (PostToolUse + pre-commit): pass (exit 0)
- `scripts/hooks/check-registry-sync.sh` (pre-commit): pass (exit 0)
- pre-commit 설치 상태: pass — `core.hooksPath = scripts/hooks` 로 연결되어 있습니다.
- `flutter analyze`: pass — 지적 사항 없음
- `flutter test`: pass — 154개 통과, 1개 skip
- `node content-pipeline/common/validate.mjs`: pass — `data/` 산출물 4종 전부 통과
- `npm --prefix content-pipeline test`: pass — 33개 전부 통과

## Promotion candidates (input to wellspec delta step 2)
- **콘텐츠 로드 실패 + 재시도 폴백** — `lib/features/home/home_screen.dart:335`
  (`_scheduleFallback`), `lib/features/places/stadium_places_screen.dart:135`
  (`_placesFallback`), `lib/features/team_select/team_select_screen.dart:205`
  (`_LoadFailure`) 세 곳에서 "로딩 스피너 / 제목 + 안내 문구 + 다시 시도 버튼" 구조가
  거의 그대로 반복됩니다. 재시도 경로도 셋 다 `invalidateContent` 로 같습니다.
  → shared components 로 승격할 후보입니다.
- **팀 테마 앱바** — `lib/features/home/home_screen.dart:143`,
  `lib/features/places/stadium_places_screen.dart:115`,
  `lib/features/places/place_map_screen.dart:92` 세 곳에서
  `TeamThemeScope.maybeOf(context)` 로 배경·전경색을 꺼내고 같은 제목 스타일을 붙이는
  `AppBar` 구성이 반복됩니다. 화면이 늘어날수록 그대로 복제될 자리입니다.
  → shared components 로 승격할 후보입니다.
- **타이포 조합 스타일** — `TextStyle(fontFamily: TypeTokens.fontFamily, fontSize:
  TypeTokens.*, fontWeight: TypeTokens.*, color: ColorTokens.*)` 네 줄짜리 조합이
  13개 파일에서 38회 반복됩니다. 지금 토큰 레지스트리는 크기·굵기·색을 각각
  낱개로만 제공해서, 조합은 매번 손으로 다시 씁니다.
  → design tokens 에 이름 있는 조합 스타일(예: `TextTokens.heading`)을 추가할
  후보입니다.
