import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../backend/user_data.dart';
import '../../content/content_loader.dart' show ContentResult;
import '../../content/content_providers.dart';
import '../../content/models.dart';
import '../../design/tokens.dart';
import '../../ui/shared/category_labels.dart';
import '../../ui/shared/content_fallback.dart';
import '../../ui/shared/map_links.dart';
import '../../ui/shared/place_card.dart';
import '../../ui/shared/place_detail_sheet.dart';
import '../places/place_map_screen.dart';
import 'liked_places.dart';

/// 좋아요 내역 탭 (step 3.3) — 추천과 같은 카테고리 체계로 내가 누른 장소만
/// 보여준다. `lib/features/home/main_tabs_root.dart` 의 좋아요 탭 자리를
/// 채운다.
///
/// - 좋아요 상태의 단일 출처는 [likedPlaceIdsProvider] 이고, 이름·카테고리는
///   서버가 아니라 콘텐츠([placesProvider])에서 온다 — [groupLikedPlaces] 가
///   둘을 맞춘다. 그래서 이 탭이 있다고 서버 읽기가 늘지 않는다(좋아요 id
///   집합은 이미 세션당 한 번만 읽는 캐시된 값이다).
/// - **탭 뿌리가 provider 를 직접 구독한다**([lib/features/home/main_tabs_root.dart]
///   의 `_HomeTab` 이 세운 규칙과 같다) — `MainTabScaffold` 의 탭별 Navigator 는
///   route 를 한 번만 만들기 때문에, 생성자 인자로 좋아요 집합을 받으면 그
///   값이 얼어붙어 "해제 시 즉시 사라진다"가 성립하지 않는다.
/// - **"못 읽었다"와 "하나도 없다"는 다른 화면이다.** [likedPlaceIdsProvider]
///   는 3.2 의 결정대로 읽기 실패를 삼켜 추천 목록에서는 빈 집합으로 fail-open
///   하지만(추천 목록 전체를 막지 않기 위해), 이 탭은 그 fail-open 결과가
///   화면의 전부가 되는 자리라 오류와 빈 목록을 구분해야 한다. 그래서 이
///   provider 는 이제 읽기 실패를 삼키지 않고 `AsyncError` 로 흘려보내도록
///   고쳤다(`lib/backend/user_data.dart` 의 [LikedPlaceIds.build]) — 다른
///   소비자(카드·상세 시트)는 여전히 `likedPlaceIdsProvider.value ?? const {}`
///   로 읽어 오류를 빈 집합으로 접어 두므로 그쪽 동작은 그대로다. 이 화면만
///   `AsyncValue` 를 그대로 보고 오류(못 읽음)와 빈 데이터(하나도 없음)를
///   갈라 각자의 얼굴([ContentFallback] vs [_emptyState])을 보여준다
///   (decisions.md 의 supersede 결정).
/// - 콘텐츠에서 사라진 좋아요 장소는 [groupLikedPlaces] 가 조용히 걸러낸다.
class LikesTabScreen extends ConsumerWidget {
  const LikesTabScreen({super.key});

  /// 좋아요 목록을 못 읽은 자리의 안내 제목.
  static const String loadFailureTitle = '좋아요 목록을 불러오지 못했어요';

  /// 진짜로 하나도 없는 자리의 안내 제목 — 위와 다른 문구라야 두 상태가
  /// 갈린다는 사실이 화면에서도 드러난다.
  static const String emptyTitle = '아직 좋아요한 장소가 없어요';

  /// 빈 상태의 설명 한 줄.
  static const String emptyMessage = '추천 탭에서 마음에 드는 곳에 하트를 눌러보세요.';

