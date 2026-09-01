---
status: approved
cycle: 2
---

# kbo-away-fans — plan (사이클 2)

<!--
  델타 계획. phase 1 은 **확장 로스터가 더하는 것만** 실물로 만든다
  (기존에 살아 있는 기반을 다시 쓰는 것은 spec 의 결정 사항이지 계획 단계가 아니다).
  입력: `.wellbegun/spec.md` (승인됨), `.wellbegun/begin.md`, `.wellbegun/decisions.md`
-->

## Phases
| phase | delivers | steps |
|---|---|---|
| 1 | 델타 기반 + 강제 장치 (계약 v2·토큰·Firestore·백엔드 계층·공유 컴포넌트·훅 3종) | 1.1–1.9 |
| 2 | 계정: 로그인 게이트에서 사용자 문서까지 | 2.1–2.5 |
| 3 | 5탭 골격과 좋아요 여정 | 3.1–3.4 |
| 4 | 배지: 방문 판정 → 도장 → 판 → 연출 → 못 받는 날 | 4.1–4.5 |
| 5 | 홈 개인화 마무리 (최근 5경기·현재 위치) | 5.1–5.2 |

**Verification tier 를 매긴 기준.** 규칙대로 "그 단계가 건드리는 결정 중 가장 되돌리기
어려운 등급"을 따르되, L/XL 결정을 **처음 실물로 굳히는** 단계에 `fresh` 를 주고,
이미 굳은 계약을 **소비하기만 하는** 단계는 `basic` 으로 둔다. 그렇게 하지 않으면
사이클 2의 거의 모든 단계가 XL(계정·데이터 소유권) 아래에 들어가 등급이 뜻을 잃는다.

## Step contracts

### Step 1.1: schedule 계약 schemaVersion 2 + 앱 파서 확장
1. **Goal:** schedule.json 계약에 종료 경기 상태와 점수·승패 필드를 더해 `schemaVersion` 을 2로 올리고, 파이프라인 검증과 앱 파서가 같은 계약을 함께 따르게 한다. (크롤 창 확장은 1.2)
2. **Acceptance criteria:** 스키마의 `schemaVersion` const 가 2이고 종료된 경기가 홈·원정 점수와 승패 결과를 담는다. schemaVersion 1 문서는 검증이 거부한다. 종료 상태인데 점수가 없는 문서도 검증이 거부한다. 앱 파서가 새 필드를 읽고, 점수가 없는 예정 경기도 그대로 읽는다. 크롤러가 산출하는 문서의 schemaVersion 이 2다. `data/schedule.json` 이 새 계약으로 검증을 통과한다.
3. **Boundary tests:**
   - `node content-pipeline/common/validate.mjs` → exit 0
   - `node content-pipeline/common/validate.mjs content-pipeline/test/fixtures/schedule.schema-version-1.json` → exit 1 (신설 픽스처)
   - `node content-pipeline/common/validate.mjs content-pipeline/test/fixtures/schedule.finished-missing-score.json` → exit 1 (신설 픽스처)
   - `npm --prefix content-pipeline test` → exit 0
   - `flutter test test/content/content_loader_test.dart` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** spec.md 의 DB schema 절(JSON 계약 변경분), `content-pipeline/REGISTRY.md`, `content-pipeline/CLAUDE.md`
5. **Verification tier:** fresh
6. **Discretion scope:** 새 필드의 이름과 표현, 종료 상태 값의 이름, 승패를 별도 필드로 둘지 점수에서 파생할지(무승부가 있으므로 파생만으로는 부족한지 판단 포함).

### Step 1.2: 크롤 창 과거 확장 + 경기 결과 산출
1. **Goal:** 크롤 창을 과거 구간까지 넓히고 네이버 응답의 점수·승자를 1.1 의 계약 필드로 옮겨, 최근 경기 결과가 산출물에 남게 한다.
2. **Acceptance criteria:** 크롤 창이 과거 구간을 포함하고 종료된 경기가 점수·승패와 함께 산출물에 남는다. 미래 경기는 종전대로 점수 없이 예정 상태다. 산출물 교체는 기존 보호 패턴 그대로 validate 통과 시에만 일어난다. 과거 경기가 섞여도 다음 원정 D-day 계산과 오늘 취소 감지가 이전과 같은 결과를 낸다.
3. **Boundary tests:**
   - `npm --prefix content-pipeline test` → exit 0 (과거·종료 경기가 든 신규 크롤 픽스처의 변환 결과를 단언하는 케이스 포함)
   - `node content-pipeline/common/validate.mjs` → exit 0
   - `flutter test test/features/home/next_away_game_test.dart test/features/home/stadium_browse_test.dart` → exit 0 (과거 경기가 섞인 픽스처 케이스 추가)
   - `flutter analyze` → exit 0
