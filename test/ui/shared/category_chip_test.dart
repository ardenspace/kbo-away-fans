import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/category_chip.dart';

void main() {
  testWidgets('CategoryChip이 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              CategoryChip(label: '맛집', selected: true),
              CategoryChip(label: '카페'),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('맛집'), findsOneWidget);
    expect(find.text('카페'), findsOneWidget);
  });
}
