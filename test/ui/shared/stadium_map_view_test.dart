import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/stadium_map_view.dart';

void main() {
  testWidgets('StadiumMapView가 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StadiumMapView(stadiumId: 'sajik'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(StadiumMapView), findsOneWidget);
  });
}
