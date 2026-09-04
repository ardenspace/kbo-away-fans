# kbo-away-fans

KBO 원정 팬을 위한 구장 주변 가이드 앱 (Flutter).

## 구조

- `lib/design/` — 디자인 토큰 (색·간격·타이포·모션). 토큰 파일 밖 raw 리터럴 금지.
- `lib/ui/shared/` — 공유 컴포넌트 (`REGISTRY.md` 로스터와 짝 유지).
- `lib/features/` — 화면·기능 단위 코드.
- `lib/backend/` — 사용자 데이터·인증 공통 계층. Firebase·카카오 SDK import 는 이 폴더
  (와 `lib/analytics/`) 안에만 두고, 화면·상태 계층은 여기가 내보내는 타입만 소비한다
  (`REGISTRY.md` 로스터와 짝 유지, 상세는 `lib/backend/CLAUDE.md`).
- `content-pipeline/` — 서버 없는 콘텐츠 파이프라인 (크롤링 → 검증 → 정적 JSON 배포).
- `firebase.json` / `firestore.rules` / `firestore.indexes.json` — Firestore 보안 규칙·
  인덱스·에뮬레이터 설정. 필드 계약은 `docs/firestore-schema.md`, 규칙 테스트는 `firebase/`.
- `functions/` — Cloud Functions (카카오 액세스 토큰 → Firebase 커스텀 토큰).
- `docs/` — 계약·제안 문서 (`firestore-schema.md` 등).
- `scripts/hooks/` — 커밋 시점 백스톱 4종 (아래 "pre-commit 훅" 절 참조).
- `.wellbegun/` — 파이프라인 문서 (spec/plan/decisions).

## 클론 후 최초 설정

```sh
flutter pub get
npm ci --prefix content-pipeline   # 파이프라인(Node) 의존성
git config core.hooksPath scripts/hooks   # pre-commit 훅 설치 (아래 참조)
```

### pre-commit 훅

git hook은 클론으로 전파되지 않으므로 위처럼 저장소 내 훅 경로를 1회 지정한다.
이후 커밋마다 검사 4종이 작업 트리 전체를 훑어 위반 커밋을 막는다:

- `check-hardcoded-values.sh` — 토큰 밖 raw 디자인 값.
- `check-registry-sync.sh` — 공유 폴더 ↔ REGISTRY.md 로스터 동기화.
- `check-no-location-upload.sh` — 기기 위치는 서버에 올리지 않는다는 데이터 소유권
  결정의 강제. 다섯 방향을 본다: `lib/backend/` 에 위도·경도로 읽히는 필드가 없는지,
  그리고 좌표를 다루는 `lib/location/` 이 (1) **허용 목록 안의 것만** import
  하는지, (2) `export`·`part` 를 쓰지 않는지, (3) 그 폴더에 값을 담아 둘
  자리(최상위 변수 · 클래스 안의 `static` 저장소 · 좌표를 쌓을 수 있는 인스턴스
  필드)를 두지 않았는지, (4) 좌표를 콘솔에 찍지 않는지(`print`·`debugPrint*` ·
  `Zone.current.print` 같은 점 뒤 호출).
  (1) 의 허용 목록은 그 폴더가 **오늘 실제로 쓰는 것** 여섯뿐이다(`dart:math` ·
  `package:flutter_riverpod` · 좌표·권한 플러그인 둘 ·
  `../content/kst.dart` · 같은 폴더의 파일). 거부 목록이 아니라 허용 목록인 것은
  거부 목록이 세 번 샜기 때문이다 — `lib/backend/` 만 막던 검사가 `lib/analytics/`
  를 놓쳤고, 그 둘을 막은 검사가 `lib/content/content_providers.dart` 의
  `httpClientProvider` 와 `lib/weather/weather.dart` 의 `effectAt(lat:, lng:)` 를
  놓쳤다. 짝으로, 허용 목록의 유일한 폴더 밖 문인 `lib/content/kst.dart` 에는
  검사가 셋 붙는다: 그 파일에 `export`·`part` 가 없는지, 그 파일 자신의 import 도
  허용 목록(`models.dart`) 안에만 있는지, 그리고 그 파일이 내미는 **최상위 공개
  이름 집합**이 넷 그대로인지. 셋째가 사이클 2 의 4.1 round 5 에서 생겼다 — 그
  전에는 `export` 만 보고 있어서, 그 파일에 공개 함수를 하나 더하고 그 안에서
  좌표를 외부 서버로 보내는 것이 훅 4종과 시험 663개를 전부 통과했다. 그 셋은
  round 6 까지 `[ -f ]` 가드 뒤에 있어서 그 파일이 옮겨지면 **조용히**
  건너뛰어졌다(`git mv` 로 재현) — 이제 스크립트가 자기가 볼 세 자리
  (`lib/backend` · `lib/location` · `lib/content/kst.dart`)의 존재를 먼저
  단언하고, 자리가 사라지면 침묵하는 대신 exit 2 로 드러난다.
  (3) 이 허용하는 것은 `const`·`static const`, "담을 수 없는 타입"(변하지 않는
  dart:core 기본형과 그 폴더가 스스로 선언한 class·enum·mixin 이름, 그리고 함수
  타입 typedef)의 `final` 필드, 함수 타입의 `final` 필드, 그리고 그런 타입 인자를
  받는 읽기 전용 provider 뿐이다 — `Provider<LocationPermissionGateway>`·
  `Provider<int>` 는 통과하고 `Provider<List<DeviceFix>>`·`Provider<StringBuffer>`
  는 통과하지 못한다(변경 가능한 통이 곧 좌표를 담아 둘 자리다). 이 검사는 줄이
  아니라 **문장**을 본다 — 파일을 훑으며 주석과 문자열을 걷어 내고 괄호 밖의
  중괄호로 깊이를 세므로, 들여쓰기를 네 칸으로 바꾸거나 클래스를 한 줄로 쓰거나
  선언을 여러 줄로 쪼개도 같은 자리로 온다(round 5 이전에는 그 셋이 전부 검사를
  지나갔다). round 6 이 이 검사의 **오탐 셋**을 풀었다 — 값 나열 뒤에 멤버가
  오는 enum, `@override` 가 붙은 필드, 몸통 없는 게터 선언(`String get id;`)
  이 전부 exit 2 였다. 셋 다 평범한 Dart 이고 `flutter analyze` 무지적인데
  커밋과 CI 를 막았다. 이 검사가 **일부러** 거절하는 정당한 모양(타입을 적지
  않은 `final`, `late` 필드, `final List<String>`, 타입 매개변수·레코드 타입
  필드, 최상위 `final` 등)은 그 스크립트 헤더의 4) 에 **열린 목록**으로 적혀
  있다 — round 6 의 거부 사유가 바로 그 목록이 "아래 둘"로 닫혀 있었던 것이다.
- `check-firebase-import-boundary.sh` — SDK import 가 전용 계층 밖으로 새지 않는지.
  백엔드 SDK(`firebase_*` · `cloud_firestore` · `cloud_functions` ·
  `google_sign_in` · 카카오)는 `lib/backend/`·`lib/analytics/` 안에만, 위치 권한
  플러그인(`permission_handler`)은 `lib/location/location.dart` 안에만, 좌표
  플러그인(`geolocator`)은 `lib/location/visit_check.dart` 안에만. 좌표 쪽이
  파일 하나로 좁은 것은 기기의 좌표를 얻는 통로를 그 라이브러리 안에 가두기
  위해서다 — 그 통로는 private 함수 하나이고, 그것을 들고 도는 판정기도
  private 필드로만 쥔다.

이 검사 둘과 `lib/location/` 의 구조와 경계 시험의 파수꾼들이 함께 지키는
약속은 **"앱의 코드가 기기 좌표를 서버로 보내지 않으며, 그렇게 하려면 눈에
띄는 의도적 변경이 필요하다"** 이다(`.wellbegun/decisions.md` 2026-09-04
`[L]`).