  /// 좋아요 쓰기 실패 안내 — `StadiumPlacesScreen.likeFailureNotice` 와 같은
  /// 모양(정적 문구 + 스낵바)을 그대로 따른다.
  static const String likeFailureNotice = '좋아요를 반영하지 못했어요. 잠시 뒤 다시 시도해 주세요.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedPlaceIdsProvider);
    final placesAsync = ref.watch(placesProvider);
    final placesDoc = contentDataOf(placesAsync);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(title: const Text('좋아요')),
      body: _body(context, ref, likedAsync, placesAsync, placesDoc),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Set<String>> likedAsync,
    AsyncValue<ContentResult<PlacesDocument>> placesAsync,
    PlacesDocument? placesDoc,
  ) {
    // 좋아요 자체를 못 읽은 자리 — "하나도 없다"와 다른 얼굴 + 재시도.
    if (likedAsync.hasError) {
      return ContentFallback(
        loading: false,
        title: loadFailureTitle,
        onRetry: () => ref.invalidate(likedPlaceIdsProvider),
      );
    }
    // 콘텐츠(장소 이름·카테고리)를 못 얻은 자리 — 다른 화면과 같은 재시도 경로.
    if (placesDoc == null) {
      return ContentFallback(
        loading: placesAsync is AsyncLoading,
        onRetry: placesAsync is AsyncLoading
            ? null
            : () => invalidateContent(ref),
      );
    }
    // 여기까지 왔는데 값이 아직 없으면(콜드 스타트의 세션 확정 대기) 로딩.
    if (!likedAsync.hasValue) {
      return const ContentFallback(loading: true);
    }

    final grouped = groupLikedPlaces(placesDoc.places, likedAsync.value!);
    if (grouped.isEmpty) return _emptyState();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SpaceTokens.lg,
        SpaceTokens.sm,
        SpaceTokens.lg,
        SpaceTokens.xxl,
      ),
      children: [
        for (final entry in grouped) ...[
          Padding(
            key: ValueKey('likes-category-${entry.key.name}'),
            padding: const EdgeInsets.symmetric(vertical: SpaceTokens.sm),
            child: Text(
              categoryLabelOf(entry.key),
              style: TextTokens.sectionTitle,
            ),
          ),
          for (final place in entry.value) ...[
            PlaceCard(
              name: place.name,
              categoryLabel: categoryLabelOf(place.category),
              shoutoutSource: place.shoutout,
              onTap: () => _showDetailSheet(context, ref, place),
              liked: true,
              onLikeChanged: (liked) => _toggleLike(ref, place, liked),
              onLikeFailed: (error) => _handleLikeFailed(context),
            ),
            const SizedBox(height: SpaceTokens.md),
          ],
        ],
      ],
    );
  }

  /// 진짜로 좋아요가 하나도 없는 자리의 명시적 빈 상태.
  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.all(SpaceTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(LikesTabScreen.emptyTitle, style: TextTokens.sectionTitle),
          SizedBox(height: SpaceTokens.sm),
          Text(LikesTabScreen.emptyMessage, style: TextTokens.bodyMuted),
        ],
      ),
    );
  }

  /// 장소 상세 시트 — 추천 탭(`StadiumPlacesScreen`)과 같은 진입점을 그대로
  /// 잇는다(acceptance: "항목을 탭하면 기존 장소 상세 시트로 이어진다").
  void _showDetailSheet(BuildContext context, WidgetRef ref, Place place) {
    final stadium = contentDataOf(
      ref.read(stadiumsProvider),
    )?.byId(place.stadiumId);
    PlaceDetailSheet.show(
      context,
      name: place.name,
      categoryLabel: categoryLabelOf(place.category),
      address: place.address,
      description: place.description,
      onOpenMap: () => _openMap(context, place, stadium),
      onDirections: () =>
          launchNaverMapRoute(name: place.name, lat: place.lat, lng: place.lng),
      onShare: () => _share(place),
      liked: true,
      onLikeChanged: (liked) => _toggleLike(ref, place, liked),
      onLikeFailed: (error) => _handleLikeFailed(context),
    );
  }

  /// 좋아요를 누르거나(true) 취소한다(false) — [likedPlaceIdsProvider] 하나만
  /// 고친다. 이 위젯이 그 provider 를 직접 구독하므로, 성공한 뒤 집합이
  /// 바뀌면 이 화면이 다시 그려져 해제한 장소가 목록에서 즉시 빠진다.
  Future<void> _toggleLike(WidgetRef ref, Place place, bool liked) {
    return ref
        .read(likedPlaceIdsProvider.notifier)
        .toggle(
          place.id,
          LikeWrite(
            placeId: place.id,
            stadiumId: place.stadiumId,
            category: place.category,
          ),
          liked,
        );
  }

  /// 좋아요 쓰기 실패 안내 — [LikeButton] 이 되돌린 뒤에 부른다.
  void _handleLikeFailed(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text(LikesTabScreen.likeFailureNotice)),
    );
  }

  /// 시트를 닫고 앱 내 지도 화면으로 진입한다 (`StadiumPlacesScreen._openMap`
  /// 과 같은 진입점).
  void _openMap(BuildContext context, Place place, Stadium? stadium) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaceMapScreen(place: place, stadium: stadium),
      ),
    );
  }

  /// OS 공유 시트 — 장소 이름 + 지도 링크 페이로드.
  Future<void> _share(Place place) {
    return SharePlus.instance.share(
      ShareParams(
        text: buildMapSharePayload(
          name: place.name,
          categoryLabel: categoryLabelOf(place.category),
        ),
      ),
    );
  }
}
