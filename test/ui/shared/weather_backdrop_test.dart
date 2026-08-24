import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/weather_backdrop.dart';

void main() {
  testWidgets('WeatherBackdrop이 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WeatherBackdrop(
          raining: true,
          child: Center(child: Text('콘텐츠')),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('콘텐츠'), findsOneWidget);
  });
}
