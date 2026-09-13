# 핸드오프 — 원정러 응원팀 컬러 기반 실시간 디자인

## 2026-09-13 다음 세션 재개 체크포인트

일반 개발 방식으로 계속한다. wellbegin/wellspec/wellplan/wellrun을 다시 시작하지
않는다. 승인된 명세와 계획은 참고 계약으로 유지하고, 실제 코드·검사 결과를 기준으로
남은 결함을 닫는다. HTML은 보존하고 원격 push는 사용자 지시 전까지 하지 않는다.

- 시작 HEAD: `494ca0e` (`fix(theme): isolate cached settings by account`).
- 브랜치 상태: `main`은 `origin/main` 대비 ahead 51, behind 2. 작업 트리가 많이
  변경되어 있으므로 pull/rebase/merge 전에 원격 2개 커밋의 내용과 충돌 범위를 먼저
  읽는다. 기존 변경을 stash/reset/checkout으로 치우지 않는다.
- 방금 완료: 계정별 테마 캐시 소유권, 스플래시 중 프로필 조기 조회, historical
  unknown-team 마이페이지 assertion 수정. 독립 probe 8/8과 관련 회귀 30/30 통과.
- 전체 검사: analyze 0 issues, Firebase 80/80, content 61/61, JSON 4종 validate,
  hooks 4종, diff-check 통과.
- 전체 Flutter 상태: 1074 pass, 1 skip, 3 fail. 실패를 완료로 처리하지 않는다.
- 다음 우선순위 1: `test/features/profile/cycle3_phase2_round3_independent_probe_test.dart`
  — A→B→A 전환 중 A의 오래된 테마 쓰기가 A의 최신 성공 쓰기 뒤에 완료되는 순서 문제.
- 다음 우선순위 2: `test/features/home/cycle3_phase4_fresh_integration_probe_test.dart`
  — 5시간 지난 방문 판정이 도착 상태를 계속 주장하는 문제.
- 다음 우선순위 3: `test/features/home/cycle3_phase4_round3_verifier_probe_test.dart`
  — legacy 폭의 독립 `PlaceCard` 전화번호 overflow.
- 위 셋을 각각 재현·수정·관련 검사한 뒤 전체 `flutter test`를 다시 실행한다.
- 이후 Android SDK 37/compileSdk 36 불일치를 해결하고 릴리스 빌드를 실제 검증한다.
- 미커밋 변경과 untracked verifier probe는 이전 세션에서 보존한 작업이다. 출처와
  필요성을 확인해 논리 단위로 정리하며, 무더기 삭제나 무관한 커밋을 하지 않는다.
- `visualizations/`의 HTML은 디자인 기준 자료이므로 삭제·재생성·포맷하지 않는다.

## 2026-09-13 wellrun 종료 및 일반 개발 전환

사용자 지시에 따라 cycle 3 wellrun은 전체 fresh review round 2 REJECT 지점에서
중단한다. 승인된 `.wellbegun/begin.md`, `.wellbegun/spec.md`, `.wellbegun/plan.md`와
`visualizations/`의 HTML은 그대로 유지한다. 이후 구현·검증·미커밋 변경 정리는
일반 개발 방식으로 진행하며, 실행하지 않았거나 실패한 검증은 완료로 기록하지 않는다.
원격 push는 계속 보류한다.

- 완료된 범위: Steps 1.1–5.1과 Phase 1–4 통합 검증.
- 마지막 완료 수정: whole-run round 1의 세 결함을 고친 `1f7b339`.
- 전환 기준선: `4af4da1` (`chore(wellrun): record whole-run round 2 rejection`).
- 전환 시 재현: `flutter test test/cycle3_whole_run_r2_independent_probe_test.dart`
  결과 3 pass, 4 fail.
