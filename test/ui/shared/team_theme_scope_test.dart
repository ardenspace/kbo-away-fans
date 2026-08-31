import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/design/tokens.dart';
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

  group('테마 전환 연출', () {
    /// 스코프가 **지금** 하위에 주고 있는 테마.
    ///
    /// 하위 위젯이 마지막으로 본 값을 캡처해 두면 안 된다. 전환 마지막
    /// 프레임의 목표 테마는 직전 보간 색과 값이 같아 `updateShouldNotify` 가
    /// 재알림을 걸지 않고(의도된 절약), 그러면 하위 위젯은 다시 빌드되지 않아
    /// 캡처값이 한 프레임 뒤처진 사본에 머문다.
    TeamTheme provided(WidgetTester tester) =>
        TeamThemeScope.of(tester.element(find.byType(SizedBox)));

    /// 팀 id를 바깥에서 갈아끼울 수 있는 호스트.
    ///
    /// 스코프가 트리의 **같은 자리**에 남아 있어야 전환이 성립하므로,
    /// 라우트를 새로 밀지 않고 teamId만 바꾼다.
    Future<void> host(
      WidgetTester tester, {
      required String initialTeamId,
      required void Function(void Function(String)) exposeSetter,
    }) async {
      var teamId = initialTeamId;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              exposeSetter((next) => setState(() => teamId = next));
              return TeamThemeScope.forTeam(
                teamId: teamId,
                child: const SizedBox.shrink(),
              );
            },
          ),
        ),
      );
    }

    testWidgets('테마가 바뀌면 themeShift 동안 색을 보간해 건너간다', (tester) async {
      late void Function(String) setTeam;
      await host(
        tester,
        initialTeamId: 'lotte',
        exposeSetter: (setter) => setTeam = setter,
      );

      expect(
        provided(tester),
        same(TeamThemes.lotte),
        reason: '첫 렌더는 보간 없이 목표 테마',
      );

      setTeam('hanwha');
      await tester.pump();
      expect(
        provided(tester).primary,
        isNot(equals(TeamThemes.hanwha.primary)),
        reason: '전환 시작 프레임에 목표 색으로 튀지 않는다',
      );

      await tester.pump(MotionTokens.themeShift ~/ 2);
      expect(
        provided(tester).primary,
        isNot(equals(TeamThemes.lotte.primary)),
        reason: '중간 프레임은 출발 색을 떠나 있다',
      );
      expect(
        provided(tester).primary,
        isNot(equals(TeamThemes.hanwha.primary)),
        reason: '중간 프레임은 아직 목표 색에 닿지 않았다',
      );

      await tester.pumpAndSettle();
      expect(
        provided(tester),
        same(TeamThemes.hanwha),
        reason: '전환이 끝나면 목표 테마 인스턴스를 그대로 내려보낸다',
      );
    });

    testWidgets('전환 도중 목표가 또 바뀌면 직전 중간색에서 이어 간다', (tester) async {
      late void Function(String) setTeam;
      await host(
        tester,
        initialTeamId: 'lotte',
        exposeSetter: (setter) => setTeam = setter,
      );

      setTeam('hanwha');
      await tester.pump();
      await tester.pump(MotionTokens.themeShift ~/ 2);
      final midway = provided(tester).primary;

      setTeam('samsung');
      await tester.pump();
      expect(
        provided(tester).primary,
        equals(midway),
        reason: '이어받는 첫 프레임은 직전 중간색 — 이전 목표색으로 튀면 깜빡인다',
      );

      await tester.pumpAndSettle();
      expect(provided(tester), same(TeamThemes.samsung));
    });

    testWidgets('같은 테마로 다시 세팅하면 전환이 시작되지 않는다', (tester) async {
      late void Function(String) setTeam;
      await host(
        tester,
        initialTeamId: 'kia',
        exposeSetter: (setter) => setTeam = setter,
      );

      setTeam('kia');
      await tester.pump();

      expect(provided(tester), same(TeamThemes.kia));
      // 애니메이션이 돌면 프레임이 예약되어 pumpAndSettle 이 시간을 소모한다.
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