4. **Registries to read:** `content-pipeline/REGISTRY.md`, spec.md 의 DB schema 절
5. **Verification tier:** fresh
6. **Discretion scope:** 과거 창의 길이(일 수)와 조정 플래그 형태, 네이버 응답 필드 매핑 세부, 고빈도 cron 에서 과거 구간을 매번 다시 긁을지.

### Step 1.3: 디자인 토큰 확장 — `text.*` / `badge.*` / `badgeTier.*` / `motion.stamp`
1. **Goal:** `lib/design/tokens.dart` 에 이름 있는 타이포 조합, 배지 판 수치, 등급 표현, 도장 연출 모션 네 그룹을 더한다.
2. **Acceptance criteria:** 네 그룹이 이름 있는 상수로 존재한다. `text.*` 는 폰트·크기·굵기·색을 묶은 완성된 스타일을 돌려주고 그 값이 기존 낱개 토큰에서 온다. 등급 3단계 각각에 대응하는 값이 있고 팀 색 위에 얹히는 방식이다. `motion.stamp` 가 지속·커브를 함께 담는다. 토큰 파일 밖에 새 raw 리터럴이 생기지 않는다.
3. **Boundary tests:**
   - `flutter test test/design/tokens_test.dart` → exit 0 (네 그룹 존재, 등급 3단계, 조합 스타일이 `TypeTokens`·`ColorTokens` 값을 그대로 쓰는지 단언)
   - `bash scripts/hooks/check-hardcoded-values.sh` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** spec.md 의 Design tokens 절, `lib/design/tokens.dart` 기존 그룹
5. **Verification tier:** fresh
6. **Discretion scope:** 조합 스타일의 항목 이름과 개수, 등급 이름, 구체 수치의 초기값.

### Step 1.4: 타이포 조합 스타일 기존 38곳 일괄 교체
1. **Goal:** 13개 파일에 흩어진 네 줄짜리 `TextStyle` 손조합을 1.3 의 조합 스타일로 전부 바꾼다 — 두 방식이 공존하지 않게 하는 것이 목적이다.
2. **Acceptance criteria:** `lib/design/` 밖에 낱개 토큰을 손으로 조합한 `TextStyle` 이 남지 않는다. 기존 위젯 테스트가 렌더 결과 변화 없이 그대로 통과한다.
3. **Boundary tests:**
   - `grep -rn -B2 "fontFamily: TypeTokens.fontFamily" lib --include='*.dart' | grep -v '^lib/design/' | grep -c 'TextStyle('` → 0 (손조합 `TextStyle` 이 남지 않음)
     <!-- wellrun 이 1.3 검증에서 교정: 원래 문구는 `lib/app.dart` 의 `ThemeData(fontFamily: …)` 까지 잡아 37곳을 전부 바꿔도 통과할 수 없었다. 그 자리는 TextStyle 을 받지 않아 어떤 조합 스타일로도 대체 불가이고, 폰트를 번들할 때 필요한 줄이라 지울 수도 없다. acceptance("낱개 토큰을 손으로 조합한 TextStyle 이 남지 않는다")는 그대로 두고 검사 명령만 그 의도에 맞게 좁혔다. 2026-09-01 -->
   - `flutter test test/design/tokens_test.dart` → exit 0 (조합 스타일이 실제 사용처를 덮는지 함께 확인)
   - `flutter test` → exit 0
   - `bash scripts/hooks/check-hardcoded-values.sh` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** spec.md 의 Design tokens 절, `lib/ui/shared/REGISTRY.md`, `lib/ui/shared/CLAUDE.md`
5. **Verification tier:** basic
6. **Discretion scope:** 조합이 딱 맞지 않는 소수 지점의 처리 방식(가장 가까운 조합 + `copyWith` 인지 조합을 하나 더 만드는지).

### Step 1.5: Firestore 데이터 모델과 보안 규칙
1. **Goal:** 사용자·도장·좋아요 세 컬렉션의 경로와 필드, "본인만 읽고 쓴다" 보안 규칙, 인덱스 구성을 실물 파일로 만든다.
2. **Acceptance criteria:** 보안 규칙이 세 경로 모두에서 본인 문서만 읽고 쓰게 하고 남의 문서와 미인증 접근을 거부한다. 도장 문서의 id 가 `{stadiumId}_{gameId}` 한 형태로만 만들어지도록 규칙 또는 계약 문서가 못박는다. 위도·경도로 읽히는 필드가 어느 컬렉션 계약에도 없다. 사용자 문서의 칸별 요약(구장별 개수·등급) 필드가 계약에 정의되어 있다.
3. **Boundary tests:**
   - `npm --prefix firebase test` → exit 0 (Firestore 에뮬레이터 위의 규칙 단위 테스트 4종: 본인 문서 읽기 허용 / 남의 문서 읽기 거부 / 남의 도장 쓰기 거부 / 미인증 접근 거부)
   - `grep -rniE '(lat|lng|latitude|longitude|coord)' firestore.rules docs/firestore-schema.md` → 매치 없음 (grep exit 1)
