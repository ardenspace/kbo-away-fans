import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import 'team_theme_scope.dart';

/// 팀 테마에서 배경·전경색을 꺼내 오는 앱바.
///
/// 색을 고르는 규칙(팀이 있으면 대표색 몸통 + `onPrimary` 전경, 없으면 팔레트
/// 기본색)이 화면마다 복제되어 있던 것을 한 자리로 모은 것이다. 복제되어
/// 있으면 팀 색이 바뀌는 자리를 하나 빠뜨려도 눈에 띄지 않는다.
///
/// [TeamThemeScope] 를 `maybeOf` 로 읽으므로 스코프 밖(로그인·설정처럼 팀
/// 맥락이 없는 화면)에서도 그대로 쓸 수 있다.
class TeamThemedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TeamThemedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  /// 앱바 제목.
  final String title;

  /// 오른쪽 진입점들 (설정·바꾸기 등).
  final List<Widget>? actions;

  /// 왼쪽 자리. 비우면 Navigator 가 뒤로가기를 채운다.
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = TeamThemeScope.maybeOf(context);
    final background = theme?.primary ?? ColorTokens.surface;
    final foreground = theme?.onPrimary ?? ColorTokens.textPrimary;

    return AppBar(
      backgroundColor: background,
      foregroundColor: foreground,
      leading: leading,
      actions: actions,
      title: Text(
        title,
        style: TextTokens.appBarTitle.copyWith(color: foreground),
      ),
    );
  }
}
