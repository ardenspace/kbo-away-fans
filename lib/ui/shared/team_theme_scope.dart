import 'package:flutter/material.dart';

import '../../design/team_themes.dart';

/// 팀 테마 토큰을 하위 트리에 주입하는 테마 전환 지점.
///
/// 구장/팀 맥락이 있는 화면 전체를 이 위젯으로 감싼다. 하위 위젯은
/// [TeamThemeScope.of] / [maybeOf]로 현재 팀 테마를 읽는다.
class TeamThemeScope extends InheritedWidget {
  const TeamThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  /// 팀 id([TeamThemes.byId]의 키, common.defs teamId 10종)로 감싸는 편의 생성자.
  factory TeamThemeScope.forTeam({
    Key? key,
    required String teamId,
    required Widget child,
  }) {
    final theme = TeamThemes.byId[teamId];
    assert(theme != null, '알 수 없는 teamId: $teamId');
    return TeamThemeScope(key: key, theme: theme!, child: child);
  }

  /// 주입할 팀 테마.
  final TeamTheme theme;

  /// 가장 가까운 상위 스코프의 팀 테마. 스코프 밖이면 null.
  static TeamTheme? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TeamThemeScope>()
        ?.theme;
  }

  /// 가장 가까운 상위 스코프의 팀 테마. 스코프 밖에서 부르면 assert 실패.
  static TeamTheme of(BuildContext context) {
    final theme = maybeOf(context);
    assert(theme != null, 'TeamThemeScope가 상위 트리에 없습니다');
    return theme!;
  }

  @override
  bool updateShouldNotify(TeamThemeScope oldWidget) =>
      theme != oldWidget.theme;
}
