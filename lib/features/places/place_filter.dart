/// 추천 장소 필터 (step 3.1) — 순수 로직.
///
/// 화면(추천 목록·미리보기)은 이 함수 하나로 필터한다.
/// 정렬은 places.json 문서 순서(큐레이션 순서)를 그대로 유지한다.
library;

import '../../content/models.dart';

/// [places] 를 구장·카테고리·실내 조건으로 필터한다.
///
/// - [stadiumId]: 필수 — 해당 구장의 장소만 남긴다.
/// - [category]: null 이면 전체 카테고리.
/// - [indoorOnly]: true 면 실내([Place.indoor]) 장소만 (우천 플랜B).
///
/// 결과 순서는 [places] 의 순서(큐레이션 순서)를 보존한다.
List<Place> filterPlaces(
  List<Place> places, {
  required String stadiumId,
  PlaceCategory? category,
  bool indoorOnly = false,
}) {
  return places
      .where((p) =>
          p.stadiumId == stadiumId &&
          (category == null || p.category == category) &&
          (!indoorOnly || p.indoor))
      .toList();
}
