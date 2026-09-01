/// StampBadge 위젯 테스트 — 칸 하나의 세 모습(빈 상태·획득·등급)이
/// 서로 갈리는지, 그리고 등급 표현이 토큰의 링 값을 그대로 소비하는지.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/ui/shared/stamp_badge.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

/// 칸 몸통을 칠한 장식 — 배지가 실제로 그린 원.
BoxDecoration bodyDecoration(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(of: find.byType(StampBadge), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

/// 등급 링을 그리는 painter — 빈 칸이면 null.
BadgeTierRingPainter? ringPainter(WidgetTester tester) {
  final painters = tester
      .widgetList<CustomPaint>(
        find.descendant(of: find.byType(StampBadge), matching: find.byType(CustomPaint)),
      )
      .map((paint) => paint.foregroundPainter)
      .whereType<BadgeTierRingPainter>();
  return painters.isEmpty ? null : painters.first;
}

void main() {
  testWidgets('빈 상태 — 팀 색을 흐리게 깔고 테두리만 두르며 등급 링이 없다', (tester) async {
    const theme = TeamThemes.lg;
    await tester.pumpWidget(host(const StampBadge(theme: theme, stamps: 0, label: 'LG')));

    expect(tester.takeException(), isNull);
    final decoration = bodyDecoration(tester);
    expect(decoration.shape, BoxShape.circle);
    expect(
      decoration.color,
      theme.primary.withValues(alpha: BadgeTokens.emptyOpacity),
    );
    expect(decoration.border, isNotNull);
    expect(ringPainter(tester), isNull);
  });

  testWidgets('획득 — 몸통이 팀 대표색으로 꽉 차고 글자는 onPrimary 색', (tester) async {
    const theme = TeamThemes.lg;
    await tester.pumpWidget(host(const StampBadge(theme: theme, stamps: 1, label: 'LG')));

    final decoration = bodyDecoration(tester);
    expect(decoration.color, BadgeTierTokens.first.bodyColor(theme.primary));
    expect(decoration.border, isNull);
    expect(tester.widget<Text>(find.text('LG')).style!.color, theme.onPrimary);
  });

  testWidgets('등급 — 도장 개수의 등급 링을 토큰 값 그대로 그린다', (tester) async {
    for (final entry in <int, BadgeTier>{
      1: BadgeTier.first,
      3: BadgeTier.regular,
      10: BadgeTier.master,
    }.entries) {
      await tester.pumpWidget(
        host(StampBadge(theme: TeamThemes.hanwha, stamps: entry.key, label: '한화')),
      );
      final style = BadgeTierTokens.byTier[entry.value]!;
      final painter = ringPainter(tester);

      expect(painter, isNotNull, reason: '도장 ${entry.key}개는 등급 링이 있어야 한다');
      expect(painter!.layers, same(style.rings));
      expect(painter.inset, BadgeTokens.tierRingInset);
    }
  });

  testWidgets('세 등급의 링은 서로 다른 겹 수를 그린다 (색 없이도 갈린다)', (tester) async {
    final layerCounts = <int>[];
    for (final stamps in [1, 3, 10]) {
      await tester.pumpWidget(
        host(StampBadge(theme: TeamThemes.nc, stamps: stamps, label: 'NC')),
      );
      layerCounts.add(ringPainter(tester)!.layers.length);
    }

    expect(layerCounts.toSet().length, 3);
    expect(layerCounts, orderedEquals(<int>[...layerCounts]..sort()));
  });

  testWidgets('탭 콜백이 있으면 눌린다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(StampBadge(theme: TeamThemes.kt, stamps: 2, label: 'kt', onTap: () => taps++)),
    );

    await tester.tap(find.byType(StampBadge));
    await tester.pump();
    expect(taps, 1);
  });
}