**그 문장이 왜 "불가능하다"가 아닌지부터 읽을 것.** 위 약속을 지키는 것은
대부분 **소스 텍스트를 보는 검사와 시험**이다. 텍스트를 보는 검사가 실제로
막는 것은 **실수와 무심코**이고, **작정하고 그 검사를 피하려는 코드는 막지
못한다** — 텍스트를 보는 검사에는 언제나 같은 일을 하면서 패턴을 비켜 가는
표기가 남고, 그것은 정규식을 더 촘촘히 해서 없앨 수 있는 성질이 아니다.
4.1 의 fresh 검증 round 3·4·5 가 매번 검사를 하나 더 두껍게 했고 매번 다음
표기가 나왔다(별칭과 점 사이의 줄바꿈 · 네 칸 들여쓴 클래스 필드 · 한 줄로
쓴 클래스 · 허용된 파일에 공개 함수 하나 더하기). round 5 가 그 넷을 막았지만
다섯 번째가 없다고 적지 않는다.

그런 우회를 실제로 막는 것은 검사가 아니라 **코드 리뷰**이고, 그런 코드는
눈에 띈다. 그래서 아래 겹별 목록이 약속하는 것은 **"이 갈래는 실수로 지나갈
수 없다"**이지 **"이 갈래는 누구도 지날 수 없다"**가 아니다.

그 약속은 다섯 겹으로 서 있는데 **겹마다 지키는 것이 다르고, 겹마다 지키지
못하는 것도 있다** — 겹 1(좌표 통로가 private)은 Dart 의 가시성과
`test/features/badges/visit_check_test.dart` 의 소스 대조 파수꾼 여섯이(폴더
전체 · geolocator 의 모든 별칭을 만지는 최상위 선언이 `_readDeviceFix`
하나인가 · `part` 금지 · 통로를 부르는 줄 · 밖에서 값을 건네받는 두 서명 ·
판정기의 필드 집합), 겹 2(플러그인 import 를 파일 하나로)는
`check-firebase-import-boundary.sh` 가, 겹 3(내보낼 수단 없음)과 겹 4(담아 둘
자리 없음)는 `check-no-location-upload.sh` 가, 겹 5(경계를 넘는 타입에 좌표
없음, 후보 타입에 팀 id 없음)는 타입 파수꾼 셋이 지킨다.

**지키지 못하는 것도 그 자리에 적혀 있다.** `dart:core` 는 import 없이 서므로
막을 수 없고, 거기 있는 `print` 는 이름을 그대로 부르는 줄로만 잡히므로
`final logger = print;` 로 우회된다(실측 확인). 겹 4 는 함수 몸통 안의 지역
변수와 클로저 캡처를 보지 않는다. 겹 1 의 파수꾼은 선언을 열 0 의 머리 줄로
알아보므로, 열 0 을 블록 주석으로 여는 선언은 앞 선언의 이름을 물려받아
지나간다(이 라운드의 구현자가 스스로 공격해 확인했고, 정규식을 한 겹 더
씌우는 대신 적어 두었다). 겹별로 무엇이 지키고 무엇은 지키지 않는지는
`lib/location/visit_check.dart` 첫 문단에 실측과 함께 적혀 있다 — 뭉뚱그려
"다섯 다 검사가 지킨다"라고 쓰지 말 것.

**다음에 이 문단을 고치는 사람에게.** 새 표기 우회를 하나 찾았다고 해서 이
문단이 거짓이 되는 것은 아니다: 그런 우회는 이 문단이 이미 인정한 범위 안이다.
값어치가 있는 것은 **실수로 지나갈 수 있는 갈래**(사람이 나쁜 뜻 없이 쓸 법한
모양인데 검사가 놓치는 자리)를 찾는 쪽이다.

