/// Step 3.3 boundary test — 길안내 딥링크 URL 생성(좌표·이름 인코딩)과
/// OS 공유 페이로드. SDK 없이 순수 함수만 검증한다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/map_links.dart';

void main() {
  // 공백·특수문자·한글이 섞인 이름으로 인코딩을 검증한다.
  const name = '사직 돼지국밥 & 냉면';
  const lat = 35.1941;
  const lng = 129.0615;

  test('앱 딥링크 — nmap://route/public 에 좌표·인코딩된 이름·appname', () {
    final uri = naverMapRouteAppUri(name: name, lat: lat, lng: lng);

    expect(uri.scheme, 'nmap');
    expect(uri.host, 'route');
    expect(uri.path, '/public');
    expect(uri.queryParameters['dlat'], '35.1941');
    expect(uri.queryParameters['dlng'], '129.0615');
    // 디코딩 왕복 — percent 인코딩이 이름을 온전히 보존한다.
    expect(uri.queryParameters['dname'], name);
    // 원문에는 인코딩된 형태로 실린다 (공백 %20, & %26, 한글 UTF-8).
    expect(uri.toString(), contains(Uri.encodeComponent(name)));
    expect(uri.queryParameters['appname'], kNaverMapCallerAppName);
  });

  test('웹 폴백 — 도착지가 lng,lat,인코딩된 이름으로 경로에 고정된다', () {
    final uri = naverMapRouteWebUri(name: name, lat: lat, lng: lng);

    expect(uri.scheme, 'https');
    expect(uri.host, 'map.naver.com');
    expect(uri.toString(), contains('/p/directions/-/129.0615,35.1941,'));
    expect(uri.toString(), contains(Uri.encodeComponent(name)));
  });

  test('공유 페이로드 — 장소 이름 + 지도 링크가 담긴다', () {
    final payload = buildMapSharePayload(name: name, categoryLabel: '맛집');

    expect(payload, contains(name));
    expect(payload, contains('맛집'));
    final link = naverMapPlaceWebUri(name: name);
    expect(link.toString(), startsWith('https://map.naver.com/p/search/'));
    expect(link.toString(), contains(Uri.encodeComponent(name)));
    expect(payload, contains(link.toString()));
  });

  test('길안내 실행 — 앱 딥링크 우선, 실패하면 웹 폴백 순서로 연다', () async {
    final attempts = <Uri>[];
    final opened = await launchNaverMapRoute(
      name: name,
      lat: lat,
      lng: lng,
      launch: (uri) async {
        attempts.add(uri);
        return uri.scheme == 'https'; // 앱 스킴은 실패 시나리오.
      },
    );

    expect(opened, isTrue);
    expect(attempts, hasLength(2));
    expect(attempts.first.scheme, 'nmap');
    expect(attempts.last.scheme, 'https');
  });

  test('길안내 실행 — 앱 딥링크가 열리면 웹 폴백은 시도하지 않는다', () async {
    final attempts = <Uri>[];
    final opened = await launchNaverMapRoute(
      name: name,
      lat: lat,
      lng: lng,
      launch: (uri) async {
        attempts.add(uri);
        return true;
      },
    );

    expect(opened, isTrue);
    expect(attempts, hasLength(1));
    expect(attempts.single.scheme, 'nmap');
  });
}
