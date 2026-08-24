import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// [StadiumPicker]에 표시할 구장 하나.
@immutable
class StadiumPickerItem {
  const StadiumPickerItem({required this.id, required this.label});

  /// 구장 안정 id (stadiums.json의 id).
  final String id;

  /// 표시 이름 (예: '사직').
  final String label;
}

/// 구장 골라 구경하기 진입 (탐색 모드) — 경기 없는 날·탐색 진입점.
class StadiumPicker extends StatelessWidget {
  const StadiumPicker({
    super.key,
    required this.stadiums,
    this.onSelected,
  });

  /// 표시할 구장 목록 (콘텐츠의 구장 9곳).
  final List<StadiumPickerItem> stadiums;

  /// 구장 선택 콜백 (선택한 구장 id 전달).
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '구장 골라 구경하기',
          style: TextStyle(
            fontFamily: TypeTokens.fontFamily,
            fontSize: TypeTokens.heading,
            fontWeight: TypeTokens.weightExtraBold,
            color: ColorTokens.textPrimary,
          ),
        ),
        const SizedBox(height: SpaceTokens.md),
        Wrap(
          spacing: SpaceTokens.sm,
          runSpacing: SpaceTokens.sm,
          children: [
            for (final stadium in stadiums)
              GestureDetector(
                onTap: () => onSelected?.call(stadium.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpaceTokens.md,
                    vertical: SpaceTokens.sm,
                  ),
                  decoration: BoxDecoration(
                    color: ColorTokens.surface,
                    border: Border.all(color: ColorTokens.outline),
                    borderRadius: BorderRadius.circular(RadiusTokens.pill),
                  ),
                  child: Text(
                    stadium.label,
                    style: const TextStyle(
                      fontFamily: TypeTokens.fontFamily,
                      fontSize: TypeTokens.label,
                      fontWeight: TypeTokens.weightBold,
                      color: ColorTokens.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