그보다 강한 문장 — 좌표를 알아내는 것이 구조적으로 불가능하다 — 은 이 앱이
하지 않는 약속이다: 구장 방문 판정 API 는 "이 지점 반경 안에 있는가"를 묻는
신탁이라 반복 질의로 좌표가 좁혀지고(측위 5회로 오차 0.03m), 위치 기반
참·거짓을 묻는 코드가 앱 안에 있는 한 그 성질은 없앨 수 없다. 자세한 것은
`lib/location/visit_check.dart` 첫 문단과
`test/probe/coord_oracle_probe_test.dart` 에 있다.

Claude Code 세션에서는 `.claude/settings.json`의 PostToolUse 훅이 편집 직후에도 검사를
돌리지만 범위가 다르다 — `check-hardcoded-values.sh`와 `check-no-location-upload.sh`
2종뿐이고, `check-registry-sync.sh`·`check-firebase-import-boundary.sh`는 커밋 시점
(pre-commit)에서만 돈다. **CI(`conventions` job)는 4종을 전부 돈다** — 위치 검사
둘은 4.1 round 5 에서 배선했고, 그 전까지는 로컬 훅에만 걸려 있어서 훅을 설정하지
않은 클론과 `--no-verify` 커밋과 크론 워크플로의 봇 커밋이 전부 지나갔다.

## 개발

```sh
flutter analyze                      # 경고 0 유지
flutter test
npm --prefix content-pipeline test   # 파이프라인 테스트
node content-pipeline/common/validate.mjs   # data/ 4종 JSON 계약 검증
```

### Firestore 규칙 테스트

사용자 데이터의 보안 규칙(`firestore.rules`)은 Firestore 에뮬레이터 위에서 실제 규칙
파일을 평가하는 단위 테스트로 검증한다. 클라우드에 붙지 않으므로 Firebase 로그인도
실제 프로젝트도 필요 없다 (에뮬레이터 전용 프로젝트 id `demo-kbo-away-fans` 를 쓴다).

```sh
npm ci --prefix firebase              # 최초 1회 — firebase-tools + 규칙 테스트 하네스
npm --prefix firebase test            # 에뮬레이터 기동 → 규칙 테스트 → 종료
npm --prefix firebase run emulator    # 에뮬레이터만 띄워 둔 채 대기 (수동 확인용)
```

에뮬레이터는 127.0.0.1:8791 을 쓴다.

**JDK 21 (에뮬레이터 선행 조건).** Firestore 에뮬레이터는 Java 런타임 위에서 돈다.
macOS 의 `/usr/bin/java` 는 JVM 이 없어도 존재하는 스텁이라 `java -version` 이 실패하면
설치가 필요하다.

```sh
brew install openjdk@21                          # macOS
sudo apt-get install -y openjdk-21-jre-headless  # Debian/Ubuntu
```

Homebrew 의 `openjdk@21` 은 keg-only 라 PATH 에 노출되지 않는데, 셸 설정을 고치지
않아도 된다 — `firebase/run-rules-tests.sh` 가 흔한 설치 경로를 스스로 뒤져 PATH 를
주입한다. 다른 위치에 설치했다면 `JAVA_HOME` 을 지정하고 실행한다.

계약 문서는 `docs/firestore-schema.md` 다. 필드를 더하거나 지우는 변경은 그 문서와
`firestore.rules`, `firebase/test/rules.test.mjs` 를 같은 커밋에서 함께 옮긴다.

### Cloud Functions (카카오 로그인)

`functions/` 에 callable 함수 하나(`kakaoCustomToken`)가 있다 — 카카오 액세스 토큰을
검증해 Firebase 커스텀 토큰을 발급한다. 호출 규약과 오류 코드는
`lib/backend/REGISTRY.md` 의 "이 폴더 밖에 있는 짝" 절이 든다.

```sh
npm --prefix functions test    # 단위 테스트 (의존성 설치 없이 그대로 돈다)
npm ci --prefix functions      # 배포·에뮬레이터에 필요한 SDK 설치
```

