# kbo-away-fans

KBO 원정 팬을 위한 구장 주변 가이드 앱 (Flutter).

## 구조

- `lib/design/` — 디자인 토큰 (색·간격·타이포·모션). 토큰 파일 밖 raw 리터럴 금지.
- `lib/ui/shared/` — 공유 컴포넌트 (`REGISTRY.md` 로스터와 짝 유지).
- `lib/features/` — 화면·기능 단위 코드.
- `content-pipeline/` — 서버 없는 콘텐츠 파이프라인 (크롤링 → 검증 → 정적 JSON 배포).
- `.wellbegun/` — 파이프라인 문서 (spec/plan/decisions).

## 클론 후 최초 설정

```sh
flutter pub get
npm ci --prefix content-pipeline   # 파이프라인(Node) 의존성
git config core.hooksPath scripts/hooks   # pre-commit 훅 설치 (아래 참조)
```

### pre-commit 훅

git hook은 클론으로 전파되지 않으므로 위처럼 저장소 내 훅 경로를 1회 지정한다.
이후 커밋마다 `check-hardcoded-values.sh`(토큰 밖 raw 디자인 값)와
`check-registry-sync.sh`(공유 폴더 ↔ REGISTRY.md 로스터 동기화)가 실행되어 위반 커밋을 막는다.
Claude Code 세션에서는 `.claude/settings.json`의 PostToolUse 훅이 편집 직후에도 같은 검사를 돌린다.

## 개발

```sh
flutter analyze                      # 경고 0 유지
flutter test
npm --prefix content-pipeline test   # 파이프라인 테스트
node content-pipeline/common/validate.mjs   # data/ 4종 JSON 계약 검증
```

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
