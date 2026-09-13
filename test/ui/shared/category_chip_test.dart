import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/ui/shared/category_chip.dart';
import 'package:kbo_away_fans/ui/shared/team_theme_scope.dart';

void main() {
  testWidgets('CategoryChip이 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              CategoryChip(label: '맛집', selected: true),
              CategoryChip(label: '카페'),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('맛집'), findsOneWidget);
    expect(find.text('카페'), findsOneWidget);
  });

  testWidgets('목적지 팀 스코프 안에서도 전역 accent를 우선한다', (tester) async {
    final visual = AppVisualTheme.resolve(
      favoriteTeamId: null,
      defaultFamily: AppThemeFamily.a,
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: visual.toThemeData(),
        home: TeamThemeScope(
          theme: TeamThemes.lotte,
          child: const Scaffold(
            body: CategoryChip(label: '전체', selected: true),
          ),
        ),
      ),
    );

    final chip = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    final decoration = chip.decoration! as BoxDecoration;
    expect(decoration.color, visual.primary);
    expect(decoration.border!.top.color, visual.primary);
    expect(tester.widget<Text>(find.text('전체')).style!.color, visual.onPrimary);
  });
}