4. **Registries to read:** spec.md 의 DB schema 절(Firestore), begin.md 의 데이터 소유권 결정
5. **Verification tier:** fresh
6. **Discretion scope:** 필드 이름과 인덱스 구성, 규칙 파일의 구조, 칸별 요약의 표현, 규칙 테스트 패키지의 위치와 구성, JDK 배포판과 설치 방법.

> **선행 조건 (이 단계가 스스로 처리한다):** Firestore 에뮬레이터는 Java 런타임을 요구하는데
> 이 머신에는 없다(`java -version` 실패). 이 단계는 JDK 와 `firebase-tools`·
> `@firebase/rules-unit-testing` 설치까지 포함하며, 설치 방법은 README 의 개발 절에 남긴다.
> 셋 다 무료이고 Firebase 요금과 무관하다. 규칙 테스트는 4.2 의 도장 쓰기에서 다시 쓰인다.

### Step 1.6: `lib/backend/` 공통 계층 골격 + 로스터·read-first 문서
1. **Goal:** 인증·사용자 데이터·오류 봉투의 타입 경계를 만들고 Firebase SDK import 를 이 폴더 안에 가두며, `REGISTRY.md` 와 `CLAUDE.md` 를 코드 옆에 둔다. (실제 로그인 흐름은 phase 2)
2. **Acceptance criteria:** `lib/backend/` 에 auth·user_data·errors 세 파일이 있고 타입 경계만으로 컴파일된다. Firebase 예외가 네트워크/권한/알 수 없음 세 도메인 오류로 변환된다. `firebase_*`·`cloud_firestore` import 가 `lib/backend/` 와 `lib/analytics/` 밖에 없다. 위도·경도 필드가 이 폴더의 어떤 업로드 경로에도 없다. `lib/backend/REGISTRY.md` 의 행과 폴더 파일이 일치하고 `lib/backend/CLAUDE.md` 가 "작업 전 로스터를 읽어라"를 명시한다.
3. **Boundary tests:**
   - `flutter test test/backend/` → exit 0 (오류 봉투 변환 단위 테스트, 가짜 백엔드로 사용자 데이터 접근 계약 단언)
   - `grep -rnE "package:(firebase_|cloud_firestore)" lib --include='*.dart' | grep -vE '^lib/(backend|analytics)/'` → 매치 없음 (grep exit 1)
   - `bash scripts/hooks/check-hardcoded-values.sh` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** spec.md 의 Backend common layers 절, 1.5 가 만든 Firestore 계약 문서, `lib/ui/shared/REGISTRY.md`(경계 규칙의 선례)
5. **Verification tier:** fresh
6. **Discretion scope:** 타입 표현(sealed 클래스·결과 타입 등), provider 주입 형태, 파일 내부 분해, `cloud_firestore` 의존성 추가 방식.

### Step 1.7: 카카오 커스텀 토큰 Cloud Function
1. **Goal:** 카카오 액세스 토큰을 검증해 Firebase 커스텀 토큰을 발급하는 함수를 `functions/` 에 만든다. (배포와 앱 연동은 2.3)
2. **Acceptance criteria:** 유효한 카카오 토큰이면 카카오 사용자 id 에서 결정적으로 나오는 uid 로 커스텀 토큰을 발급한다. 카카오 검증이 실패하면 토큰을 발급하지 않고 오류를 돌려준다. 이메일 등 추가 동의 항목을 요구하지 않는다(uid·닉네임만). 카카오 API 호출이 함수 안 한 자리에서만 일어난다.
3. **Boundary tests:**
   - `npm --prefix functions test` → exit 0 (가짜 카카오 응답으로 성공 → 토큰 발급 1회 / 401 → 발급 0회 + 오류 / 결정적 uid 단언)
   - `grep -rn "account_email" functions --include='*.js' --include='*.ts' --include='*.mjs' | grep -v node_modules` → 매치 없음 (grep exit 1)
4. **Registries to read:** spec.md 의 Backend common layers 절, decisions.md 의 소셜 로그인 L 결정
5. **Verification tier:** fresh
6. **Discretion scope:** 런타임·언어와 내부 구조, 함수 이름과 호출 규약(callable / HTTPS), 테스트 러너 선택.

