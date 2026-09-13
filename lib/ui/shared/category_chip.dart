import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/tokens.dart';
import 'team_theme_scope.dart';

/// 맛집/방탈출/카페 등 카테고리 필터 칩 (추천 목록 필터).
///
/// 팀 테마 스코프 안이면 선택 색이 팀 대표색을 따른다.
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
    final team = TeamThemeScope.maybeOf(context);
    final selectedBg =
        team?.primary ?? visual?.primary ?? material.colorScheme.primary;
    final selectedFg =
        team?.onPrimary ?? visual?.onPrimary ?? material.colorScheme.onPrimary;
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
