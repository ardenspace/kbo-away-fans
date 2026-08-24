/// Step 3.1 필터 단위 테스트 — 구장 id 필터 정확성,
/// 카테고리+실내 조합 필터, 빈 결과 상태.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/places/place_filter.dart';

Place place({
  required String id,
  required String stadium,
  required PlaceCategory category,
  bool indoor = true,
  String? shoutout,
}) {
  return Place(
    id: id,
    stadiumId: stadium,
    name: id,
    category: category,
    indoor: indoor,
    source: 'curated',
    lat: 37.5,
    lng: 127.0,
    shoutout: shoutout,
  );
}

void main() {
  final roster = [
    place(id: 'jamsil-gukbap', stadium: 'jamsil', category: PlaceCategory.food),
    place(
      id: 'jamsil-pocha',
      stadium: 'jamsil',
      category: PlaceCategory.food,
      indoor: false,
    ),
    place(id: 'jamsil-cafe', stadium: 'jamsil', category: PlaceCategory.cafe),
    place(
      id: 'jamsil-hangang',
      stadium: 'jamsil',
      category: PlaceCategory.activity,
      indoor: false,
    ),
    place(id: 'sajik-gukbap', stadium: 'sajik', category: PlaceCategory.food),
    place(
      id: 'sajik-tower',
      stadium: 'sajik',
      category: PlaceCategory.landmark,
      indoor: false,
    ),
  ];

  group('구장 id 필터', () {
    test('해당 구장의 장소만, 문서 순서 그대로 남는다', () {
      final result = filterPlaces(roster, stadiumId: 'jamsil');

      expect(
        result.map((p) => p.id).toList(),
        ['jamsil-gukbap', 'jamsil-pocha', 'jamsil-cafe', 'jamsil-hangang'],
      );
      expect(result.every((p) => p.stadiumId == 'jamsil'), isTrue);
    });

    test('다른 구장의 장소는 섞이지 않는다', () {
      final result = filterPlaces(roster, stadiumId: 'sajik');

      expect(result.map((p) => p.id).toList(), ['sajik-gukbap', 'sajik-tower']);
    });
  });

  group('카테고리 + 실내 조합 필터', () {
    test('카테고리만: 그 카테고리 장소만 남는다', () {
      final result = filterPlaces(
        roster,
        stadiumId: 'jamsil',
        category: PlaceCategory.food,
      );

      expect(result.map((p) => p.id).toList(),
          ['jamsil-gukbap', 'jamsil-pocha']);
    });

    test('실내만: 실외 장소가 빠진다', () {
      final result =
          filterPlaces(roster, stadiumId: 'jamsil', indoorOnly: true);

      expect(
          result.map((p) => p.id).toList(), ['jamsil-gukbap', 'jamsil-cafe']);
    });

    test('카테고리 + 실내 조합: 두 조건을 모두 만족해야 남는다', () {
      final result = filterPlaces(
        roster,
        stadiumId: 'jamsil',
        category: PlaceCategory.food,
        indoorOnly: true,
      );

      expect(result.map((p) => p.id).toList(), ['jamsil-gukbap']);
    });
  });

  group('빈 결과', () {
    test('장소 0건 카테고리는 빈 목록이다', () {
      final result = filterPlaces(
        roster,
        stadiumId: 'jamsil',
        category: PlaceCategory.escapeRoom,
      );

      expect(result, isEmpty);
    });

    test('조합 필터로 전부 걸러져도 빈 목록이다 (실외뿐인 카테고리 + 실내만)', () {
      final result = filterPlaces(
        roster,
        stadiumId: 'jamsil',
        category: PlaceCategory.activity,
        indoorOnly: true,
      );

      expect(result, isEmpty);
    });

    test('장소가 하나도 없는 구장은 빈 목록이다', () {
      final result = filterPlaces(roster, stadiumId: 'gocheok');

      expect(result, isEmpty);
    });
  });
}
