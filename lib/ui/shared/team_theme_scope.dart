import 'package:flutter/material.dart';

import '../../design/team_themes.dart';
import '../../design/tokens.dart';

/// 팀 테마 토큰을 하위 트리에 주입하는 테마 전환 지점.
///
/// 구장/팀 맥락이 있는 화면 전체를 이 위젯으로 감싼다. 하위 위젯은
/// [TeamThemeScope.of] / [maybeOf]로 현재 팀 테마를 읽는다.
///
/// 같은 자리에서 [theme] 이 바뀌면 네 색을 [MotionTokens.themeShift] 동안
/// 보간해서 건너간다 (응원 팀을 바꾸거나, 다음 원정 경기가 다른 홈팀 구장으로
/// 넘어가는 경우). 첫 렌더와 전환이 끝난 뒤에는 목표 테마 인스턴스를 그대로
/// 내려보내므로, 정지 상태에서는 이 위젯이 없던 때와 동일하게 동작한다.
///
/// 화면을 새로 밀어 올리며 진입하는 경우(구장 상세·지도 화면)는 스코프가
/// 그 자리에서 처음 마운트되므로 보간이 걸리지 않는다. 라우트 전환 연출과
/// 색 전환이 겹쳐 서로를 방해하지 않게 두는 편이 낫다는 판단이다.
class TeamThemeScope extends StatefulWidget {
  const TeamThemeScope({
    super.key,
    required this.theme,
    required this.child,
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

  /// 주입할 팀 테마 (전환의 목표값).
  final TeamTheme theme;

  /// 이 테마를 물려받을 하위 트리.
  final Widget child;

  /// 가장 가까운 상위 스코프의 팀 테마. 스코프 밖이면 null.
  ///
  /// 전환 중에는 보간된 중간 색이 나온다.
  static TeamTheme? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_TeamThemeInherited>()
        ?.theme;
  }

  /// 가장 가까운 상위 스코프의 팀 테마. 스코프 밖에서 부르면 assert 실패.
  static TeamTheme of(BuildContext context) {
    final theme = maybeOf(context);
    assert(theme != null, 'TeamThemeScope가 상위 트리에 없습니다');
    return theme!;
  }

  @override
  State<TeamThemeScope> createState() => _TeamThemeScopeState();
}

class _TeamThemeScopeState extends State<TeamThemeScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _progress;

  /// 전환이 출발한 테마. 아직 한 번도 바뀌지 않았으면 null.
  TeamTheme? _from;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MotionTokens.themeShift,
      vsync: this,
    );
    // 색 보간에는 되돌아오지 않는 커브를 쓴다. 탄성 커브(bouncy·emphasized)는
    // 진행률이 1을 넘었다가 돌아오므로, 목표 색을 지나쳤다 되돌아오는 것처럼
    // 보여서 팀 색이 잠깐 엉뚱한 색으로 읽힌다.
    _progress = CurvedAnimation(
      parent: _controller,
      curve: MotionTokens.standard,
    );
  }

  @override
  void didUpdateWidget(TeamThemeScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.theme == oldWidget.theme) return;
    // 전환 도중에 목표가 또 바뀌면, 지금 화면에 떠 있는 중간색에서 이어 간다.
    // 이전 목표색으로 튀었다가 다시 출발하면 깜빡이는 것처럼 보인다.
    _from = _displayed(oldWidget.theme);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// 지금 그려야 할 테마.
  ///
  /// 전환 중이 아니면 [target] 인스턴스를 그대로 돌려준다. 정지 상태에서
  /// 굳이 같은 색의 사본을 만들지 않기 위한 것이다.
  ///
  /// 정지 판정에 [AnimationController.isAnimating] 을 쓰면 안 된다. 마지막
  /// 틱에서 티커가 멈춘 뒤로는 다시 빌드될 일이 없어서, 목표색과 값은 같지만
  /// 인스턴스는 다른 보간 사본이 트리에 그대로 남는다. 상태값(completed)은
  /// 그 마지막 틱의 알림 이전에 세팅되므로 같은 프레임에서 바로 읽힌다.
  TeamTheme _displayed(TeamTheme target) {
    final from = _from;
    if (from == null || _controller.isCompleted) return target;
    return TeamTheme.lerp(from, target, _progress.value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (context, child) => _TeamThemeInherited(
        theme: _displayed(widget.theme),
        child: child!,
      ),
    );
  }
}

/// 실제로 테마를 물려주는 InheritedWidget.
///
/// 바깥의 [TeamThemeScope] 가 전환 연출을 맡고, 이 위젯은 그 결과값을
/// 하위 트리에 꽂는 일만 한다.
class _TeamThemeInherited extends InheritedWidget {
  const _TeamThemeInherited({
    required this.theme,
    required super.child,
  });

  final TeamTheme theme;

  @override
  bool updateShouldNotify(_TeamThemeInherited oldWidget) =>
      theme != oldWidget.theme;
}
