import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/tokens.dart';

/// 경기 전·취소 화면에서 쓰는 약한 테마 그라데이션 티켓.
///
/// 정상 상태의 끝점은 primary 70% + secondary 30%다. [cancelled]이면 팀색보다
/// 취소 의미가 먼저 읽히도록 양 끝 모두 전역 danger 역할색에서 만든다.
class JourneyTicket extends StatelessWidget {
  const JourneyTicket({
    super.key,
    required this.child,
    this.cancelled = false,
    this.padding = const EdgeInsets.all(SpaceTokens.lg),
  });

  final Widget child;
  final bool cancelled;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<AppVisualTheme>()!;
    final startAccent = cancelled ? visual.danger : visual.primary;
    final endAccent = cancelled
        ? visual.danger
        : Color.lerp(
            visual.primary,
            visual.secondary,
            JourneyTokens.ticketSecondaryBlend,
          )!;
    final colors = <Color>[
      Color.alphaBlend(
        startAccent.withValues(alpha: JourneyTokens.surfaceTintOpacity),
        visual.surface,
      ),
      Color.alphaBlend(
        endAccent.withValues(alpha: JourneyTokens.surfaceTintOpacity),
        visual.surface,
      ),
    ];

    return Semantics(
      container: true,
      label: cancelled ? '취소된 경기' : '원정 경기 티켓',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          border: Border.all(color: cancelled ? visual.danger : visual.outline),
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
