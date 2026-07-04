/// NCP(NAVER Cloud Platform) Maps Client ID 배선 + 미주입 degrade 판정 (R12).
///
/// 네이티브·SDK 의존 없는 순수 Dart — 지도 화면(task 2.4)이 이 상수·술어를 참조해
/// 네이티브 지도 위젯을 만들지, 안내 텍스트로 degrade 할지 분기한다.
library;

/// `--dart-define=NCP_MAP_CLIENT_ID=...` 로 주입되는 NCP Maps Client ID.
///
/// 기존 시크릿 컨벤션(main.dart 의 `SUPABASE_URL`/`SUPABASE_ANON_KEY`
/// `String.fromEnvironment`)과 동일하게 컴파일 타임에 주입한다.
/// 실키는 저장소에 커밋하지 않으며(관행), 미주입 시 기본값은 빈 문자열이다.
///
/// task 2.4 의 네이버맵 초기화가 이 값을 그대로 읽어 쓴다.
const String ncpMapClientId = String.fromEnvironment('NCP_MAP_CLIENT_ID');

/// Client ID 미주입(빈 문자열/공백) 판정 — 지도 화면 degrade 분기의 술어.
///
/// true 면 네이티브 지도 위젯을 생성하지 말고 안내 텍스트만 렌더한다
/// (crash 없음, R12). [clientId] 를 인자로 받아 순수하게 판정하므로
/// `--dart-define` 없이도 단위 테스트로 검증 가능하다.
bool shouldDegradeMap(String clientId) => clientId.trim().isEmpty;