- 미해결 1: A 계정의 늦은 캐시 쓰기 완료가 현재 B 계정 상태로 유입된다.
- 미해결 2: B 계정 캐시 read 대기 중 Riverpod의 이전 A 값을 현재 값처럼 사용한다.
- 미해결 3: 스플래시 동안 프로필 의존 테마가 프로필 서버 확인 유예를 먼저 소비한다.
- 미해결 4: 과거 unknown team 프로필이 `ProfileTabScreen`의 엄격한
  `TeamThemeScope.forTeam` 경로에서 assertion을 낸다.
- 기존 deferred: legacy stamp-before-profile-patch 규칙 실패 가능성, 계정 전환 뒤
  오래된 테마 쓰기 순서 문제, Android SDK 37/compileSdk 36 릴리스 게이트.
- 다음 작업: 위 네 결함 수정 → 관련 probe·회귀 검사 → 기존 미커밋 변경의 출처와
  필요성을 구분해 정리 → 실제 통과한 결과만 이 핸드오프에 갱신.

### 일반 개발 전환 후 결과

전환 당시의 네 결함은 수정했다. 테마 캐시 상태가 UID를 함께 보존해 계정 전환 중
이전 값을 현재 계정 값으로 오인하지 않고, 늦은 캐시 쓰기도 현재 계정에만 반영한다.
스플래시에서는 계정 귀속 기기 캐시만 미리 읽고 서버 프로필은 구독하지 않는다.
마이페이지는 전역 테마를 다시 팀 스코프로 감싸지 않아 historical unknown team도
중립 테마로 계속 사용할 수 있다.

- whole-run round 2 독립 probe: 8 pass.
- 관련 테마·스플래시·마이페이지 회귀: 30 pass.
- 전체 `flutter analyze`: 0 issues.
- 전체 `flutter test`: 1074 pass, 1 skip, 3 fail. 세 실패는 전환 전 선언된
  probe 예외와 동일하며 새 회귀는 아니다.
- Firebase 규칙: 80 pass.
- content pipeline: 61 pass; JSON 문서 4종 validate pass.
- enforcement hook 4종과 `git diff --check`: pass.
- 아직 실패하는 probe: 오래된 방문 판정이 5시간 뒤에도 도착 상태를 주장하는 경우,
  legacy 폭의 독립 `PlaceCard` 전화번호 overflow, 계정 A→B→A 전환 중 A의 오래된
  테마 쓰기가 최신 성공 쓰기 뒤에 완료되는 경우.
- Android SDK 37/compileSdk 36 릴리스 빌드 게이트는 실행하지 않았고 완료로 처리하지 않는다.
- HTML은 변경하지 않았고 push도 수행하지 않았다.

## 2026-09-12 cycle 3 wellrun 현재 체크포인트

이 문서의 아래 초기 디자인 핸드오프는 이력으로 보존한다. 현재 실행 상태의
원본은 `.wellbegun/run.md`이며, 승인된 `begin.md`/`spec.md`/`plan.md`에서 계속한다.
wellbegin·wellspec·wellplan을 다시 시작하지 않는다.

- 모드: `companion`; L/XL 추가 결정에서만 멈춘다.
- 완료: Steps 1.1–2.2, Phase 1 통합 검증, Step 2.1 fresh 검증.
- 현재: Phase 2 통합 fresh round 2 REJECT 후 60% drain-mode 체크포인트.
  round 1의 오래된 B 응답 seam은 revision-gated pending 설정으로 `eb10743`에서 수정했다.
  round 2는 느린 LG 선택 쓰기 중 B 설정 스냅샷이 아직 null인 팀을 되비춰 낙관적 LG를
  잠시 지우는 seam을 `cycle3_phase2_fresh_journey_probe_test.dart`가 재현했다.
- 다음: Step 2.1 소유 fix — 관련 없는 profile snapshot이 진행 중인 최신 팀 선택을
  덮지 않게 한다 → 두 Phase 2 probe와 전체 Flutter regression → **round 3 final fresh verifier**.
  round cap 때문에 round 3 REJECT면 wellrun 정책의 사용자 선택으로 멈춰야 한다.