### Step 1.8: 공유 컴포넌트 7종 골격 + 로스터 갱신
1. **Goal:** spec 의 공유 컴포넌트 7종을 최소 props 로 렌더되는 골격으로 만들고 같은 커밋에서 `lib/ui/shared/REGISTRY.md` 에 행을 더한다.
2. **Acceptance criteria:** 7개 파일이 존재하고 각각 예외 없이 렌더된다. `StampBoard` 가 빈 칸을 포함해 10칸을 전부 렌더한다. `StampBadge` 가 빈 상태·획득·등급 세 모습을 가진다. 색·간격·타이포가 전부 토큰에서 온다. 로스터 행과 폴더 파일이 일치한다.
3. **Boundary tests:**
   - `flutter test test/ui/shared/` → exit 0 (7종 렌더 스모크 + `StampBoard` 10칸 단언 + `StampBadge` 세 모습 단언)
   - `bash scripts/hooks/check-registry-sync.sh` → exit 0
   - `bash scripts/hooks/check-hardcoded-values.sh` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** spec.md 의 Shared components·Design tokens 절, `lib/ui/shared/REGISTRY.md`, `lib/ui/shared/CLAUDE.md`
5. **Verification tier:** fresh
6. **Discretion scope:** 각 컴포넌트의 내부 분해와 골격 단계 props, 배지 판의 배치(격자/지도형), 탭 아이콘 선택, 로그인 버튼의 제공자별 표현.

### Step 1.9: 강제 장치 3종 설치와 wiring
1. **Goal:** `check-registry-sync.sh` 에 `lib/backend/` 짝을 더하고 `check-no-location-upload.sh` 와 `check-firebase-import-boundary.sh` 를 신설해 pre-commit·PostToolUse 에 건다.
2. **Acceptance criteria:** 깨끗한 트리에서 네 검사 전부 exit 0. `lib/backend/` 에 로스터 없는 파일을 두면 registry-sync 가 exit 2. `lib/backend/` 안 업로드 경로에 위도 필드를 두면 no-location-upload 가 exit 2. `lib/features/` 에 firestore import 를 두면 import-boundary 가 exit 2. 위반이 남아 있으면 커밋이 막힌다.
3. **Boundary tests:**
   - 깨끗한 트리에서 `bash scripts/hooks/check-hardcoded-values.sh` / `check-registry-sync.sh` / `check-no-location-upload.sh` / `check-firebase-import-boundary.sh` → 각각 exit 0
   - `lib/backend/` 에 로스터 없는 임시 파일 추가 → `check-registry-sync.sh` exit 2, 제거 후 exit 0
   - `lib/backend/` 에 위도 필드를 올리는 임시 코드 추가 → `check-no-location-upload.sh` exit 2, 제거 후 exit 0
   - `lib/features/` 에 `package:cloud_firestore` import 임시 추가 → `check-firebase-import-boundary.sh` exit 2, 제거 후 exit 0
   - 위반이 남은 상태에서 `git commit` → 비0 종료
4. **Registries to read:** spec.md 의 Enforcement plan 절, 기존 두 스크립트, `.claude/settings.json`
5. **Verification tier:** basic
6. **Discretion scope:** grep 패턴 세부와 예외 목록 관리 방식, PostToolUse 에 어느 검사를 걸지.

### Step 2.1: 로그인 게이트와 인증 상태
1. **Goal:** 앱의 첫 화면을 로그인으로 바꾸고(`RootGate` 확장) 인증 상태에 따라 로그인·온보딩·홈이 갈리게 하며, 기존 154개 테스트가 인증 상태를 주입하도록 옮긴다.
2. **Acceptance criteria:** 로그인하지 않은 실행은 로그인 화면에서 멈춘다 — 계정 없이 쓰는 경로가 없다. 로그인 상태면 기존 분기(팀 없음 → 온보딩, 있음 → 홈)가 그대로다. 로그아웃하면 로그인 화면으로 돌아온다. 기존 테스트가 전부 통과한다.
3. **Boundary tests:**
   - `flutter test` → exit 0 (기존 154개 + 게이트 3분기 신규 케이스)
   - `bash scripts/hooks/check-hardcoded-values.sh` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/backend/REGISTRY.md`, `lib/ui/shared/REGISTRY.md`, decisions.md 의 계정 모델 XL 결정
5. **Verification tier:** fresh
6. **Discretion scope:** 로그인 화면의 문구·레이아웃, 인증 상태를 테스트에 주입하는 방식, 스플래시와 게이트의 순서.

### Step 2.2: 구글·애플 로그인 실연결 + Firebase 프로젝트 설정
1. **Goal:** Firebase 프로젝트를 Blaze 로 전환하되 예산 알림과 상한을 먼저 걸고, 구글·애플 제공자를 켜서 실제 로그인이 되게 한다.
2. **Acceptance criteria:** 설정 파일이 없는 클론에서도 빌드·analyze·테스트가 통과한다(사이클 1의 no-op 패턴 유지). 설정이 있는 기기에서 구글 로그인으로 계정이 만들어진다. iOS 에서 애플 로그인이 동작한다. Firebase 콘솔에 예산 알림과 상한이 걸려 있다. **로그인해 둔 계정의 실기기 콜드 스타트에서 로그인 화면이 번쩍이지 않는다** (2.1 이월: `authStateProvider` 의 첫 값이 `AuthService.currentUser` 인데 Firebase Auth 는 영속 세션 복원 전까지 이 값이 null 이라 확정된 로그아웃으로 판정될 수 있다 — 번쩍이면 첫 값 정책을 여기서 고친다). **`signIn` 이 성공을 돌려준 직후 `currentUser` 가 실제로 채워지는지 확인한다** (2.1 이월: 로그인 화면의 잠금을 푸는 자리가 게이트뿐이라, 성공했는데 세션이 안 서면 앱 재시작 말고 나갈 길이 없다).
3. **Boundary tests:**
   - `flutter test` → exit 0 (설정 파일 없는 상태에서)
   - `grep -rnE "package:(firebase_|cloud_firestore)" lib --include='*.dart' | grep -vE '^lib/(backend|analytics)/'` → 매치 없음
   - `bash scripts/hooks/check-firebase-import-boundary.sh` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/backend/REGISTRY.md`, decisions.md 의 백엔드 XL·비용 M 결정
