/// DdayHeader 위젯 테스트 — step 2.3 boundary: 세 상태("오늘"/D-day/빈 상태)
/// 모두 렌더. 상대팀 배지는 팀 테마 스코프가 있을 때만 붙는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/ui/shared/dday_header.dart';
import 'package:kbo_away_fans/ui/shared/team_badge.dart';
import 'package:kbo_away_fans/ui/shared/team_theme_scope.dart';

Widget host(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

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
}
