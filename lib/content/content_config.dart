/// 콘텐츠 소스 설정 — URL 상수 하나로 소스를 전환한다.
library;

/// 콘텐츠 JSON 4종(teams/stadiums/places/schedule)의 배포 원점.
///
/// **이 상수 하나만 바꾸면 소스가 바뀐다** (spec의 acceptance 계약).
/// 실호스팅 URL 연결은 step 5.3의 일이다.
///
/// 개발 단계에서는 저장소의 샘플 데이터를 로컬 정적 서버로 서빙한다:
/// ```sh
/// python3 -m http.server 8787 --directory content-pipeline/data
/// ```
/// (iOS 시뮬레이터는 `127.0.0.1` 그대로, Android 에뮬레이터는
/// 호스트 루프백이 `10.0.2.2` 이므로 이 상수를 그 주소로 바꿔 쓴다.)
const String kContentBaseUrl = 'http://127.0.0.1:8787';

/// 앱이 이해하는 콘텐츠 계약 버전.
///
/// `content-pipeline/schema/*.schema.json` 의 `schemaVersion` const 와
/// 일치해야 한다. 원격 문서의 값이 이와 다르면 로더는 갱신을 거부하고
/// 기존 캐시를 유지한다(계약 변경은 마이그레이션급 — spec DB schema 절).
const int kSupportedSchemaVersion = 1;