- 계속 순서: Phase 2 통합 → 3.1 → 3.2 → Phase 3 통합 →
  4.1 → 4.2 → Phase 4 통합 → 5.1 → 전체 fresh-eyes.
- 커밋 정책: 기존 사용자 변경은 보존하고 각 step 소유 hunk만 단계 커밋한다. 현재
  cycle 3 커밋은 `2cad5f4`, `4c094bb`, `e8e5d5f`, `665029b`, `e2ed8c3`,
  `ccd7162`, `901e314`, `85e19f5`, `47f74f5`, `0f17206`, `eb10743` 순서다.
- 검증 정책: S/M step은 lint·boundary basic만, fresh verifier는 L/XL step·phase
  integration·whole-run review에만 붙인다. Step 1.5는 basic으로 plan/run 수정 완료.
- Step 1.5 사용자 결정은 `.wellbegun/decisions.md`에 기록했고 pending 파일은 제거했다.
- Step 1.5 round 1에서 실제 legacy 문서의 `profileThemeKey`가 현재 규칙에 거부되는
  결함을 잡았다. 현재는 닉네임/응원팀 transaction이 없는 A/auto를 채우고
  구 필드를 원자적으로 제거한다. fake/Firestore 행렬과 10칸 board 보존 probe가 통과했다.
- 최근 지휘자 회귀: `flutter test` 980 pass(1 skip), `npm --prefix firebase test` 80 pass.
  Step 2.2 통합 전 Timer 누수와 pre-splash 프로필 timeout 소진은 각각
  `47f74f5`, `0f17206`에서 수정했다.
- Phase 1 통합: targeted Flutter 48 pass, Firebase 전체 pass, `flutter analyze lib/design` pass,
  `scripts/hooks/pre-commit` pass.
- 추적해야 할 Deferred: legacy 프로필이 닉네임/팀 patch 전에 도장을 먼저 쓰면
  `writeStamp` batch가 구 `profileThemeKey`와 누락된 A/auto 때문에 규칙에 거부될 수 있다.
  Step 1.5의 사용자 확정 범위 밖 M 발견으로 `run.md` Deferred에 남겼다.
- 최종 릴리스 게이트 전 Android SDK 37/compileSdk 36 불일치를 해결해야 한다.
  현재 SDK에 `android-37.0`은 설치되어 있지만 Flutter 기본 compileSdk는 36이다.
- 현재 작업 트리의 모든 미커밋 변경, `.wellbegun/cycles/02/`, `visualizations/`,
  기존 `home_screen.dart`/테스트 변경, verifier probe를 사용자 작업으로 계속 보존한다.
- 구현 기준: `visualizations/away-live-journey-preview.html`,
  `visualizations/favorite-team-theme.html`; 스플래시·로고는 건드리지 않는다.

작성: 2026-09-12 / 다음 할 일: **사이클 3 디자인 계약 확정 후 Flutter 전면 적용**

## 다음 세션 시작 문구

```text
kbo-away-fans 사이클 3 디자인 작업을 이어서 진행한다. .wellbegun/HANDOFF.md 와
.wellbegun/begin.md 를 먼저 읽고, visualizations/away-live-journey-preview.html 과
visualizations/favorite-team-theme.html 을 기준으로 앱 본체를 전면 수정한다. 스플래시와
로고는 제외한다. begin의 남은 질문을 닫고 wellspec → wellplan → wellrun으로 이어간다.
```

## 2026-09-12 컬러 방향 확정

이번 세션에서 다음 방향을 선택했다.

- **스플래시 화면과 로고의 현재 색은 판단 대상에서 제외한다.** 둘 다 목업 이미지이며,
  앱 본체의 컬러 시스템을 확정한 뒤 별도로 다시 만든다.
- 기존의 따뜻한 오프화이트/종이색 중심 방향은 사용하지 않는다. 게임·엔터테인먼트
  느낌과 상태 애니메이션의 가시성을 위해 앱 본체는 쿨톤 기반으로 수정한다.