테스트는 가짜 카카오 응답과 가짜 Admin SDK 로 돌기 때문에 카카오에도 Firebase 에도
나가지 않는다. Firebase SDK 를 설치하면 배선 테스트 4개가 더 켜진다(미설치 시 skip) —
`test/index.test.js` 의 배선 2개와 `test/app-check-enforcement.test.js` 의 App Check
강제 2개. 뒤쪽은 함수를 express 핸들러로 세워 HTTP 로 부르므로 카카오 호출도
`globalThis.fetch` 대역이 받는다(네트워크로 나가지 않는다).

이 함수는 **App Check 을 강제한다**(`enforceAppCheck: true`). 로그인 **전에** 불리는
함수라 호출자 인증을 요구할 수 없고(요구할 자격 증명이 바로 이 함수가 발급하려는
것이다), 부르는 것 자체가 카카오 API 왕복과 함수 실행 시간이라 남의 반복 호출이 그대로
요금이 된다. 유효한 App Check 토큰이 없는 호출은 함수 몸이 돌기 전에 `unauthenticated`
로 거절된다. 클라이언트 배선은 `lib/backend/app_check.dart` 이고, 둘 중 하나만 서면
아무것도 막지 못한다.

**그래서 배포에는 순서가 있다.** 콘솔에 증명 제공자를 등록하고 개발 기기의 디버그
토큰을 넣기 **전에** 이 함수를 배포하면, 그 순간부터 카카오 로그인이 전부 막힌다.
순서와 확인 방법은 `.wellbegun/run.md` 의 step 2.3 "사람 몫" 체크리스트에 있다.

### 카카오 로그인 (사람이 1회)

