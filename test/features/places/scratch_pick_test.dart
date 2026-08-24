/// Step 3.2 긁기 랜덤 선택 단위 테스트 — 선택이 항상 현재 필터 풀 안,
/// 재선택 시 다른 장소 가능, 빈 풀은 null(카드 비노출 근거).
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/places/place_filter.dart';
import 'package:kbo_away_fans/features/places/scratch_pick.dart';

Place place({
  required String id,
  required String stadium,
  required PlaceCategory category,
  bool indoor = true,
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
    shoutout: null,
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
  ];

  group('현재 필터 풀 안에서만 선택', () {
    test('구장 필터 풀: 어떤 시드로도 잠실 밖 장소는 나오지 않는다', () {
      final pool = filterPlaces(roster, stadiumId: 'jamsil');
      final poolIds = pool.map((p) => p.id).toSet();

      for (var seed = 0; seed < 50; seed++) {
        final pick = pickScratchPlace(pool, Random(seed));
        expect(pick, isNotNull);
        expect(poolIds.contains(pick!.id), isTrue);
      }
    });

    test('카테고리+실내 조합 풀: 조건을 만족하는 장소만 나온다', () {
      final pool = filterPlaces(
        roster,
        stadiumId: 'jamsil',
        category: PlaceCategory.food,
        indoorOnly: true,
      );

      for (var seed = 0; seed < 50; seed++) {
        expect(pickScratchPlace(pool, Random(seed))!.id, 'jamsil-gukbap');
      }
    });
  });

  group('재선택', () {
    test('같은 풀에서 다시 뽑으면 다른 장소가 나올 수 있다', () {
      final pool = filterPlaces(roster, stadiumId: 'jamsil');
      final random = Random(1);

      final picked = <String>{
        for (var i = 0; i < 20; i++) pickScratchPlace(pool, random)!.id,
      };

      expect(picked.length, greaterThan(1));
      expect(picked.every((id) => pool.any((p) => p.id == id)), isTrue);
    });
  });

  group('빈 풀', () {
    test('빈 풀이면 null — 화면은 카드를 렌더하지 않는다', () {
      expect(pickScratchPlace(const [], Random(0)), isNull);
    });

    test('필터로 전부 걸러진 풀도 null 이다', () {
      final pool = filterPlaces(roster, stadiumId: 'gocheok');
      expect(pickScratchPlace(pool, Random(0)), isNull);
    });
  });
}
