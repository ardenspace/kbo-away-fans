import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 장소 상세 바텀시트 (지도 진입·길안내·OS 공유 진입점). 장소 카드 탭 시 띄운다.
class PlaceDetailSheet extends StatelessWidget {
  const PlaceDetailSheet({
    super.key,
    required this.name,
    required this.categoryLabel,
    this.address,
    this.description,
    this.onOpenMap,
    this.onDirections,
    this.onShare,
  });

  /// 장소 이름.
  final String name;

  /// 카테고리 표시 문구.
  final String categoryLabel;

  /// 주소 (없으면 카테고리만 표시).
  final String? address;

  /// 소개 문구 (없으면 생략).
  final String? description;

  /// '지도에서 보기' 탭 콜백 (StadiumMapView 지도 화면 진입).
  final VoidCallback? onOpenMap;

  /// '길안내' 탭 콜백 (네이버지도 앱/웹 딥링크로 이탈).
  final VoidCallback? onDirections;

  /// OS 공유 시트 진입 콜백.
  final VoidCallback? onShare;

  /// 표준 진입점 — 모달 바텀시트로 띄운다.
  static Future<void> show(
    BuildContext context, {
    required String name,
    required String categoryLabel,
    String? address,
    String? description,
    VoidCallback? onOpenMap,
    VoidCallback? onDirections,
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
        address: address,
        description: description,
        onOpenMap: onOpenMap,
        onDirections: onDirections,
        onShare: onShare,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final address = this.address;
    final description = this.description;

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
            address == null ? categoryLabel : '$categoryLabel · $address',
            style: const TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: TypeTokens.label,
              fontWeight: TypeTokens.weightMedium,
              color: ColorTokens.textSecondary,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: SpaceTokens.sm),
            Text(
              description,
              style: const TextStyle(
                fontFamily: TypeTokens.fontFamily,
                fontSize: TypeTokens.body,
                fontWeight: TypeTokens.weightRegular,
                color: ColorTokens.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: SpaceTokens.lg),
          Row(
            children: [
              TextButton(
                onPressed: onOpenMap,
                child: const Text('지도에서 보기'),
              ),
              const SizedBox(width: SpaceTokens.sm),
              TextButton(
                onPressed: onDirections,
                child: const Text('길안내'),
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
