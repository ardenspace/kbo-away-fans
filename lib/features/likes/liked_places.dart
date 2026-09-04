/// 좋아요 내역 그룹핑 (step 3.3) — 순수 로직.
///
/// 좋아요 상태의 단일 출처는 [likedPlaceIdsProvider]([lib/backend/user_data.dart])
/// 이고 거기서 오는 것은 장소 id 집합뿐이다. 이름·카테고리·구장은 서버가 아니라
/// 콘텐츠([Place])에 있으므로, 이 함수가 둘을 맞춰 화면이 그릴 목록을 만든다
/// (서버 읽기를 늘리지 않고 콘텐츠와 좋아요 id 를 맞추는 것이 이 탭의 일이라는
/// 결정).
library;

import '../../content/models.dart';

/// [likedIds] 에 속한 장소만 [places] 에서 골라 카테고리로 묶는다.
///
/// - **카테고리 순서는 [PlaceCategory.values] 순서** — 추천 탭의 카테고리 칩과
///   같은 순서라 두 화면의 카테고리 체계가 일치한다.
/// - 각 카테고리 안에서는 [places] 의 순서(콘텐츠 큐레이션 순서)를 그대로
///   보존한다 — [likedIds] 는 `Set` 이라 자체로는 순서를 보장하지 않는다.
/// - **[likedIds] 에는 있지만 [places] 에는 없는 id는 조용히 걸러진다.**
///   콘텐츠가 갱신되며 장소가 사라지면 생길 수 있는 상태인데, 좋아요 문서에는
///   이름·카테고리가 없어 그 항목을 무엇으로도 그릴 수 없다 — 깨진 카드를
///   보여주거나 원본 없이 자리만 차지하는 것보다, 더 이상 존재하지 않는
///   장소는 목록에서 빠지는 편이 사람에게 맞는 사실이다.
/// - 멤버가 하나도 없는 카테고리는 결과에 들지 않는다(빈 섹션을 그리지 않는다).
List<MapEntry<PlaceCategory, List<Place>>> groupLikedPlaces(
  List<Place> places,
  Set<String> likedIds,
) {
  final grouped = <PlaceCategory, List<Place>>{};
  for (final place in places) {
    if (!likedIds.contains(place.id)) continue;
    grouped.putIfAbsent(place.category, () => []).add(place);
  }
  return [
    for (final category in PlaceCategory.values)
      if (grouped[category] case final members?) MapEntry(category, members),
  ];
}
