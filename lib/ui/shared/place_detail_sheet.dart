import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import 'like_button.dart';

/// 장소 상세 바텀시트 (지도 진입·길안내·OS 공유 진입점, 좋아요 토글 포함).
///
/// 장소 카드 탭 시 띄운다. 좋아요 버튼은 [onLikeChanged] 를 줄 때만 뜬다.
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
    this.liked = false,
    this.onLikeChanged,
    this.onLikeFailed,
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

  /// 지금까지 알려진 좋아요 상태.
  final bool liked;

  /// 좋아요 상태를 서버에 쓴다 — 주지 않으면 좋아요 버튼 자체가 없다.
  final Future<void> Function(bool liked)? onLikeChanged;

  /// 좋아요 쓰기 실패를 화면에 알리는 경로.
  final void Function(Object error)? onLikeFailed;

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
    bool liked = false,
    Future<void> Function(bool liked)? onLikeChanged,
    void Function(Object error)? onLikeFailed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
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
        liked: liked,
        onLikeChanged: onLikeChanged,
        onLikeFailed: onLikeFailed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final address = this.address;
    final description = this.description;
    final onLikeChanged = this.onLikeChanged;

    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: TextTokens.title)),
              if (onLikeChanged != null)
                LikeButton(
                  liked: liked,
                  onChanged: onLikeChanged,
                  onFailed: onLikeFailed,
                ),
            ],
          ),
          const SizedBox(height: SpaceTokens.xs),
          Text(
            address == null ? categoryLabel : '$categoryLabel · $address',
            style: TextTokens.supporting,
          ),
          if (description != null) ...[
            const SizedBox(height: SpaceTokens.sm),
            Text(description, style: TextTokens.body),
          ],
          const SizedBox(height: SpaceTokens.lg),
          Row(
            children: [
              TextButton(onPressed: onOpenMap, child: const Text('지도에서 보기')),
              const SizedBox(width: SpaceTokens.sm),
              TextButton(onPressed: onDirections, child: const Text('길안내')),
              const SizedBox(width: SpaceTokens.sm),
              TextButton(onPressed: onShare, child: const Text('공유')),
            ],
          ),
        ],
      ),
    );
  }
}
