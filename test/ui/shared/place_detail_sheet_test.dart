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
    expect(find.text('공유'), findsOneWidget);
  });
}