- 하나의 고정 브랜드 키컬러를 모든 사용자에게 쓰기보다, **사용자가 선택한 응원팀이
  앱 테마를 결정**하도록 한다.
- 팀 컬러 원본은 `lib/design/team_themes.dart`의 `TeamThemes` 10종을 사용한다.
- 화면 전체를 팀 대표색으로 채우지는 않는다. 공통 쿨톤 배경·표면·본문색 위에서
  대표색과 보조색이 티켓, CTA, 선택 상태, 경로, 스탬프, 라이브 신호에 반영된다.
- 우천 취소·경고·성공 같은 시맨틱 색은 팀 색보다 의미가 우선이며 팀 테마와 분리한다.
- 상대팀/목적지 홈팀 색은 경기 정보의 보조 맥락에만 쓰고, 앱 전체 테마의 주체는
  사용자가 선택한 응원팀으로 둔다.

### 팀 없음 사용자와 기본 테마 계열

- **응원팀 선택은 필수가 아니다.** `팀 없음`은 미완료 온보딩이 아니라 정상 프로필
  상태이며 앱 전체를 사용할 수 있다.
- 팀 없음 사용자는 네 개의 개별 테마가 아니라 두 **계열** 중 하나를 고른다.
  - A 계열: `A1 · Lavender Play`(밝음) ↔ `A4 · Periwinkle Night`(어두움)
  - B 계열: `B1 · Royal Fresh`(밝음) ↔ `B4 · Royal Night`(어두움)
- 밝음/어두움은 시간대에 따라 자동으로 바뀌고 설정에서 수동 제어할 수 있다.
- 나중에 응원팀을 선택하면 해당 팀 테마가 기본 계열보다 우선한다. 다시 팀 없음으로
  돌아오면 전에 선택한 A/B 계열을 복원한다.
- **중요 구현 제약:** 팀 테마와 팀 없음 기본 테마는 반드시 앱 전역의 단일 상태에서
  관리한다. 개별 화면이나 탭이 최종 테마를 따로 소유하면 안 된다. 하단 탭의 중첩
  Navigator, 바텀시트, 오버레이, 새 route까지 같은 테마를 받아야 한다.
- 우천 취소·경고·성공 같은 시맨틱 색은 어느 계열/팀 테마보다 의미가 우선한다.

### 경기 전 티켓의 확정 강도

현재 선택한 기준은 `visualizations/team-theme-preview.html`의 **약한 파생 글로우 티켓**이다.

- 티켓 본체는 팀 `primary`가 주인공이다.
- 오른쪽으로 갈수록 `secondary`를 약하게 섞는다.
- 현재 CSS 기준은 `primary → primary 70% + secondary 30%`의 절제된 그라데이션이다.
- 강한 방사형 발광, 선명한 사선 광택, 보조색까지 크게 갈라지는 그라데이션은
  시험했으나 과해서 되돌렸다.
- 다음 세션에서 **글로우를 다시 강하게 만들지 않는다.** 현재의 거의 단색처럼 보이는
  은근한 차이가 사용자가 선택한 기준이다.

## 이번 대화에서 도달한 핵심

브랜드 이름은 **`원정러`를 그대로 유지**한다. 여기서 원정은 야구 용어의 원정 경기만
뜻하지 않는다. 홈팀 경기를 홈구장에서 보더라도 사용자는 야구장으로 이동하고 경험을
쌓으므로, 제품 경험에서는 **“오늘의 야구장 원정”**으로 포괄한다.

디자인의 중심은 티켓·전광판·여권 중 하나를 화면에 텍스트로 선언하는 것이 아니다.
내부 디자인 원칙은 다음 한 문장이다.

> **야구장으로 향하는 사람의 현재 상태가 화면의 이미지·색·움직임에 반영된다.**

작업명은 `원정 라이브` 또는 `실시간 원정 여정`이다. 이 작업명은 앱 화면에 노출할
카피가 아니다.

