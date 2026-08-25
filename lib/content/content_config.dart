/// 콘텐츠 소스 설정 — URL 상수 하나로 소스를 전환한다.
library;

/// 콘텐츠 JSON 4종(teams/stadiums/places/schedule)의 배포 원점.
///
/// **이 상수 하나만 바꾸면 소스가 바뀐다** (spec의 acceptance 계약).
/// 기본값은 실호스팅(GitHub Pages, `content-pipeline/deploy.mjs` 가
/// gh-pages 브랜치로 올리는 곳)이다.
///
/// 로컬 개발·CI 는 `--dart-define=CONTENT_BASE_URL=...` 로 오버라이드한다:
/// ```sh
/// python3 -m http.server 8787 --directory content-pipeline/data
/// flutter run --dart-define=CONTENT_BASE_URL=http://127.0.0.1:8787
/// ```
/// (iOS 시뮬레이터는 `127.0.0.1` 그대로, Android 에뮬레이터는
/// 호스트 루프백이 `10.0.2.2`.)
const String kContentBaseUrl = String.fromEnvironment(
  'CONTENT_BASE_URL',
  defaultValue: 'https://ardenspace.github.io/kbo-away-fans',
);

/// 콘텐츠 문서 하나의 HTTP 요청 타임아웃.
///
/// 실기기에서 첫 로드가 무기한 대기하지 않도록 로더의 모든 GET 에 적용한다.
/// 파이프라인 fetch 공통(`content-pipeline/common/fetch.mjs`)의 시도당
/// 타임아웃 10초와 같은 값.
const Duration kContentFetchTimeout = Duration(seconds: 10);

/// 앱이 이해하는 콘텐츠 계약 버전.
///
/// `content-pipeline/schema/*.schema.json` 의 `schemaVersion` const 와
/// 일치해야 한다. 원격 문서의 값이 이와 다르면 로더는 갱신을 거부하고
/// 기존 캐시를 유지한다(계약 변경은 마이그레이션급 — spec DB schema 절).
const int kSupportedSchemaVersion = 1;
