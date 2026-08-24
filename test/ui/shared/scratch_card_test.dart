import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/scratch_card.dart';

void main() {
  testWidgets('ScratchCard가 렌더되고 탭하면 공개된다', (tester) async {
    var revealed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScratchCard(
            hiddenLabel: '광안리 방탈출',
            onRevealed: () => revealed = true,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('오늘 뭐하지? 긁어 보기'), findsOneWidget);

    await tester.tap(find.byType(ScratchCard));
    await tester.pumpAndSettle();

    expect(revealed, isTrue);
    expect(find.text('광안리 방탈출'), findsOneWidget);
  });
}
