/// DdayHeader 위젯 테스트 — step 2.3 boundary: 세 상태("오늘"/D-day/빈 상태)
/// 모두 렌더.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/dday_header.dart';

Widget host(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('D-day 상태: 남은 일수와 경기 정보를 렌더한다', (tester) async {
    await tester.pumpWidget(
      host(const DdayHeader(dDay: 3, matchLabel: '8/30 (토) 사직 · vs 롯데')),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('D-3'), findsOneWidget);
    expect(find.text('8/30 (토) 사직 · vs 롯데'), findsOneWidget);
  });

  testWidgets('"오늘" 상태: dDay 0이면 오늘 표시를 렌더한다', (tester) async {
    await tester.pumpWidget(
      host(const DdayHeader(dDay: 0, matchLabel: '8/25 (화) 잠실 · vs LG')),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('오늘'), findsOneWidget);
    expect(find.text('8/25 (화) 잠실 · vs LG'), findsOneWidget);
  });

  testWidgets('빈 상태: 남은 일정이 없으면 명시적 빈 상태를 렌더한다', (tester) async {
    await tester.pumpWidget(host(const DdayHeader.empty()));

    expect(tester.takeException(), isNull);
    expect(find.text('남은 원정 경기가 없어요'), findsOneWidget);
  });
}