## 확정에 가까운 디자인 방향

- 기본 바탕과 카드 표면은 팀과 무관한 공통 쿨톤 뉴트럴을 사용한다.
- 기본 전경은 쿨톤의 짙은 잉크색을 사용한다.
- 티켓·지도·전광판·스탬프의 **시각 문법**을 상태에 따라 사용하되, 화면에
  `티켓북`, `야간 전광판` 같은 콘셉트 설명 텍스트를 쓰지 않는다.
- 사용자가 선택한 응원팀 컬러는 화면 전체를 칠하지 않고 티켓, CTA, 경로, 선택 상태,
  스탬프, 작은 빛에 쓴다.
- 시간대 테마는 장식이 아니라 분위기 계층이다. 사용자가 끌 수 있다.
- 우천 취소·경기 상태·추천 내용 같은 기능 정보는 시간대 테마를 꺼도 유지한다.
- 애니메이션은 계속 도는 장식보다 출발·도착·발견·방문·취소 같은 사건에 대한
  반응과 보상으로 쓴다.

## 하나의 홈이 변하는 상태 흐름

```text
경기 전 티켓
  → 이동 중 지도 경로/출발 안내판
  → 구장 근처 조명/도착 신호
  → 경기 중 전광판/라이브 신호
  → 경기 후 식당 추천과 방문 스탬프

우천 취소 시:
경기 티켓에 취소 도장
  → 야구장 경로 중단
  → 실내 식당·카페 쪽으로 경로 재구성
  → 플랜B 추천이 오늘의 주 화면으로 올라옴
```

화면 상태를 정할 때 단순히 현재 시각만 보지 않는다.

1. 시간대
2. 경기 시작까지 남은 시간과 경기 상태
3. 사용자가 구장 근처인지
4. 날씨 및 우천 취소 여부

이 네 신호를 합쳐야 한다. 예를 들어 경기 없는 밤에는 전광판 테마를 강하게 켜지
않고 기본 기록 화면을 유지한다.

## 식당 추천 연결 방식

- 경기 며칠 전: 갈 곳을 미리 저장하는 카드.
- 이동 중: 이동 경로와 경기 시작 시간을 고려해 저장할 장소를 제시.
- 구장 근처: 지금 실제로 갈 수 있는 가까운 장소를 우선 표시.
- 경기 중: 경기 종료 예상 시각 이후 갈 곳을 미리 보여 줌.
- 경기 종료 후: 뒤풀이/늦게 갈 수 있는 장소 중심.
- 비 예보만 있을 때: 홈을 빼앗지 않고 실내 장소를 추천 순서에서 조금 올림.
- 우천 취소가 확정되면: 실내 식당·카페를 플랜B 주 경로로 전환.
- 영업 중, 대기 시간 같은 정보는 실제 데이터 출처가 있을 때만 표현한다.

`오늘 뭐 하지?` 스크래치 카드는 결정 피로를 줄이는 **선택형 랜덤 추천**이다. 필수
정보를 긁기 뒤에 숨기지 않는다. 접근성/모션 감소 환경에서는 탭 한 번으로 결과를
공개하는 대안이 필요하다.

## 사용자가 처음 제시한 원하는 연출

- 구장 스탬프 랠리: 방문 구장에 도장이 찍히는 애니메이션.
- 스크래치 카드 UI: 긁으면 랜덤 추천이 나오는 `오늘 뭐 하지?`.
- 구장별 테마 컬러 전환: 대전은 주황, NC는 민트처럼 목적지 색이 부드럽게 전환.
- 지도 위 경로 애니메이션: 원정 기록을 선으로 이어 이동 경로가 그려짐.
- 맛집 카드 스와이프: 원정 맛집 후보를 넘기고 저장.
- 날씨 연동 파티클: 비가 오면 빗방울이 나타나고 플랜B로 자연스럽게 유도.
- 시간대별 UI 변화 및 사용자 설정에서 해당 분위기 기능 끄기.

