/// task 2.4 — 지도 화면 골격 위젯/단위 테스트 (R9·R12).
///
/// 네이티브 SDK 미로딩: 실제 NaverMap 위젯은 절대 생성하지 않는다. map_view seam 을
/// fake builder 로 대체 pump 하고, degrade 분기는 clientId 파라미터로 강제한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/map/map_models.dart';
import 'package:kbo_away_fans/features/map/map_screen.dart';
import 'package:kbo_away_fans/features/map/naver_map_view.dart';

const _fakeMapKey = Key('fake-map-view');

/// map_view 대체 구현 — 전달받은 마커를 노출하는 fake. 네이티브 SDK 미접촉.
class _RecordingMapView {
  List<MapMarker>? received;

  Widget build(BuildContext context, List<MapMarker> markers) {
    received = markers;
    return Container(key: _fakeMapKey);
  }
}

List<MapMarker> _markers(int n) => [
      for (var i = 0; i < n; i++)
        MapMarker(
          id: 'stadium-$i',
          name: 'stadium-$i',
          lat: 37.0 + i,
          lng: 127.0 + i,
          isVisited: i.isEven,
        ),
    ];

void main() {
  testWidgets('fake map_view 로 pump → flutter test 통과 (네이티브 SDK 미로딩) (R12)',
      (tester) async {
    final fake = _RecordingMapView();
    await tester.pumpWidget(MaterialApp(
      home: MapScreen(
        clientId: 'real-client-id',
        mapViewBuilder: fake.build,
      ),
    ));

    expect(find.byKey(_fakeMapKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Client ID 미주입 → 네이티브 지도 위젯 미생성 + 중앙 안내 텍스트 (takeException==null) (R12)',
      (tester) async {
    var builderCalled = false;
    await tester.pumpWidget(MaterialApp(
      home: MapScreen(
        clientId: '', // 미주입 → degrade
        mapViewBuilder: (context, markers) {
          builderCalled = true; // 호출되면 네이티브 경로를 탄 것 — degrade 위반.
          return const SizedBox.shrink();
        },
      ),
    ));

    expect(builderCalled, isFalse); // 지도 위젯 빌더 자체를 호출하지 않는다.
    expect(find.byKey(_fakeMapKey), findsNothing);
    expect(find.text(mapUnavailableMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Client ID 주입 시 기본 map_view 는 실제 네이버맵 경로 (구성 분기 단위 확인) (R9)', () {
    // 미주입/공백은 degrade, 주입 값은 실제 경로로 분기한다.
    const injected = MapScreen(clientId: 'real-client-id');
    expect(injected.mapViewBuilder, same(buildNaverMapView));

    // 기본값(dart-define 미주입)은 빈 문자열이라 degrade 경로.
    const defaulted = MapScreen();
    expect(defaulted.clientId, isEmpty);
  });

  testWidgets('Client ID 주입 시 degrade 안내가 아니라 map_view 빌더로 구성한다 (R9)',
      (tester) async {
    final fake = _RecordingMapView();
    await tester.pumpWidget(MaterialApp(
      home: MapScreen(
        clientId: 'real-client-id',
        mapViewBuilder: fake.build,
      ),
    ));

    expect(fake.received, isNotNull); // 빌더가 호출됨 = 실제 경로 분기.
    expect(find.text(mapUnavailableMessage), findsNothing);
  });

  testWidgets('마커 목록을 map_view 로 그대로 전달한다 (마커 전달 확인) (R9)',
      (tester) async {
    final fake = _RecordingMapView();
    final markers = _markers(9);
    await tester.pumpWidget(MaterialApp(
      home: MapScreen(
        clientId: 'real-client-id',
        markers: markers,
        mapViewBuilder: fake.build,
      ),
    ));

    expect(fake.received, hasLength(9));
    expect(fake.received, same(markers));
    expect(fake.received!.first.id, 'stadium-0');
  });
}
