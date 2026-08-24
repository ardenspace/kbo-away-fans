import '../../content/models.dart';

/// places.schema category enum ↔ 화면 한국어 문구의 **단일** 매핑.
///
/// 카테고리 문구가 필요한 모든 곳(필터 칩, PlaceCard, 상세 시트,
/// 미리보기)은 이 맵을 쓴다 — 화면마다 사본을 만들지 않는다.
/// enum 멤버가 늘면 이 맵도 같은 커밋에서 갱신한다
/// (아래 [categoryLabelOf] 의 완전성 assert 가 테스트에서 잡는다).
const Map<PlaceCategory, String> kCategoryLabels = {
  PlaceCategory.food: '맛집',
  PlaceCategory.cafe: '카페',
  PlaceCategory.escapeRoom: '방탈출',
  PlaceCategory.activity: '액티비티',
  PlaceCategory.landmark: '명소',
};

/// [category] 의 표시 문구 — 매핑 누락은 프로그래밍 오류로 즉시 드러낸다.
String categoryLabelOf(PlaceCategory category) {
  final label = kCategoryLabels[category];
  assert(label != null, 'kCategoryLabels 에 ${category.name} 항목이 없음');
  return label ?? category.contractValue;
}