## 만들어 둔 디자인 미리보기

### 현재 컬러 기준 미리보기

- 독립 실행 파일: `visualizations/team-theme-preview.html`
- 같은 내용의 이전 파일명: `visualizations/favorite-team-theme-preview.html`
- 편집 원본 fragment: `visualizations/favorite-team-theme.html`
- 코드에 정의된 LG·두산·키움·SSG·KT·KIA·삼성·롯데·NC·한화 10개 팀의
  `primary / onPrimary / secondary / onSecondary` 값을 그대로 가져왔다.
- 왼쪽/상단의 팀 선택기로 응원팀을 바꿀 수 있다.
- `경기 전 / 이동 중 / 경기 중 / 우천 취소` 상태를 전환할 수 있다.
- 공통 쿨톤 UI와 팀에 따라 변하는 영역, 상태 의미가 우선하는 영역을 나눠 표현했다.
- 경기 전 티켓은 이 파일의 현재 약한 혼합 상태가 선택안이다.

### 기존 실시간 여정 미리보기

- 독립 실행 파일: `visualizations/away-live-journey-preview.html`
- 편집 원본 fragment: `visualizations/away-live-journey.html`
- 이 파일은 아직 이전의 따뜻한 오프화이트 기반이다. 상태 구조와 상호작용을 참고할
  원본이며, **다음 세션에서 컬러와 표면을 새 응원팀 테마 기준으로 수정할 대상**이다.
- 상단에서 `경기 전 / 이동 중 / 구장 근처 / 경기 중 / 우천 취소`를 전환한다.
- `시간대 분위기`를 끄면 상태와 정보는 유지하고 오프화이트 기본 테마로 돌아온다.
- 우측 상단 설정 버튼 안에도 같은 설정을 넣었다.
- 경기 전 화면 아래의 `오늘 뭐 하지?`는 마우스/포인터로 문질러 긁을 수 있다.
- 경기 전에는 티켓, 이동 중에는 경로, 구장 근처에는 조명, 경기 중에는 전광판,
  우천 취소에는 취소 도장과 실내 재경로를 이미지 중심으로 표현했다.

Chrome에서 다음 세 가지를 직접 확인했다.

1. 초기 `경기 전` 화면 렌더링
2. `우천 취소` 전환 시 빗방울·취소 티켓·플랜B 장소 표시
3. 우천 취소 상태에서 `시간대 분위기`를 끄면 정보는 남고 오프화이트로 복귀

### 이전 비교안

- `visualizations/away-fans-theme-preview.html`: 원정 기록지 / 입장권 컬렉션 /
  야간 전광판 3개 방향 비교본.
- `visualizations/away-fans-theme-directions.html`: 위 비교본의 편집 원본 fragment.
- 세 안 중 하나를 그대로 채택하지 않고, 기록지의 따뜻한 기반과 티켓/전광판의
  상태 이미지를 합쳐 현재 주 미리보기로 발전시켰다.
- `visualizations/cool-palette-directions.html` 및 preview: 초기 쿨톤 3안 비교.
- `visualizations/neon-palette-combinations.html` 및 preview: 형광 연두/미드나이트 계열
  역할 조합 비교. 최종 선택하지 않았다.
- `visualizations/pastel-palette-combinations.html` 및 preview: 사용자가 제시한 피치–
  페리윙클, 허니듀–로열블루 팔레트 비교. 최종 고정 팔레트 대신 응원팀별 테마로
  방향을 전환했다.

## 앱 코드에 적용된 범위와 적용되지 않은 범위

**중요: 위 실시간 디자인 시스템은 아직 Flutter 앱에 구현하지 않았다.** HTML은 방향을
논의하기 위한 별도 미리보기다.

