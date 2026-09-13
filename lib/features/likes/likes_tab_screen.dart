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
import '../../ui/shared/empty_state_notice.dart';
import '../../ui/shared/map_links.dart';
import '../../ui/shared/place_card.dart';
import '../../ui/shared/place_detail_sheet.dart';
import '../../ui/shared/place_like_wiring.dart';
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
///   갈라 각자의 얼굴([ContentFallback] vs [EmptyStateNotice])을 보여준다
///   (decisions.md 의 supersede 결정).
/// - **이 화면은 분석 이벤트를 남기지 않는다 — 누락이 아니라 의도다.**
///   `StadiumPlacesScreen` 은 시트를 열 때 `logPlaceTap`, 지도로 갈 때
///   `logMapOpen` 을 남기지만, `lib/analytics/analytics.dart` 가 정의한 성공
///   지표는 "추천 탭 → 지도 진입" 하나뿐이고 그 이벤트의 파라미터는
///   `stadium_id`·`category` 뿐이라 어느 탭에서 눌렀는지 가릴 칸이 없다. 이
///   화면이 같은 이름으로 같은 이벤트를 쏘면 "추천에서 왔다"와 "좋아요
///   목록에서 왔다"는 서로 다른 두 퍼널이 한 지표에 섞여, 그 지표가 정작
///   무엇을 재는지 알 수 없게 된다. 그래서 이 파일은 `analytics.dart` 를
///   import 하지 않는다(2026-09-04 [S]).
/// - 콘텐츠에서 사라진 좋아요 장소는 [groupLikedPlaces] 가 조용히 걸러낸다.
/// - **목록의 [PlaceCard] 는 장소 id 로 키를 받는다.** 같은 카테고리 안에서
///   앞 카드의 좋아요를 풀면 그 카드가 목록에서 빠지며 뒤 카드가 한 칸
///   당겨지는데, 키가 없으면 Flutter 가 자리로 위젯을 짝지어 뒤 카드의
///   element 가 앞 카드의(막 꺼진) 지역 상태를 물려받는다(3.2 [LikeButton]
///   의 `didUpdateWidget` 은 `liked` 값이 실제로 달라질 때만 지역 상태를
///   따라가므로, 자리로 짝지어진 새 위젯의 `liked` 가 우연히 이전 값과 같으면
///   갱신되지 않는다). 장소 id 키가 그 오짝을 막는다
///   (`test/features/likes/likes_tab_seam_probe_test.dart`).
class LikesTabScreen extends ConsumerWidget {
  const LikesTabScreen({super.key});

  /// 좋아요 목록을 못 읽은 자리의 안내 제목.
  static const String loadFailureTitle = '좋아요 목록을 불러오지 못했어요';

  /// 진짜로 하나도 없는 자리의 안내 제목 — 위와 다른 문구라야 두 상태가
  /// 갈린다는 사실이 화면에서도 드러난다.
  static const String emptyTitle = '아직 좋아요한 장소가 없어요';

  /// 빈 상태의 설명 한 줄.
  static const String emptyMessage = '추천 탭에서 마음에 드는 곳에 하트를 눌러보세요.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedPlaceIdsProvider);
    final placesAsync = ref.watch(placesProvider);
    final placesDoc = contentDataOf(placesAsync);

    return Scaffold(
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
    // 이 검사가 아래 로딩 검사보다 **앞에** 있는 것은 순서 실수가 아니다:
    // 사람이 재시도 버튼을 누른 동안(`invalidate` 직후 `hasError` 와
    // `isLoading` 이 함께 참인 창)에도 이 화면은 실패 얼굴을 그대로 유지한다
    // — 그 창에서 스피너로 바꿔치기하면 실패→로딩→(다시 실패 또는 성공)로
    // 화면이 한 번 더 깜빡인다.
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

    final likedIds = likedAsync.value!;
    final grouped = groupLikedPlaces(placesDoc.places, likedIds);
    if (grouped.isEmpty) {
      return const EmptyStateNotice(
        title: LikesTabScreen.emptyTitle,
        message: LikesTabScreen.emptyMessage,
      );
    }

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
              style: TextTokens.onSurface(context, TextTokens.sectionTitle),
            ),
          ),
          for (final place in entry.value) ...[
            PlaceCard(
              // 장소 id 로 키를 준다 — 해제로 목록이 줄어 뒤 카드가 한 칸
              // 당겨질 때 자리가 아니라 정체성으로 짝지어지게 한다(클래스
              // 문서의 "목록의 PlaceCard 는 장소 id 로 키를 받는다" 참조).
              key: ValueKey('likes-place-${place.id}'),
              name: place.name,
              categoryLabel: categoryLabelOf(place.category),
              shoutoutSource: place.shoutout,
              onTap: () => _showDetailSheet(context, ref, place),
              liked: likedIds.contains(place.id),
              onLikeChanged: (liked) => togglePlaceLike(ref, place, liked),
              onLikeFailed: (error) => notifyPlaceLikeFailed(context),
            ),
            const SizedBox(height: SpaceTokens.md),
          ],
        ],
      ],
    );
  }

  /// 장소 상세 시트 — 추천 탭(`StadiumPlacesScreen`)과 같은 진입점을 그대로
  /// 잇는다(acceptance: "항목을 탭하면 기존 장소 상세 시트로 이어진다").
  void _showDetailSheet(BuildContext context, WidgetRef ref, Place place) {
    final stadium = contentDataOf(
      ref.read(stadiumsProvider),
    )?.byId(place.stadiumId);
    final liked =
        ref.read(likedPlaceIdsProvider).value?.contains(place.id) ?? true;
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
      liked: liked,
      onLikeChanged: (liked) => togglePlaceLike(ref, place, liked),
      onLikeFailed: (error) => notifyPlaceLikeFailed(context),
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
