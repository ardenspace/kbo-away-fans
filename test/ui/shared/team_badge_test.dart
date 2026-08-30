/// TeamBadge 위젯 테스트 — 엠블럼 없이 팀을 나타내는 표시의 계약:
/// 약칭 글자가 식별을 맡고, 대표색과 보조색이 그것을 거든다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/ui/shared/team_badge.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// 배지가 실제로 칠한 색들 — 중첩 Container 의 순서에 기대지 않는다.
Set<Color?> paintedColors(WidgetTester tester) =>
    tester.widgetList<Container>(find.byType(Container)).map((c) => c.color).toSet();

TextStyle badgeTextStyle(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!;

void main() {
  testWidgets('약칭을 렌더하고 대표색·보조색을 모두 칠한다', (tester) async {
    const theme = TeamThemes.lotte;
    await tester.pumpWidget(
      host(const TeamBadge(shortName: '롯데', theme: theme)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('롯데'), findsOneWidget);
    expect(paintedColors(tester), containsAll(<Color>[theme.primary, theme.secondary]));
  });

  testWidgets('글자는 대표색 위에 올리는 onPrimary 색으로 쓴다', (tester) async {
    const theme = TeamThemes.ssg;
    await tester.pumpWidget(
      host(const TeamBadge(shortName: 'SSG', theme: theme)),
    );

    expect(badgeTextStyle(tester, 'SSG').color, theme.onPrimary);
  });

  testWidgets('대표색이 같은 두 팀도 보조색이 달라 서로 구분된다', (tester) async {
    // SSG(#CE0E2D)와 KIA(#EA0029)는 대표색이 거의 같다. 보조색이 갈라 준다.
    await tester.pumpWidget(
      host(const TeamBadge(shortName: 'SSG', theme: TeamThemes.ssg)),
    );
    final ssgColors = paintedColors(tester);

    await tester.pumpWidget(
      host(const TeamBadge(shortName: 'KIA', theme: TeamThemes.kia)),
    );
    final kiaColors = paintedColors(tester);

    expect(ssgColors, isNot(equals(kiaColors)));
    expect(ssgColors, contains(TeamThemes.ssg.secondary));
    expect(kiaColors, contains(TeamThemes.kia.secondary));
  });

  testWidgets('compact 는 기본보다 작은 글자로 렌더한다', (tester) async {
    await tester.pumpWidget(
      host(const TeamBadge(shortName: '한화', theme: TeamThemes.hanwha)),
    );
    final regular = badgeTextStyle(tester, '한화').fontSize!;

    await tester.pumpWidget(
      host(const TeamBadge(
        shortName: '한화',
        theme: TeamThemes.hanwha,
        compact: true,
      )),
    );
    final compact = badgeTextStyle(tester, '한화').fontSize!;

    expect(compact, lessThan(regular));
  });

  testWidgets('내용에 맞춰 폭이 줄어든다 (문장 안에 끼울 수 있다)', (tester) async {
    await tester.pumpWidget(
      host(const Row(
        mainAxisSize: MainAxisSize.min,
        children: [TeamBadge(shortName: 'LG', theme: TeamThemes.lg)],
      )),
    );

    expect(tester.takeException(), isNull);
    final width = tester.getSize(find.byType(TeamBadge)).width;
    expect(width, lessThan(tester.getSize(find.byType(Scaffold)).width));
  });
}
