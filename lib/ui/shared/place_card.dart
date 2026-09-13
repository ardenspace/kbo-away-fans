import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import 'like_button.dart';

/// 추천 장소 카드 (샤라웃 출처 뱃지 포함, 좋아요 토글 포함).
///
/// 추천 목록·미리보기 어디서든 이 카드로 렌더한다. 좋아요 버튼은
/// [onLikeChanged] 를 줄 때만 뜬다 — 없으면 자리 자체를 두지 않는다
/// ([ContentFallback] 이 `onRetry` 없을 때 버튼을 두지 않는 것과 같은 규칙).
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.name,
    required this.categoryLabel,
    this.shoutoutSource,
    this.onTap,
    this.liked = false,
    this.onLikeChanged,
    this.onLikeFailed,
  });

  /// 장소 이름.
  final String name;

  /// 카테고리 표시 문구 (예: '맛집').
  final String categoryLabel;

  /// 샤라웃 출처 (예: '@busan_foodie'). null이면 뱃지 생략.
  final String? shoutoutSource;

  /// 카드 탭 콜백 (보통 PlaceDetailSheet 열기).
  final VoidCallback? onTap;

  /// 지금까지 알려진 좋아요 상태.
  final bool liked;

  /// 좋아요 상태를 서버에 쓴다 — 주지 않으면 좋아요 버튼 자체가 없다.
  final Future<void> Function(bool liked)? onLikeChanged;

  /// 좋아요 쓰기 실패를 화면에 알리는 경로.
  final void Function(Object error)? onLikeFailed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final source = shoutoutSource;
    final onLikeChanged = this.onLikeChanged;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(RadiusTokens.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        child: Padding(
          padding: const EdgeInsets.all(SpaceTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextTokens.onSurface(
                        context,
                        TextTokens.sectionTitle,
                      ),
                    ),
                  ),
                  if (onLikeChanged != null)
                    LikeButton(
                      liked: liked,
                      onChanged: onLikeChanged,
                      onFailed: onLikeFailed,
                    ),
                ],
              ),
              const SizedBox(height: SpaceTokens.sm),
              Row(
                children: [
                  Text(
                    categoryLabel,
                    style: TextTokens.onSurfaceMuted(
                      context,
                      TextTokens.supporting,
                    ),
                  ),
                  if (source != null) ...[
                    const SizedBox(width: SpaceTokens.sm),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpaceTokens.sm,
                          vertical: SpaceTokens.xs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            RadiusTokens.pill,
                          ),
                        ),
                        child: Text(
                          source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextTokens.onSurfaceMuted(
                            context,
                            TextTokens.caption,
                          ),
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
