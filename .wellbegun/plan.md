---
status: approved
cycle: 3
---

# kbo-away-fans — plan (사이클 3)

## Phases

| phase | delivers | steps |
|---|---|---|
| 1 | cycle 3 foundations + enforcement + legacy nickname/team patch compatibility | 1.1–1.5 |
| 2 | 팀 없음과 테마 설정의 저장·선택 journey | 2.1–2.2 |
| 3 | 전역 테마의 앱 본체 전면 적용 | 3.1–3.2 |
| 4 | 실시간 원정 홈 상태 시각화 | 4.1–4.2 |
| 5 | 통합·접근성·회귀 검증 | 5.1 |

## Step contracts

### Step 1.1: 프로필 테마 스키마 확장
1. **Goal:** nullable 응원팀과 A/B·auto/light/dark 설정을 사용자 문서 계약 전체에 반영한다.
2. **Acceptance criteria:** 새/기존 문서를 모두 읽고, 규칙은 허용값만 받으며 위치 필드는 계속 거부한다.
3. **Boundary tests:** `flutter test test/backend/user_data_test.dart test/backend/user_data_firestore_store_test.dart` → 0; `npm --prefix firebase test` → 0.
4. **Registries to read:** `lib/backend/REGISTRY.md`, `docs/firestore-schema.md`.
5. **Verification tier:** fresh
6. **Discretion scope:** payload helper 내부 구조와 fixture 이름.

### Step 1.2: 토큰과 전역 AppVisualTheme
1. **Goal:** 쿨톤·A/B·팀 테마를 하나의 최종 역할 값과 ThemeData로 만든다.
2. **Acceptance criteria:** 팀이 있으면 팀색, 없으면 계열/밝기 얼굴이 선택되고 시맨틱 색은 고정된다.
3. **Boundary tests:** `flutter test test/design/app_theme_test.dart test/design/tokens_test.dart` → 0; `flutter analyze lib/design` → 0.
4. **Registries to read:** `.wellbegun/spec.md` Design tokens, `lib/ui/shared/REGISTRY.md`.
5. **Verification tier:** fresh
6. **Discretion scope:** private 색 혼합 helper와 ThemeData 세부 필드.

### Step 1.3: 공유 표면·여정 컴포넌트 골격
1. **Goal:** ThemedSurface, JourneyTicket, JourneyStatusVisual, ThemeSettingsSheet를 만들고 로스터에 등록한다.
2. **Acceptance criteria:** 컴포넌트는 AppVisualTheme만 읽고 raw 색을 만들지 않으며 reduced motion 대안을 갖는다.
3. **Boundary tests:** `flutter test test/ui/shared/cycle3_theme_components_test.dart` → 0; `bash scripts/hooks/check-registry-sync.sh` → 0; `bash scripts/hooks/check-hardcoded-values.sh` → 0.
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`, `.wellbegun/spec.md` Shared components.
5. **Verification tier:** fresh
6. **Discretion scope:** 아이콘·단일 사용 painter 구조.

### Step 1.4: enforcement 복구
1. **Goal:** 저장소 pre-commit 경로를 복구하고 기존 검사 전체가 실제로 실행되게 한다.
2. **Acceptance criteria:** `core.hooksPath`가 `scripts/hooks`이고 모든 hook 검사가 통과한다.
3. **Boundary tests:** `test "$(git config core.hooksPath)" = scripts/hooks` → 0; `bash scripts/hooks/check-hardcoded-values.sh && bash scripts/hooks/check-registry-sync.sh && bash scripts/hooks/check-no-location-upload.sh && bash scripts/hooks/check-firebase-import-boundary.sh` → 0.
4. **Registries to read:** `.wellbegun/spec.md` Enforcement plan.
5. **Verification tier:** basic
6. **Discretion scope:** 없음.

### Step 1.5: legacy profile backfill-on-write
1. **Goal:** 사이클 3 이전 사용자 문서의 닉네임·응원팀 부분 수정에 A/auto 기본값을 함께 채워 실제 Firestore 쓰기를 성공시킨다.
2. **Acceptance criteria:** `defaultThemeFamily`와 `brightnessPreference`가 없는 기존 문서에 닉네임만 또는 응원팀만 패치해도 저장 결과가 각각 `a`/`auto`를 포함하며, 이미 저장된 계열·밝기 값은 덮어쓰지 않고, fake backend와 실제 Firestore 규칙이 같은 legacy-patch probe 행렬을 통과한다.
3. **Boundary tests:** `flutter test test/backend/legacy_profile_backfill_test.dart` → 0; `node --test firebase/test/phase1-r3-legacy-patch-probe.test.mjs` → 0.
4. **Registries to read:** `lib/backend/REGISTRY.md`, `docs/firestore-schema.md`.
5. **Verification tier:** basic
6. **Discretion scope:** A/auto 보충을 patch 변환 계층과 store 경계 중 어디에 둘지, 공유 probe fixture의 이름.

### Step 2.1: 팀 없음 선택과 복원
1. **Goal:** 온보딩/팀 변경에서 팀 없음을 정상 저장하고 마지막 A/B 계열을 보존한다.
2. **Acceptance criteria:** 팀 없음으로 홈에 진입하며 팀 선택 후 해제하면 이전 계열이 복원된다; 기존 프로필은 A/auto로 호환된다.
3. **Boundary tests:** `flutter test test/features/team_select/selected_team_test.dart test/features/team_select/team_select_test.dart test/features/team_select/cycle3_no_team_test.dart` → 0.
4. **Registries to read:** `lib/backend/REGISTRY.md`, `lib/ui/shared/REGISTRY.md`.
5. **Verification tier:** fresh
6. **Discretion scope:** 팀 없음 버튼의 세부 카피.

### Step 2.2: 설정 시트
1. **Goal:** 설정에서 A/B 계열과 auto/light/dark를 바꾸고 즉시 전역 반영한다.
2. **Acceptance criteria:** 팀 선택 중에는 계열 컨트롤이 저장되지만 최종 팀 테마가 우선하고, 팀 없음 복귀 시 보인다.
3. **Boundary tests:** `flutter test test/features/profile/cycle3_theme_settings_test.dart` → 0.
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`, `lib/backend/REGISTRY.md`.
5. **Verification tier:** basic
6. **Discretion scope:** 설정 진입 아이콘과 보조 문구.

