/// DdayHeader 위젯 테스트 — step 2.3 boundary: 세 상태("오늘"/D-day/빈 상태)
/// 모두 렌더. 상대팀 배지는 팀 테마 스코프가 있을 때만 붙는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/ui/shared/dday_header.dart';
import 'package:kbo_away_fans/ui/shared/team_badge.dart';
import 'package:kbo_away_fans/ui/shared/team_theme_scope.dart';
import 'package:kbo_away_fans/ui/shared/weather_backdrop.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// 상대팀(= 그 경기 홈팀) 테마 스코프 안에 놓는다 — 홈 화면과 같은 배치.
Widget hostThemed(Widget child, {TeamTheme theme = TeamThemes.lotte}) =>
    host(TeamThemeScope(theme: theme, child: child));

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

  testWidgets('상대팀 약칭을 주면 그 팀 테마의 배지를 함께 렌더한다', (tester) async {
    await tester.pumpWidget(
      hostThemed(
        const DdayHeader(
          dDay: 3,
          matchLabel: '8/30 (토) 사직야구장 · 18:30',
          opponentShortName: '롯데',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final badge = tester.widget<TeamBadge>(find.byType(TeamBadge));
    expect(badge.shortName, '롯데');
    expect(badge.theme, TeamThemes.lotte);
    // 문장 옆에 끼는 자리라 작은 판본을 쓴다.
    expect(badge.compact, isTrue);
  });

  testWidgets('상대팀 약칭이 없으면 배지를 렌더하지 않는다', (tester) async {
    await tester.pumpWidget(
      hostThemed(
        const DdayHeader(dDay: 3, matchLabel: '8/30 (토) 사직야구장 · 18:30'),
      ),
    );

    expect(find.byType(TeamBadge), findsNothing);
  });

  testWidgets('팀 테마 스코프 밖이면 배지 없이 문구만 렌더한다', (tester) async {
    await tester.pumpWidget(
      host(
        const DdayHeader(
          dDay: 3,
          matchLabel: '8/30 (토) 사직야구장 · 18:30',
          opponentShortName: '롯데',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(TeamBadge), findsNothing);
    expect(find.text('8/30 (토) 사직야구장 · 18:30'), findsOneWidget);
  });

  testWidgets('모든 전역 테마의 헤더는 맑음·비 배경에서 큰 글자 대비를 유지한다', (tester) async {
    for (final teamId in <String?>[null, ...TeamThemes.byId.keys]) {
      for (final family in AppThemeFamily.values) {
        for (final brightness in Brightness.values) {
          final visual = AppVisualTheme.resolve(
            favoriteTeamId: teamId,
            defaultFamily: family,
            brightness: brightness,
          );
          for (final raining in [false, true]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: visual.toThemeData(),
                home: Scaffold(
                  body: WeatherBackdrop(
                    raining: raining,
                    child: const Column(
                      children: [
                        DdayHeader.empty(),
                        DdayHeader(dDay: 0, matchLabel: '오늘 경기'),
                        DdayHeader(dDay: 3, matchLabel: '다음 경기'),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(seconds: 1));
            final backdrop = tester.widget<AnimatedContainer>(
              find.descendant(
                of: find.byType(WeatherBackdrop),
                matching: find.byType(AnimatedContainer),
              ),
            );
            final background = (backdrop.decoration! as BoxDecoration).color!;
            for (final label in ['남은 원정 경기가 없어요', '오늘', 'D-3']) {
              final foreground = tester
                  .widget<Text>(find.text(label))
                  .style!
                  .color!;
              final a = foreground.computeLuminance();
              final b = background.computeLuminance();
              final ratio = a >= b
                  ? (a + .05) / (b + .05)
                  : (b + .05) / (a + .05);
              expect(
                ratio,
                greaterThanOrEqualTo(3),
                reason: '$teamId $family $brightness rain=$raining $label',
              );
              expect(foreground, visual.backgroundAccent);
            }
          }
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('상대팀 스코프는 전역 제목 강조색을 덮지 않고 배지에만 적용된다', (tester) async {
    final visual = AppVisualTheme.resolve(
      favoriteTeamId: 'nc',
      defaultFamily: AppThemeFamily.a,
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: visual.toThemeData(),
        home: Scaffold(
          body: TeamThemeScope(
            theme: TeamThemes.lotte,
            child: const DdayHeader(
              dDay: 3,
              matchLabel: '사직야구장',
              opponentShortName: '롯데',
            ),
          ),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('D-3')).style!.color,
      visual.backgroundAccent,
    );
    expect(
      tester.widget<TeamBadge>(find.byType(TeamBadge)).theme,
      TeamThemes.lotte,
    );
  });
}