이번 세션에서 만든 응원팀 기반 컬러 시스템과 약한 글로우 티켓도 Flutter 코드에는
적용하지 않았다. 기존 코드 일부는 구장/경기의 홈팀 기준으로 `TeamThemeScope`를 고르는
동작과 테스트가 있으므로, 구현 단계에서는 **사용자 응원팀을 전역 테마 기준으로 바꾸는
영향 범위**를 먼저 찾아야 한다.

이번 대화 중 Flutter 앱에 적용된 것은 홈 헤더의 파란 팀 컬러 배경을 본문과 같은
`ColorTokens.background` 오프화이트로 바꾼 작은 변경뿐이다.

- `lib/features/home/home_screen.dart`
  - 홈 AppBar 배경과 surface tint를 `ColorTokens.background`로 통일.
  - 제목/액션을 `ColorTokens.textPrimary`로 변경.
  - 스크롤 시 `scrolledUnderElevation: 0`으로 색 변화를 막음.
- `test/features/home/home_screen_test.dart`
  - 홈 헤더가 오프화이트와 어두운 전경을 쓰는 테스트 추가.

당시 검증 결과:

- `flutter test test/features/home/home_screen_test.dart` — 37개 통과
- `flutter analyze lib/features/home/home_screen.dart test/features/home/home_screen_test.dart`
  — 지적 사항 없음
- `git diff --check` — 통과

## 현재 작업 트리 주의

이번 핸드오프 작성 직전 기준으로 사용자/이번 대화의 미커밋 변경이 있다.

- 수정: `lib/features/home/home_screen.dart`
- 수정: `test/features/home/home_screen_test.dart`
- 수정: `.wellbegun/HANDOFF.md` (현재 문서)
- 추적되지 않음: `visualizations/` 아래 디자인 미리보기 파일들

다음 세션은 이 변경을 사용자 작업으로 취급하고 보존한다. 디자인 결정을 굳히기 전에
대규모 Flutter 수정이나 정리를 시작하지 않는다.

## 다음 세션에서 먼저 결정할 것

1. `team-theme-preview.html`의 컬러 역할과 약한 글로우 티켓을 기준으로 삼는다.
2. `away-live-journey-preview.html`의 다섯 상태 구조에 새 컬러 시스템을 적용한다.
3. 공통 쿨톤 뉴트럴의 최종 색을 정한다. 현재 팀 테마 시안의 값은 아직 목업값이다.
4. 팀색 적용 면적을 상태별로 다듬는다.
   - 경기 전: 티켓과 CTA
   - 이동 중: 경로와 진행 신호
   - 구장 근처: 도착 조명과 스탬프
   - 경기 중: 라이브 신호와 전광판 강조
   - 우천 취소: 팀색을 낮추고 취소/플랜B 의미를 우선
5. 홈에 항상 남는 공통 골격과 상태마다 바뀌는 영역을 분리한다.
6. 시간대 변화, 경기 상태, 사용자 위치, 우천 상태의 우선순위를 유지한다.
7. 모션 감소, 배터리, 접근성, 테마 끄기 동작을 명세한다.
8. 디자인이 승인된 뒤에만 Flutter provider/화면과 매핑해 구현 단계를 나눈다.

## 다음 디자인 라운드에서 특히 볼 질문

- `원정러` 워드마크를 텍스트로 얼마나 강조할 것인가?
- 티켓의 물성을 지금처럼 큰 히어로로 둘지 더 절제할 것인가?
- 경기 중 전광판이 정보 앱처럼 과해지지 않는가?
- 식당 카드가 원정 흐름에 자연스럽게 붙어 보이는가?
- 우천 취소 전환이 즐거운 연출로 보이지 않고 상황을 명확히 전달하는가?
- 시간대 테마를 껐을 때도 제품 정체성이 충분히 남는가?
- 비슷한 대표색을 가진 팀들(LG·SSG·KIA 등)이 보조색과 시각 문법으로 충분히
  구분되는가?
- 팀색이 강한 화면에서도 우천 취소·경고 등 시맨틱 정보가 즉시 읽히는가?
