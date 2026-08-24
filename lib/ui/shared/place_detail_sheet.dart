import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 장소 상세 바텀시트 (지도 진입·OS 공유 진입점). 장소 카드 탭 시 띄운다.
class PlaceDetailSheet extends StatelessWidget {
  const PlaceDetailSheet({
    super.key,
    required this.name,
    required this.categoryLabel,
    this.onOpenMap,
    this.onShare,
  });

  /// 장소 이름.
  final String name;

  /// 카테고리 표시 문구.
  final String categoryLabel;

  /// '지도에서 보기' 탭 콜백 (StadiumMapView/딥링크 진입).
  final VoidCallback? onOpenMap;

  /// OS 공유 시트 진입 콜백.
  final VoidCallback? onShare;

  /// 표준 진입점 — 모달 바텀시트로 띄운다.
  static Future<void> show(
    BuildContext context, {
    required String name,
    required String categoryLabel,
    VoidCallback? onOpenMap,
    VoidCallback? onShare,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: ColorTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RadiusTokens.xl),
        ),
      ),
      builder: (context) => PlaceDetailSheet(
        name: name,
        categoryLabel: categoryLabel,
        onOpenMap: onOpenMap,
        onShare: onShare,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: TypeTokens.title,
              fontWeight: TypeTokens.weightExtraBold,
              color: ColorTokens.textPrimary,
            ),
          ),
          const SizedBox(height: SpaceTokens.xs),
          Text(
            categoryLabel,
            style: const TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: TypeTokens.label,
              fontWeight: TypeTokens.weightMedium,
              color: ColorTokens.textSecondary,
            ),
          ),
          const SizedBox(height: SpaceTokens.lg),
          Row(
            children: [
              TextButton(
                onPressed: onOpenMap,
                child: const Text('지도에서 보기'),
              ),
              const SizedBox(width: SpaceTokens.sm),
              TextButton(
                onPressed: onShare,
                child: const Text('공유'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