### Step 3.1: MaterialApp·탭·Navigator 테마 관통
1. **Goal:** 앱 루트 ThemeData가 하단 탭과 모든 중첩 Navigator에 단일 테마를 전달한다.
2. **Acceptance criteria:** 팀 변경/팀 없음/밝기 변경 시 살아 있는 다섯 탭과 새 route가 함께 갱신된다.
3. **Boundary tests:** `flutter test test/cycle3_global_theme_seam_test.dart test/ui/shared/main_tab_scaffold_test.dart` → 0.
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`.
5. **Verification tier:** fresh
6. **Discretion scope:** ThemeData 세부 Material 상태 값.

### Step 3.2: 화면별 고정 팔레트 제거
1. **Goal:** 스플래시를 제외한 화면의 background/surface/text/accent를 AppVisualTheme 역할로 교체한다.
2. **Acceptance criteria:** AppBar·카드·칩·CTA·sheet가 공통 쿨톤과 선택 테마를 따르고 semantic 상태는 유지된다.
3. **Boundary tests:** `flutter test test/features test/ui/shared` → 0; `bash scripts/hooks/check-hardcoded-values.sh` → 0.
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`.
5. **Verification tier:** basic
6. **Discretion scope:** 단일 화면 장식과 카피.

### Step 4.1: 원정 상태 모델
1. **Goal:** 시간·경기·위치·취소 신호를 하나의 JourneyPhase로 판정한다.
2. **Acceptance criteria:** 우선순위와 경계가 순수 테스트로 고정되고 결측은 idle로 저하한다.
3. **Boundary tests:** `flutter test test/features/home/journey_phase_test.dart` → 0.
4. **Registries to read:** 없음(feature-local).
5. **Verification tier:** basic
6. **Discretion scope:** private helper 구조.

### Step 4.2: 상태 반응형 홈
1. **Goal:** 기존 홈 정보를 보존하며 티켓·경로·도착·라이브·경기후·취소 얼굴을 적용한다.
2. **Acceptance criteria:** 여섯 상태가 같은 홈에서 바뀌고 취소 CTA/색이 팀색보다 우선하며 reduced motion에서 즉시 결과가 보인다.
3. **Boundary tests:** `flutter test test/features/home/home_screen_test.dart test/features/home/cycle3_journey_home_test.dart` → 0.
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`.
5. **Verification tier:** basic
6. **Discretion scope:** 한국어 세부 카피·아이콘·상태 장식 painter.

### Step 5.1: 전체 회귀 및 시각 seam
1. **Goal:** 사이클 3 변경을 전체 정적·동적 검사로 마감한다.
2. **Acceptance criteria:** 스플래시/로고는 변경되지 않고, 전체 앱·Firebase·content pipeline·hook 검사가 통과한다.
3. **Boundary tests:** `flutter analyze` → 0; `flutter test` → 0; `npm --prefix firebase test` → 0; `npm --prefix content-pipeline test` → 0; `node content-pipeline/common/validate.mjs` → 0; `git diff --check` → 0.
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`, `lib/backend/REGISTRY.md`.
5. **Verification tier:** fresh
6. **Discretion scope:** 테스트 fixture 정리.

## Run preview

| step | tier | touches |
|---|---|---|
| 1.1 | fresh | L DB schema |
| 1.2 | fresh | L global theme ownership |
| 1.3 | fresh | L shared component API |
| 2.1 | fresh | L optional-team profile journey |
| 3.1 | fresh | L root/nested navigation seam |
| 5.1 | fresh | cross-layer release gate |
