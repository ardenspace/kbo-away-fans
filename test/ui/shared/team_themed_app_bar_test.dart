/// TeamThemedAppBar 위젯 테스트 — 팀 맥락이 있으면 팀 색을, 없으면 팔레트
/// 기본색을 쓰는 앱바. 색을 고르는 자리가 화면마다 복제되지 않게 하는 것이 목적.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/ui/shared/team_theme_scope.dart';
import 'package:kbo_away_fans/ui/shared/team_themed_app_bar.dart';

Widget host(PreferredSizeWidget appBar) =>
    MaterialApp(home: Scaffold(appBar: appBar));

AppBar renderedBar(WidgetTester tester) =>
    tester.widget<AppBar>(find.byType(AppBar));

void main() {
  testWidgets('팀 스코프 밖에서는 팔레트 기본색으로 렌더한다', (tester) async {
    await tester.pumpWidget(host(const TeamThemedAppBar(title: 'KBO 원정러')));

    expect(tester.takeException(), isNull);
    expect(find.text('KBO 원정러'), findsOneWidget);
    final bar = renderedBar(tester);
    expect(bar.backgroundColor, ColorTokens.surface);
    expect(bar.foregroundColor, ColorTokens.textPrimary);
  });

  testWidgets('팀 스코프 안에서는 대표색 몸통 + onPrimary 전경색', (tester) async {
    const theme = TeamThemes.kia;
    await tester.pumpWidget(
      MaterialApp(
        home: TeamThemeScope(
          theme: theme,
          child: const Scaffold(appBar: TeamThemedAppBar(title: '광주 원정')),
        ),
      ),
    );

    final bar = renderedBar(tester);
    expect(bar.backgroundColor, theme.primary);
    expect(bar.foregroundColor, theme.onPrimary);
    final title = tester.widget<Text>(find.text('광주 원정'));
    expect(title.style!.color, theme.onPrimary);
  });

  testWidgets('actions 를 그대로 실어 준다', (tester) async {
    await tester.pumpWidget(
      host(
        const TeamThemedAppBar(
          title: '홈',
          actions: [Icon(Icons.swap_horiz_rounded)],
        ),
      ),
    );

    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
  });
}
