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
- `check-no-location-upload.sh` — `lib/backend/` 업로드 payload 에 위도·경도로 읽히는
  필드가 없는지 (기기 위치는 서버에 올리지 않는다는 데이터 소유권 결정의 강제).
- `check-firebase-import-boundary.sh` — Firebase·카카오 SDK import 가
  `lib/backend/`·`lib/analytics/` 밖으로 새지 않는지.

Claude Code 세션에서는 `.claude/settings.json`의 PostToolUse 훅이 편집 직후에도 검사를
돌리지만 범위가 다르다 — `check-hardcoded-values.sh`와 `check-no-location-upload.sh`
2종뿐이고, `check-registry-sync.sh`·`check-firebase-import-boundary.sh`는 커밋 시점
(pre-commit)에서만 돈다.

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
나가지 않는다. Firebase SDK 를 설치하면 배선 테스트 2개가 더 켜진다(미설치 시 skip).

배포는 Blaze 플랜과 카카오 앱 설정이 갖춰진 뒤다 — 실제 연동은 `.wellbegun/plan.md`
의 step 2.3 이 맡는다.

### 자격 증명 주입 지점 (전부 선택 사항 — 없어도 빌드·테스트 통과)

앱은 비밀 값을 하드코딩하지 않고 `--dart-define` 또는 설정 파일로 받는다.
미주입 시 각 기능은 조용히 폴백으로 저하된다.

| 주입 지점 | 방법 | 없을 때 동작 |
|---|---|---|
| `NAVER_MAP_CLIENT_ID` | `--dart-define=NAVER_MAP_CLIENT_ID=...` | 지도가 자리 표시 폴백으로 렌더 |
| `OPENWEATHER_API_KEY` | `--dart-define=OPENWEATHER_API_KEY=...` | 날씨 연출 없음 |
| `CONTENT_BASE_URL` | `--dart-define=CONTENT_BASE_URL=...` | 실호스팅(GitHub Pages) 기본값 사용 |
| Firebase 설정 파일 | `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` | 분석 이벤트가 조용히 no-op |

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