5. **Verification tier:** fresh
6. **Discretion scope:** 예산 상한 금액과 알림 임계, 제공자 설정 세부, 설정 파일을 저장소에 둘지 여부.

> 실기기 로그인 확인과 콘솔 설정은 사람이 눈으로 보는 acceptance 다. 명령으로 검증되는
> 몫은 "설정 없이도 기준선이 그대로"라는 것까지다.

### Step 2.3: 카카오 로그인
1. **Goal:** 1.7 의 함수를 배포하고 앱에서 카카오 로그인 → 커스텀 토큰 → Firebase 세션까지 잇는다.
2. **Acceptance criteria:** 카카오로 로그인하면 계정이 만들어지고, 다시 로그인해도 같은 계정에 붙는다. 함수 호출이 실패하면 로그인 화면이 이유를 안내하고 앱이 죽지 않는다. 카카오 SDK import 가 `lib/backend/` 밖에 없다. **App Check 가 켜져 있고 `kakaoCustomToken` 에 강제 적용된다** (2.2 이월 [L] 결정: 방어가 필요해지는 시점과 서는 시점을 맞춘다 — 클라이언트 wiring, 콘솔의 증명 제공자(Play Integrity / DeviceCheck·App Attest), 함수 쪽 강제, 그리고 개발 기기·시뮬레이터·에뮬레이터의 디버그 토큰 절차가 이 단계의 범위에 함께 들어온다).
3. **Boundary tests:**
   - `flutter test test/backend/` → exit 0 (커스텀 토큰 교환 경로를 가짜 구현으로 단언: 성공·실패 양쪽)
   - `grep -rn "package:kakao" lib --include='*.dart' | grep -v '^lib/backend/'` → 매치 없음 (grep exit 1)
   - `npm --prefix functions test` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/backend/REGISTRY.md`, spec.md 의 Backend common layers 절
5. **Verification tier:** fresh
6. **Discretion scope:** 카카오 SDK 패키지 선택, 오류 문구, 함수 배포 방식.

### Step 2.4: 사용자 문서와 선택 팀의 원본 이전
1. **Goal:** 로그인 직후 사용자 문서(닉네임·프로필 색·선택 팀·가입 시각·칸별 요약 초기값)를 만들고, 선택 팀의 원본을 Firestore 로 옮기며 `shared_preferences` 는 첫 렌더용 캐시로만 남긴다.
2. **Acceptance criteria:** 첫 로그인에 문서가 한 번 만들어지고 재로그인이 그것을 덮어쓰지 않는다. 팀을 바꾸면 Firestore 가 갱신되고 캐시도 따라간다. 첫 프레임은 캐시 값으로 팀 테마가 붙고 이후 서버 값으로 수렴한다. 기기를 바꿔 로그인해도 선택 팀이 따라온다. 프로필 색이 선택한 팀 색으로 전환된다.
3. **Boundary tests:**
   - `flutter test test/backend/ test/features/team_select/` → exit 0 (문서 최초 생성 1회, 재로그인 무변경, 캐시 → 서버 수렴, 서버 값과 캐시 불일치 시 서버 우선)
   - `flutter test` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/backend/REGISTRY.md`, 1.5 의 Firestore 계약 문서, spec.md 의 DB schema 절
5. **Verification tier:** fresh
6. **Discretion scope:** 기본 닉네임 생성 방식, 문서 필드 이름, 캐시 갱신 시점.

