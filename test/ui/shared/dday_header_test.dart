import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/dday_header.dart';

void main() {
  testWidgets('DdayHeader가 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DdayHeader(dDay: 3, matchLabel: '8/30 (토) 사직 · vs 롯데'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('D-3'), findsOneWidget);
    expect(find.text('8/30 (토) 사직 · vs 롯데'), findsOneWidget);
  });
}
