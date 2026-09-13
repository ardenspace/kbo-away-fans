import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/tokens.dart';

/// 맛집/방탈출/카페 등 카테고리 필터 칩 (추천 목록 필터).
///
/// 선택 색은 앱 루트의 [AppVisualTheme] accent를 따른다. 구장 route가 목적지
/// 팀의 테마 스코프로 감싸져 있어도 앱 컨트롤의 색 소유권은 바뀌지 않는다.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  /// 칩에 표시할 카테고리 문구.
  final String label;

  /// 선택(활성) 상태.
  final bool selected;

  /// 탭 콜백.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final material = Theme.of(context);
    final visual = material.extension<AppVisualTheme>();
    final selectedBg = visual?.primary ?? material.colorScheme.primary;
    final selectedFg = _readableSelectedForeground(
      background: selectedBg,
      preferred: visual?.onPrimary ?? material.colorScheme.onPrimary,
    );
    final surface = visual?.surface ?? material.colorScheme.surface;
    final outline = visual?.outline ?? material.colorScheme.outline;
    final muted =
        visual?.textSecondary ?? material.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: MotionTokens.fast,
        curve: MotionTokens.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: SpaceTokens.md,
          vertical: SpaceTokens.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? selectedBg : surface,
          border: Border.all(color: selected ? selectedBg : outline),
          borderRadius: BorderRadius.circular(RadiusTokens.pill),
        ),
        child: Text(
          label,
          style: TextTokens.label.copyWith(
            color: selected ? selectedFg : muted,
          ),
        ),
      ),
    );
  }
}

Color _readableSelectedForeground({
  required Color background,
  required Color preferred,
}) {
  if (_contrastRatio(preferred, background) >= 4.5) return preferred;
  return _contrastRatio(NeutralTokens.lightInk, background) >=
          _contrastRatio(NeutralTokens.darkInk, background)
      ? NeutralTokens.lightInk
      : NeutralTokens.darkInk;
}

double _contrastRatio(Color a, Color b) {
  final lighter = a.computeLuminance() >= b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
