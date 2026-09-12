import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/tokens.dart';

/// 앱 전역 테마를 따르는 표준 카드 표면.
///
/// 색을 인자로 받지 않는다. 앱 루트의 [AppVisualTheme]가 최종 색의 유일한
/// 소유자이며, [tinted]는 그 역할색을 약하게 합성할지만 정한다.
class ThemedSurface extends StatelessWidget {
  const ThemedSurface({
    super.key,
    required this.child,
    this.tinted = false,
    this.padding = const EdgeInsets.all(SpaceTokens.lg),
  });

  final Widget child;
  final bool tinted;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<AppVisualTheme>()!;
    final color = tinted
        ? Color.alphaBlend(
            visual.primary.withValues(alpha: JourneyTokens.surfaceTintOpacity),
            visual.surface,
          )
        : visual.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: visual.outline),
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
