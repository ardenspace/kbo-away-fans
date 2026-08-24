import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';

void main() {
  testWidgets('앱 루트 위젯이 렌더된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KboAwayFansApp()));

    expect(find.byType(KboAwayFansApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
