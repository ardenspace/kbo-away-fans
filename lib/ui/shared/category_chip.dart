import 'package:flutter/material.dart';

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
    final team = TeamThemeScope.maybeOf(context);
    final selectedBg = team?.primary ?? ColorTokens.textPrimary;
    final selectedFg = team?.onPrimary ?? ColorTokens.textInverse;

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
          color: selected ? selectedBg : ColorTokens.surface,
          border: Border.all(
            color: selected ? selectedBg : ColorTokens.outline,
          ),
          borderRadius: BorderRadius.circular(RadiusTokens.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: TypeTokens.fontFamily,
            fontSize: TypeTokens.label,
            fontWeight: TypeTokens.weightBold,
            color: selected ? selectedFg : ColorTokens.textSecondary,
          ),
        ),
      ),
    );
  }
}
