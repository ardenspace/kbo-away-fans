import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/place_detail_sheet.dart';

void main() {
  testWidgets('PlaceDetailSheet가 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlaceDetailSheet(
            name: '사직 돼지국밥',
            categoryLabel: '맛집',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('사직 돼지국밥'), findsOneWidget);
    expect(find.text('지도에서 보기'), findsOneWidget);
    expect(find.text('길안내'), findsOneWidget);
    expect(find.text('공유'), findsOneWidget);
  });

  testWidgets('주소·소개가 렌더되고 세 액션 콜백이 각각 불린다', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceDetailSheet(
            name: '사직 돼지국밥',
            categoryLabel: '맛집',
            address: '부산 동래구 사직로',
            description: '경기 전 든든한 한 그릇.',
            onOpenMap: () => tapped.add('map'),
            onDirections: () => tapped.add('directions'),
            onShare: () => tapped.add('share'),
          ),
        ),
      ),
    );

    expect(find.text('맛집 · 부산 동래구 사직로'), findsOneWidget);
    expect(find.text('경기 전 든든한 한 그릇.'), findsOneWidget);

    await tester.tap(find.text('지도에서 보기'));
    await tester.tap(find.text('길안내'));
    await tester.tap(find.text('공유'));
    expect(tapped, ['map', 'directions', 'share']);
  });
}
