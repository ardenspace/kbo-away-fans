import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/tokens.dart';

/// 앱 루트의 전역 시각 테마에서 배경·전경색을 꺼내 오는 앱바.
///
/// 목적지 팀 스코프 안에서도 앱 컨트롤은 [AppVisualTheme] 역할색을 유지한다.
/// 목적지·상대팀 색은 배지처럼 경기·구장 맥락을 설명하는 보조 요소가 맡는다.
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
    final material = Theme.of(context);
    final visual = material.extension<AppVisualTheme>();
    final background =
        visual?.background ??
        material.appBarTheme.backgroundColor ??
        material.colorScheme.surface;
    final foreground =
        visual?.textPrimary ??
        material.appBarTheme.foregroundColor ??
        material.colorScheme.onSurface;

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
