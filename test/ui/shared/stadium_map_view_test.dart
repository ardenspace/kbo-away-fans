import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/stadium_map_view.dart';

void main() {
  testWidgets('SDK 미초기화(키 없음)면 자리 표시 폴백에 마커 라벨이 렌더된다',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StadiumMapView(
            centerLat: 35.1941,
            centerLng: 129.0615,
            markers: [
              StadiumMapMarker(
                id: 'stadium-sajik',
                label: '사직야구장',
                lat: 35.1941,
                lng: 129.0615,
              ),
              StadiumMapMarker(
                id: 'place-gukbap',
                label: '사직 국밥집',
                lat: 35.19,
                lng: 129.06,
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(StadiumMapView), findsOneWidget);
    // 테스트 환경에는 클라이언트 ID 가 없으므로 항상 폴백 경로다.
    expect(find.text('지도 준비 중'), findsOneWidget);
    expect(find.text('사직야구장'), findsOneWidget);
    expect(find.text('사직 국밥집'), findsOneWidget);
  });
}
