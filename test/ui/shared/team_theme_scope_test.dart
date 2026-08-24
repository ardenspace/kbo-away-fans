import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/ui/shared/team_theme_scope.dart';

void main() {
  testWidgets('TeamThemeScope가 렌더되고 하위에서 테마를 읽는다', (tester) async {
    TeamTheme? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: TeamThemeScope.forTeam(
          teamId: 'lotte',
          child: Builder(
            builder: (context) {
              seen = TeamThemeScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(seen, same(TeamThemes.lotte));
  });
}