### Step 2.5: 온보딩 위치 권한 요청
1. **Goal:** 팀 선택 직후 용도(구장 도장·현재 위치 표시)를 설명하고 위치 권한을 요청하되, 거절해도 나머지가 그대로 동작하게 한다.
2. **Acceptance criteria:** 팀 선택을 마친 직후 설명과 권한 요청이 한 번 뜬다. 거절해도 홈·추천·좋아요가 그대로 동작한다. 이미 허용하거나 거절한 상태에서는 다시 묻지 않는다.
3. **Boundary tests:**
   - `flutter test test/features/` → exit 0 (권한 게이트를 주입한 위젯 테스트로 허용·거절·이미 결정됨 3분기)
   - `flutter test` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`, decisions.md 의 위치 권한 M 결정
5. **Verification tier:** basic
6. **Discretion scope:** 설명 화면의 문구와 형태, 위치 권한 플러그인 선택.

### Step 3.1: 하단 5탭 전환
1. **Goal:** 홈·배지·추천·좋아요·마이페이지 다섯 탭을 `MainTabScaffold` 로 세우고, 탭마다 독립 Navigator 스택을 유지한다.
2. **Acceptance criteria:** 다섯 탭이 보이고 각 탭이 자기 스택을 유지한다 — 탭 안에서 화면을 연 뒤 다른 탭에 갔다 돌아오면 그 화면이 그대로다. 홈 탭은 기존 홈 화면 그대로다. 뒤로 가기가 탭 스택을 먼저 소비한다.
3. **Boundary tests:**
   - `flutter test test/ui/shared/main_tab_scaffold_test.dart` → exit 0 (탭 전환 후 스택 보존, 뒤로 가기 우선순위)
   - `flutter test` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`, decisions.md 의 5탭 M 결정
5. **Verification tier:** basic
6. **Discretion scope:** 아이콘·라벨, 탭 전환 연출, 아직 비어 있는 탭의 자리 표시.

### Step 3.2: 좋아요 토글
1. **Goal:** 장소 카드와 상세 시트에 `LikeButton` 을 붙이고 Firestore 에 좋아요를 저장한다 — 낙관적 반영, 실패 시 되돌림.
2. **Acceptance criteria:** 누르면 즉시 반영되고 쓰기가 실패하면 원래대로 돌아온다. 같은 장소를 여러 번 눌러도 문서가 하나다. 오프라인에서 누른 것이 복구 후 반영된다. 좋아요는 시점과 무관하게 아무 때나 눌린다(경기와 묶이지 않는다).
3. **Boundary tests:**
   - `flutter test test/ui/shared/like_button_test.dart test/backend/` → exit 0 (낙관적 반영·실패 롤백·중복 눌림 멱등)
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`, `lib/backend/REGISTRY.md`
5. **Verification tier:** basic
6. **Discretion scope:** 좋아요 문서 필드, 버튼 연출, 실패 안내 방식.

### Step 3.3: 좋아요 내역 탭
1. **Goal:** 추천과 같은 카테고리 체계로 내가 누른 항목만 보여 주는 탭을 만든다.
2. **Acceptance criteria:** 내가 누른 항목만 보이고 카테고리 묶음이 추천과 같다. 항목을 탭하면 기존 장소 상세 시트로 이어진다. 하나도 없으면 빈 상태가 뜬다. 목록에서 좋아요를 풀면 즉시 사라진다.
3. **Boundary tests:**
   - `flutter test test/features/likes/` → exit 0 (빈 상태, 카테고리 묶음, 해제 시 즉시 제거)
   - `flutter test` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`(`kCategoryLabels` 포함), `lib/backend/REGISTRY.md`
5. **Verification tier:** basic
6. **Discretion scope:** 목록 정렬과 카테고리를 묶는 방식, 빈 상태 문구.

### Step 3.4: 마이페이지 탭
1. **Goal:** 닉네임·프로필 색·대표 이메일을 보여 주고 닉네임과 프로필 색을 바꿀 수 있게 하며 로그아웃 경로를 둔다.
2. **Acceptance criteria:** 세 정보가 보이고 닉네임·프로필 색 변경이 Firestore 에 반영된다. 이메일을 주지 않는 제공자(카카오)로 로그인한 사람에게는 그 자리가 빈칸으로 남지 않고 제공자 표시로 대신한다. 로그아웃하면 로그인 화면으로 돌아간다. 로그인 기기 관리는 없다(non-goal).
3. **Boundary tests:**
   - `flutter test test/features/profile/` → exit 0 (이메일 있는 계정·없는 계정 두 경우, 닉네임 변경 반영, 로그아웃 전이)
   - `flutter test` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/backend/REGISTRY.md`, spec.md 의 DB schema 절
5. **Verification tier:** basic
6. **Discretion scope:** 프로필 색 선택 방식, 닉네임 규칙, 화면 레이아웃.

### Step 4.1: 구장 방문 판정
1. **Goal:** 경기일·구장 반경·시간 창 세 조건을 순수 함수로 만들고, 앱이 열려 있을 때 위치를 한 번 받아 판정에 넣는다.
2. **Acceptance criteria:** 세 조건이 모두 맞을 때만 방문으로 판정된다. 위치 권한이 없으면 판정을 시도하지 않고 이유가 남는다. 판정에 쓰인 좌표는 어디에도 저장되지 않고 서버로 가지 않는다. 홈·원정을 구분하지 않는다 — 그 구장에 있었는지만 본다.
3. **Boundary tests:**
   - `flutter test test/features/badges/visit_check_test.dart` → exit 0 (반경 안/밖, 시간 창 안/밖, 그날 경기 없음, 권한 없음 — 다섯 갈래)
   - `bash scripts/hooks/check-no-location-upload.sh` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/backend/REGISTRY.md`, decisions.md 의 방문 확인 L 결정, begin.md 의 데이터 소유권 결정
