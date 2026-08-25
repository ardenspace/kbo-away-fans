/// Step 4.1 WeatherBackdrop 위젯 테스트 — 비 상태 주입 → 비 레이어 렌더,
/// 맑음 주입 → 비 레이어 없음 (boundary).
///
/// RainLayer 는 repeat 애니메이션이라 pumpAndSettle 을 쓰지 않고
/// 고정 pump 로 프레임을 진행한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/weather_backdrop.dart';

Widget backdrop({required bool raining}) {
  return MaterialApp(
    home: WeatherBackdrop(
      raining: raining,
      child: const Center(child: Text('콘텐츠')),
    ),
  );
}

void main() {
  testWidgets('비 상태 주입 → 비 레이어(RainLayer)가 렌더된다', (tester) async {
    await tester.pumpWidget(backdrop(raining: true));

    expect(find.byType(RainLayer), findsOneWidget);
    expect(find.text('콘텐츠'), findsOneWidget);

    // 애니메이션 프레임이 예외 없이 진행된다.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
    expect(find.byType(RainLayer), findsOneWidget);
  });

  testWidgets('맑음 주입 → 비 레이어가 없다', (tester) async {
    await tester.pumpWidget(backdrop(raining: false));
    await tester.pumpAndSettle();

    expect(find.byType(RainLayer), findsNothing);
    expect(find.text('콘텐츠'), findsOneWidget);
  });

  testWidgets('비가 그치면 비 레이어가 트리에서 사라진다', (tester) async {
    await tester.pumpWidget(backdrop(raining: true));
    expect(find.byType(RainLayer), findsOneWidget);

    await tester.pumpWidget(backdrop(raining: false));
    // 배경색 전환(weatherShift)만 남으므로 settle 가능하다.
    await tester.pumpAndSettle();
    expect(find.byType(RainLayer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
