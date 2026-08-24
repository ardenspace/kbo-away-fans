/// 네이버지도 링크 빌더 — 길안내 딥링크(nmap://)와 웹 폴백, 장소 지도 링크,
/// OS 공유 페이로드를 한곳에서 만든다.
///
/// 지도 SDK(flutter_naver_map) 의존성이 없는 순수 URL 계층이라
/// 좌표·이름 인코딩을 단위 테스트로 검증한다. SDK 렌더는 StadiumMapView 소유.
library;

import 'package:url_launcher/url_launcher.dart';

/// nmap 딥링크 관례상 호출 앱 식별자(appname 파라미터)로 넣는 번들 id.
const String kNaverMapCallerAppName = 'dev.arden.kbo_away_fans';

/// 네이버지도 앱 길안내 딥링크 (대중교통 기준).
///
/// 이름은 percent 인코딩해 dname 에 싣는다.
Uri naverMapRouteAppUri({
  required String name,
  required double lat,
  required double lng,
}) {
  return Uri.parse(
    'nmap://route/public?dlat=$lat&dlng=$lng'
    '&dname=${Uri.encodeComponent(name)}'
    '&appname=$kNaverMapCallerAppName',
  );
}

/// 네이버지도 웹 길안내 폴백 (앱 미설치 시) — 도착지는 좌표+이름으로 고정.
Uri naverMapRouteWebUri({
  required String name,
  required double lat,
  required double lng,
}) {
  return Uri.parse(
    'https://map.naver.com/p/directions/-/'
    '$lng,$lat,${Uri.encodeComponent(name)}/-/transit',
  );
}

/// 장소를 보여주는 네이버지도 웹 링크 (공유 페이로드용).
Uri naverMapPlaceWebUri({required String name}) {
  return Uri.parse(
    'https://map.naver.com/p/search/${Uri.encodeComponent(name)}',
  );
}

/// OS 공유 시트에 담는 페이로드 — 장소 이름 + 지도 링크.
String buildMapSharePayload({
  required String name,
  required String categoryLabel,
}) {
  return '[$categoryLabel] $name\n${naverMapPlaceWebUri(name: name)}';
}

/// URL 실행기 시그니처 — 테스트에서 실행 순서를 관찰하기 위한 주입점.
typedef UriLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchExternal(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// 길안내로 나간다 — 네이버지도 앱 딥링크 우선, 실패하면 웹 폴백.
///
/// 반환값은 어느 한쪽이라도 열렸는지 여부.
Future<bool> launchNaverMapRoute({
  required String name,
  required double lat,
  required double lng,
  UriLauncher launch = _launchExternal,
}) async {
  try {
    final opened = await launch(naverMapRouteAppUri(name: name, lat: lat, lng: lng));
    if (opened) return true;
  } on Exception {
    // 앱 미설치·스킴 차단 등 — 웹 폴백으로 진행.
  }
  try {
    return await launch(naverMapRouteWebUri(name: name, lat: lat, lng: lng));
  } on Exception {
    return false;
  }
}