5. **Verification tier:** fresh
6. **Discretion scope:** 반경·시간 창의 구체 수치(초기값을 잡고 실측으로 조정), 위치 플러그인 선택, 판정을 트리거하는 시점.

### Step 4.2: 도장 쓰기와 칸별 요약 갱신
1. **Goal:** 판정이 성공하면 `{stadiumId}_{gameId}` 문서를 쓰고 같은 트랜잭션으로 사용자 문서의 칸별 요약(개수·등급)을 갱신한다.
2. **Acceptance criteria:** 같은 경기에서 여러 번 판정해도 도장 문서가 하나다. 요약의 개수·등급이 실제 도장과 어긋나지 않는다. 오프라인에서 찍은 도장이 복구 후 한 번만 올라간다. 잠실은 그날 홈팀 칸에 찍힌다. 도장에 좌표가 담기지 않는다.
3. **Boundary tests:**
   - `flutter test test/backend/stamp_write_test.dart` → exit 0 (중복 쓰기 멱등, 요약과 도장의 일치, 잠실 홈팀 분기, 오프라인 큐 재전송)
   - `npm --prefix firebase test` → exit 0 (규칙: 남의 도장 쓰기 거부 케이스 포함)
   - `bash scripts/hooks/check-no-location-upload.sh` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** 1.5 의 Firestore 계약 문서, `lib/backend/REGISTRY.md`, decisions.md 의 도장 id·요약 L 결정
5. **Verification tier:** fresh
6. **Discretion scope:** 배지 등급이 갈리는 임계 개수와 등급 이름, 요약 필드 표현, 트랜잭션 재시도 정책.

### Step 4.3: 배지 판과 칸 상세
1. **Goal:** 사용자 문서의 칸별 요약만 읽어 10칸 판을 그리고, 개별 도장은 칸을 열 때만 읽는다.
2. **Acceptance criteria:** 판을 여는 동안 읽는 문서가 사용자 문서 하나다 — 도장 개수와 무관하다. 빈 칸까지 10칸이 전부 보인다(잠실은 두 칸). 칸을 열면 그 칸의 도장이 날짜와 함께 전부 보인다. 판에는 칸별 최고 등급이 보인다.
3. **Boundary tests:**
   - `flutter test test/features/badges/` → exit 0 (가짜 백엔드의 읽기 호출 수를 세어 판 렌더가 사용자 문서 1건만 읽는지 단언, 도장 0개·다수 두 경우에서 동일)
   - `flutter test test/ui/shared/` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`, `lib/backend/REGISTRY.md`, decisions.md 의 판 읽기 패턴 L 결정
5. **Verification tier:** fresh
6. **Discretion scope:** 판의 배치와 칸 상세 화면의 레이아웃, 정렬 순서.

### Step 4.4: 도장 획득 연출과 등급 상승
1. **Goal:** 도장이 찍히는 순간을 `motion.stamp` 로 연출하고, 등급이 오르는 순간을 이어 붙인다 — 이 사이클의 대표 연출이다.
2. **Acceptance criteria:** 도장이 찍히는 순간 연출이 재생된다. 등급이 오르는 도장이면 등급 상승이 이어서 보인다. 연출을 건너뛰거나 중간에 화면을 벗어나도 데이터는 이미 확정되어 있다. 연출 수치가 전부 토큰에서 온다.
3. **Boundary tests:**
   - `flutter test test/features/badges/stamp_reveal_test.dart` → exit 0 (연출 재생, 등급 상승 분기, 연출 중단 시 데이터 유지)
   - `bash scripts/hooks/check-hardcoded-values.sh` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** spec.md 의 Design tokens 절, `lib/ui/shared/REGISTRY.md`
5. **Verification tier:** basic
6. **Discretion scope:** 연출의 구체적 표현, 등급 상승 화면의 형태.

### Step 4.5: 도장을 못 받는 날의 안내
1. **Goal:** 위치 권한 거부와 판정 실패 각각에 대해 배지 탭이 이유를 안내하고 권한 설정으로 이어 준다.
2. **Acceptance criteria:** 권한을 거부한 사람에게 왜 도장이 안 찍히는지가 배지 탭에 뜨고 설정으로 가는 경로가 있다. 판정 실패(권한은 있으나 조건 불충족)는 다른 문구로 안내한다. 권한이 없어도 판은 열리고 빈 칸이 보인다. 추천·좋아요·홈은 권한과 무관하게 그대로 동작한다.
3. **Boundary tests:**
   - `flutter test test/features/badges/` → exit 0 (권한 거부·판정 실패 두 안내, 권한 없이도 판 렌더)
   - `flutter test` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`(`ContentFallback` 포함), begin.md 의 failure branch
