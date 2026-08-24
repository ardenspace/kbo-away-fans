import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 추천 장소 카드 (샤라웃 출처 뱃지 포함).
///
/// 추천 목록·미리보기 어디서든 이 카드로 렌더한다.
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.name,
    required this.categoryLabel,
    this.shoutoutSource,
    this.onTap,
  });

  /// 장소 이름.
  final String name;

  /// 카테고리 표시 문구 (예: '맛집').
  final String categoryLabel;

  /// 샤라웃 출처 (예: '@busan_foodie'). null이면 뱃지 생략.
  final String? shoutoutSource;

  /// 카드 탭 콜백 (보통 PlaceDetailSheet 열기).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final source = shoutoutSource;

    return Material(
      color: ColorTokens.surface,
      borderRadius: BorderRadius.circular(RadiusTokens.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        child: Padding(
          padding: const EdgeInsets.all(SpaceTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: TypeTokens.fontFamily,
                  fontSize: TypeTokens.heading,
                  fontWeight: TypeTokens.weightBold,
                  color: ColorTokens.textPrimary,
                ),
              ),
              const SizedBox(height: SpaceTokens.sm),
              Row(
                children: [
                  Text(
                    categoryLabel,
                    style: const TextStyle(
                      fontFamily: TypeTokens.fontFamily,
                      fontSize: TypeTokens.label,
                      fontWeight: TypeTokens.weightMedium,
                      color: ColorTokens.textSecondary,
                    ),
                  ),
                  if (source != null) ...[
                    const SizedBox(width: SpaceTokens.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpaceTokens.sm,
                        vertical: SpaceTokens.xs,
                      ),
                      decoration: BoxDecoration(
                        color: ColorTokens.surfaceDim,
                        borderRadius:
                            BorderRadius.circular(RadiusTokens.pill),
                      ),
                      child: Text(
                        source,
                        style: const TextStyle(
                          fontFamily: TypeTokens.fontFamily,
                          fontSize: TypeTokens.caption,
                          fontWeight: TypeTokens.weightMedium,
                          color: ColorTokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
