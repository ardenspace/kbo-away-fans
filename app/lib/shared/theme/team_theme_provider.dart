import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'team_colors.dart';
import 'team_theme.dart';

part 'team_theme_provider.g.dart';

/// 현재 응원팀 abbr. `null` = 미선택(중립 테마).
///
/// task-010(응원팀 설정 UI)·task-009(프로필 영속화)에서 이 notifier 에 연결된다.
/// 지금은 런타임 상태만 들고 영속화는 하지 않는다.
@Riverpod(keepAlive: true)
class CurrentTeam extends _$CurrentTeam {
  @override
  String? build() => null;

  /// 응원팀 변경. `null` 이면 미선택(중립)으로 되돌린다.
  void select(String? abbr) => state = abbr;
}

/// 현재 팀에서 파생되는 앱 테마. 미선택이거나 알 수 없는 abbr 이면 중립 테마.
@riverpod
ThemeData teamTheme(Ref ref) {
  final abbr = ref.watch(currentTeamProvider);
  final colors = (abbr != null ? kTeamColors[abbr] : null) ?? kNeutralColors;
  return buildTeamTheme(colors);
}