5. **Verification tier:** basic
6. **Discretion scope:** 안내 문구와 배치, 설정으로 보내는 방식.

### Step 5.1: 홈 최근 5경기 결과 요약
1. **Goal:** 1.2 가 산출한 과거 경기를 홈 중단에서 내 팀의 최근 5경기 요약으로 보여 준다.
2. **Acceptance criteria:** 내 팀의 최근 경기가 점수·승패·구장·날짜와 함께 최대 5개 보인다. 경기가 5개보다 적으면 있는 만큼만 보인다. 하나도 없으면 빈 상태가 뜬다. 선발 투수·날씨 자리는 만들지 않는다(이번 사이클 범위 밖).
3. **Boundary tests:**
   - `flutter test test/features/home/recent_games_test.dart` → exit 0 (5개 초과·미만·0개, 홈/원정 양쪽 경기 포함, 무승부 표시)
   - `flutter test test/features/home/` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** spec.md 의 DB schema 절, `lib/ui/shared/REGISTRY.md`
5. **Verification tier:** basic
6. **Discretion scope:** 요약 카드의 레이아웃과 표기, 승패 표시 방식.

### Step 5.2: 홈 상단 현재 위치 표시
1. **Goal:** 위치 권한이 있으면 홈 상단에 현재 위치를 표시하고, 없으면 그 자리를 조용히 접는다.
2. **Acceptance criteria:** 권한이 있으면 현재 위치가 상단에 뜬다. 권한이 없으면 그 자리가 사라지거나 권한 안내로 바뀌고 홈의 나머지는 그대로다. 좌표가 저장되거나 서버로 가지 않는다.
3. **Boundary tests:**
   - `flutter test test/features/home/home_screen_test.dart` → exit 0 (권한 있음·없음 두 경우)
   - `bash scripts/hooks/check-no-location-upload.sh` → exit 0
   - `flutter test` → exit 0
   - `flutter analyze` → exit 0
4. **Registries to read:** `lib/ui/shared/REGISTRY.md`, begin.md 의 데이터 소유권 결정
5. **Verification tier:** basic
6. **Discretion scope:** 위치 표기 형태(구·동 단위인지 구장 근접 표시인지), 갱신 주기.

## Run preview
<!-- tier 가 fresh 이거나 L/XL 결정을 건드리는 단계 — wellrun 이 브리핑에서 "멈출 수 있는 자리"로 보여 준다 -->
| step | tier | touches |
|---|---|---|
| 1.1 | fresh | [L] schedule 계약 schemaVersion 2 — 계약 변경은 마이그레이션급 |
| 1.2 | fresh | [L] 최근 5경기 데이터 범위, [M] 크롤 창 |
| 1.3 | fresh | 디자인 토큰 로스터 확장 — 이후 전 화면이 여기에 의존 |
| 1.5 | fresh | [XL] 데이터 소유권(위치 미저장), [L] 도장 문서 id — 개인 데이터의 벽 |
| 1.6 | fresh | [XL] 백엔드 도입 형태, [L] 소셜 로그인 방식 — SDK 경계가 여기서 굳는다 |
| 1.7 | fresh | [L] 카카오 커스텀 토큰 |
| 1.8 | fresh | 공유 컴포넌트 로스터 7종 — [L] 배지 판 읽기 패턴의 소비 형태 포함 |
| 2.1 | fresh | [XL] 계정 모델 필수 — 기존 154개 테스트가 함께 움직인다 |
| 2.2 | fresh | [XL] 백엔드 도입 형태, [M] 비용 제약(Blaze 전환·예산 상한) |
| 2.3 | fresh | [L] 소셜 로그인 방식 (카카오 경로 완성) |
| 2.4 | fresh | [XL] 데이터 소유권, [M] 기기 저장값과 계정의 관계 |
| 4.1 | fresh | [L] 구장 방문 확인 방식 |
| 4.2 | fresh | [L] 도장 문서 id 멱등, [L] 요약 동시 갱신 |
| 4.3 | fresh | [L] 배지 판 읽기 패턴 — 무료 할당량이 걸린 자리 |
