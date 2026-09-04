/// Step 3.3 — [groupLikedPlaces] 순수 로직 시험.
///
/// 재는 갈래:
///  1) 카테고리 순서는 [PlaceCategory.values] 순서(추천 탭 칩 순서)다.
///  2) 카테고리 안에서는 콘텐츠(장소 목록) 순서를 보존한다.
///  3) 콘텐츠에 없는 좋아요 id(사라진 장소)는 조용히 걸러진다.
///  4) 멤버가 없는 카테고리는 결과에 들지 않는다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/likes/liked_places.dart';

Place _place({
  required String id,
  required PlaceCategory category,
  String stadiumId = 'jamsil',
}) {
  return Place(
    id: id,
    stadiumId: stadiumId,
    name: id,
    category: category,
    indoor: true,
    source: 'curated',
    lat: 37.5,
    lng: 127.0,
  );
}

void main() {
  test('좋아요가 하나도 없으면 빈 목록', () {
    final places = [_place(id: 'a', category: PlaceCategory.food)];

    final grouped = groupLikedPlaces(places, const {});

    expect(grouped, isEmpty);
  });

  test('카테고리 순서는 PlaceCategory.values 순서 — 콘텐츠 등장 순서와 무관하다', () {
    // 콘텐츠 등장 순서는 landmark → food 이지만(역순), 결과는 enum 순서인
    // food → landmark 여야 한다.
    final places = [
      _place(id: 'tower', category: PlaceCategory.landmark),
      _place(id: 'gukbap', category: PlaceCategory.food),
    ];

    final grouped = groupLikedPlaces(places, {'tower', 'gukbap'});

    expect(grouped.map((e) => e.key).toList(), [
      PlaceCategory.food,
      PlaceCategory.landmark,
    ]);
  });

  test('카테고리 안에서는 콘텐츠 순서를 그대로 보존한다', () {
    final places = [
      _place(id: 'gukbap-1', category: PlaceCategory.food),
      _place(id: 'gukbap-2', category: PlaceCategory.food),
      _place(id: 'gukbap-3', category: PlaceCategory.food),
    ];

    final grouped = groupLikedPlaces(places, {
      'gukbap-3',
      'gukbap-1',
      'gukbap-2',
    });

    expect(grouped, hasLength(1));
    expect(grouped.single.value.map((p) => p.id).toList(), [
      'gukbap-1',
      'gukbap-2',
      'gukbap-3',
    ]);
  });

  test('콘텐츠에 없는 좋아요 id(사라진 장소)는 조용히 걸러진다', () {
    final places = [_place(id: 'still-here', category: PlaceCategory.cafe)];

    final grouped = groupLikedPlaces(places, {'still-here', 'gone-place'});

    expect(grouped, hasLength(1));
    expect(grouped.single.value.map((p) => p.id).toList(), ['still-here']);
  });

  test('좋아요 id 전부가 콘텐츠에서 사라졌으면 결과는 빈 목록이다', () {
    final places = [_place(id: 'still-here', category: PlaceCategory.cafe)];

    final grouped = groupLikedPlaces(places, {'gone-place'});

    expect(grouped, isEmpty);
  });

  test('멤버가 없는 카테고리는 결과에 들지 않는다', () {
    final places = [
      _place(id: 'a', category: PlaceCategory.food),
      _place(id: 'b', category: PlaceCategory.cafe),
    ];

    final grouped = groupLikedPlaces(places, {'a'});

    expect(grouped.map((e) => e.key).toList(), [PlaceCategory.food]);
  });
}
