/// TeamThemedAppBar 위젯 테스트 — 목적지 팀 맥락과 무관하게 앱 루트의
/// AppVisualTheme 역할색을 쓰는 앱바.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/ui/shared/team_theme_scope.dart';
import 'package:kbo_away_fans/ui/shared/team_themed_app_bar.dart';

final visual = AppVisualTheme.resolve(
  favoriteTeamId: null,
  defaultFamily: AppThemeFamily.a,
  brightness: Brightness.dark,
);

Widget host(PreferredSizeWidget appBar) => MaterialApp(
  theme: visual.toThemeData(),
  home: Scaffold(appBar: appBar),
);

AppBar renderedBar(WidgetTester tester) =>
    tester.widget<AppBar>(find.byType(AppBar));

void main() {
  testWidgets('팀 스코프 밖에서는 AppVisualTheme 앱바 역할로 렌더한다', (tester) async {
    await tester.pumpWidget(host(const TeamThemedAppBar(title: 'KBO 원정러')));

    expect(tester.takeException(), isNull);
    expect(find.text('KBO 원정러'), findsOneWidget);
    final bar = renderedBar(tester);
    expect(bar.backgroundColor, visual.background);
    expect(bar.foregroundColor, visual.textPrimary);
  });

  testWidgets('팀 스코프 안에서도 AppVisualTheme 역할색을 유지한다', (tester) async {
    const theme = TeamThemes.kia;
    await tester.pumpWidget(
      MaterialApp(
        theme: visual.toThemeData(),
        home: TeamThemeScope(
          theme: theme,
          child: const Scaffold(appBar: TeamThemedAppBar(title: '광주 원정')),
        ),
      ),
    );

    final bar = renderedBar(tester);
    expect(bar.backgroundColor, visual.background);
    expect(bar.foregroundColor, visual.textPrimary);
    final title = tester.widget<Text>(find.text('광주 원정'));
    expect(title.style!.color, visual.textPrimary);
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
