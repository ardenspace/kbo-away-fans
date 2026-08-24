import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';

void main() {
  testWidgets('PlaceCard가 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlaceCard(
            name: '사직 돼지국밥',
            categoryLabel: '맛집',
            shoutoutSource: '@busan_foodie',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('사직 돼지국밥'), findsOneWidget);
    expect(find.text('@busan_foodie'), findsOneWidget);
  });
}