1. **카카오 개발자 콘솔**(https://developers.kakao.com) → 내 애플리케이션 추가.
   앱 이름·회사명을 넣고 만들면 앱 키 넷이 나온다.
2. **네이티브 앱 키**를 세 자리에 **같은 값으로** 적는다:
   - `lib/backend/auth_kakao.dart` 의 `kKakaoNativeAppKey`
   - `android/app/src/main/AndroidManifest.xml` 의 `android:scheme="kakao{키}"`
   - `ios/Runner/Info.plist` 의 `CFBundleURLTypes` → `kakao{키}`
   세 자리가 어긋나면 로그인이 끝나고도 앱으로 **돌아오지** 못한다. 대조는
   `flutter test test/backend/kakao_app_key_sync_test.dart` 가 한다.
3. **플랫폼 등록**: 콘솔 → 플랫폼에서 Android 패키지명
   (`com.ardenspace.kbo_away_fans`)과 **키 해시**, iOS 번들 ID 를 등록한다. 이 등록이
   이 키의 실제 방어선이다 — 등록된 바이너리에서만 그 키를 쓸 수 있다.
4. **카카오 로그인 활성화 + 동의 항목**: 콘솔 → 카카오 로그인 활성화, 동의 항목은
   **닉네임 하나뿐**이다(이메일·전화번호는 비즈니스 채널을 요구하고 앱이 그 값으로
   하는 일이 없다 — `functions/kakao.js` 의 `KAKAO_PROPERTY_KEYS`).
5. Redirect URI 는 따로 등록하지 않는다 — 네이티브 SDK 는 `kakao{키}://oauth` 커스텀
   스킴으로 돌아오고, 그 스킴은 위 2번의 두 네이티브 파일에 있다.

**네이티브 앱 키는 저장소에 그대로 둔다.** 감출 값이 아니기 때문이다: 카카오의 네 앱
키 중 감추라고 경고되는 것은 Admin 키와 client secret 이고, 네이티브 앱 키는 앱에
내장되는 것을 전제로 설계된 플랫폼 키라 APK·IPA 를 뜯으면 그대로 나온다. 감출지
말지를 "카카오 키인가"가 아니라 **"이 값이 바이너리에 실려 나가는가"**로 가른
판단이다(`.wellbegun/decisions.md`). **Admin 키·REST API 키·client secret 은 저장소에
들어오면 안 된다** — 지금 `functions/` 는 사용자의 액세스 토큰만 검증하므로 셋 다
필요 없다.

### Firebase 콘솔 설정 (사람이 1회)

코드로는 할 수 없고 콘솔·개발자 계정에서 해야 하는 몫이다. 순서가 중요하다 —
**예산 알림과 상한을 먼저 걸고 Blaze 로 올린다.**

1. **예산 알림·상한**: Google Cloud 콘솔 → 결제 → 예산 및 알림에서 월 **$5** 예산을
   만들고 임계 **50% · 90% · 100%** 알림을 건다. Blaze 로 올려도 Spark 의 무료
   할당량은 그대로라 MVP 규모의 정상 사용은 청구액이 0에 수렴하므로, 임계를 넘는 것
   자체가 폭주·남용 신호다.
2. **Blaze 전환**: Firebase 콘솔 → 요금제. Cloud Functions 배포(카카오 로그인, step
   2.3)에 필요하다.
3. **구글 제공자**: Firebase 콘솔 → Authentication → Sign-in method → Google 사용
   설정. Android 는 디버그·릴리스 SHA-1 지문을 프로젝트 설정에 등록하고
   `google-services.json` 을 **다시** 내려받는다(웹 OAuth 클라이언트 `client_type: 3`
   가 들어 있어야 id 토큰이 나온다). iOS 는 `GoogleService-Info.plist` 를 **다시**
   내려받기만 하면 된다 — 그 파일의 `REVERSED_CLIENT_ID` 를 빌드 단계가 산출물의
   `Info.plist` 에 URL 스킴으로 넣는다(아래 문단). 저장소의
   `ios/Runner/Info.plist` 에 손으로 적지 않는다.
4. **애플 제공자**: Firebase 콘솔 → Authentication → Sign-in method → Apple 사용
   설정. Xcode 에서 Runner 타깃에 **Sign in with Apple** capability 를 켜고, Apple
   Developer 의 App ID 에도 같은 기능을 켠다. iOS 는 네이티브 시트로 뜨므로 여기까지면
   된다 — 안드로이드의 애플 로그인은 웹 흐름이라 Services ID 와 return URL 이 더
   필요하다.

앱 쪽 구현은 `lib/backend/auth_firebase.dart` 하나이며, 위 설정이 없는 클론에서도
`flutter analyze`·`flutter test`·안드로이드 빌드·iOS 빌드가 그대로 통과한다.
설정 파일을 양쪽 빌드가 **있으면 쓰고 없으면 넘어가는** 방식으로 집어 들기 때문이다:
안드로이드는 `android/app/build.gradle.kts` 가 `google-services.json` 이 있을 때만
`com.google.gms.google-services` 플러그인을 적용하고, iOS 는 Runner 타깃의
"Firebase config: copy plist + inject Google URL scheme (if present)" 빌드 단계가
파일이 있을 때만 앱 번들로 복사한다(Copy Bundle Resources 에 넣어 두면 파일이 없는
클론에서 Xcode 가 "Build input file cannot be found" 로 멈춘다). 설정 파일을 놓았다가
치운 경우에도 같은 단계가 번들에 남은 옛 사본을 지우므로, 빌드에 설정이 실렸는지는
설정 파일의 유무 하나로 정해진다.

같은 단계가 iOS 구글 로그인의 URL 스킴도 맡는다. `GIDSignIn` 은 리버스 클라이언트
ID 가 URL 스킴으로 등록돼 있지 않으면 예외를 던지는데, 그 값은 프로젝트 좌표라
저장소에 두지 않기로 했으므로(`.wellbegun/decisions.md`) 저장소의
`ios/Runner/Info.plist` 대신 **빌드 산출물의** `Info.plist` 에만 넣는다. 단계는
`GoogleService-Info.plist` 에서 `REVERSED_CLIENT_ID` 를 읽어 `CFBundleURLTypes` 를
주입하고, 설정 파일이 없거나 아직 구글 제공자를 켜지 않아 그 키가 없으면 조용히
넘어간다. 그래서 사람이 손으로 넣을 것도, 커밋할지 말지 고를 것도 없다.

### 자격 증명 주입 지점 (전부 선택 사항 — 없어도 빌드·테스트 통과)

앱은 비밀 값을 하드코딩하지 않고 `--dart-define` 또는 설정 파일로 받는다.
미주입 시 각 기능은 조용히 폴백으로 저하된다.

| 주입 지점 | 방법 | 없을 때 동작 |
|---|---|---|
| `NAVER_MAP_CLIENT_ID` | `--dart-define=NAVER_MAP_CLIENT_ID=...` | 지도가 자리 표시 폴백으로 렌더 |
| `OPENWEATHER_API_KEY` | `--dart-define=OPENWEATHER_API_KEY=...` | 날씨 연출 없음 |
| `CONTENT_BASE_URL` | `--dart-define=CONTENT_BASE_URL=...` | 실호스팅(GitHub Pages) 기본값 사용 |
| Firebase 설정 파일 | `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` | 분석 이벤트가 조용히 no-op + 로그인 불가 (로그인 화면이 안내와 함께 선다) |
| 카카오 네이티브 앱 키 | **주입이 아니라 저장소의 값** — 위 "카카오 로그인" 절의 세 자리 | 카카오 로그인이 `kakao-key-missing` 으로 드러나게 실패 (다른 두 제공자는 그대로) |

Firebase 설정 파일은 저장소에 두지 않는다 — Firebase 콘솔의 프로젝트 설정에서
각자 내려받아 위 두 경로에 놓는다. 로그인은 분석과 달리 조용히 no-op 하지 않는다:
계정 없이 쓰는 경로가 없는 앱이라 "로그인 없이 도는 실행"은 곧 설정 실수를 숨기는
것이므로, 설정이 없으면 로그인 화면에 안내가 함께 뜬다
(`lib/backend/auth_firebase.dart`).

예시 (전부 주입한 실행):

```sh
flutter run \
  --dart-define=NAVER_MAP_CLIENT_ID=<클라이언트ID> \
  --dart-define=OPENWEATHER_API_KEY=<API키>
```

Android 는 Firebase 설정 파일을 넣으면 다음 빌드부터 Google Services plugin 이
자동 적용된다 (`android/app/build.gradle.kts` 의 조건부 wiring — 파일이 없으면
plugin 미적용으로 빌드는 그대로 통과).

### 로컬 콘텐츠 서버

콘텐츠 JSON 4종(teams/stadiums/places/schedule)의 소스는
`lib/content/content_config.dart` 의 `kContentBaseUrl` 상수 하나다.
로컬 산출물로 앱을 돌리려면 정적 서버를 띄우고 오버라이드한다:

```sh
python3 -m http.server 8899 --directory content-pipeline/data
flutter run --dart-define=CONTENT_BASE_URL=http://127.0.0.1:8899
```

iOS 시뮬레이터는 `127.0.0.1` 그대로, Android 에뮬레이터는 호스트 루프백이
`10.0.2.2` (`http://10.0.2.2:8899`). 예시 포트 8899 는 임의 값이니 겹치면 바꾼다.

## 콘텐츠 배포

`content-pipeline/data/` 의 4종 JSON 은 GitHub Pages(gh-pages 브랜치)로 배포된다:

```sh
npm --prefix content-pipeline run deploy
```

deploy 는 idempotent — 원격 트리가 동일하면 push 를 생략하므로 언제 다시 실행해도
안전하다. CI 경로는 `.github/workflows/`(크롤 cron 이 변경 커밋 시 직접 deploy,
사람 push 는 deploy-content.yml)가 커버한다.
