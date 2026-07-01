/// 맛집 pick 근거. DB `restaurants.pick_type` CHECK 와 일치.
enum PickType {
  player('선수 PICK'),
  fan('팬 PICK'),
  editor('에디터 PICK');

  const PickType(this.label);
  final String label;

  static PickType parse(String raw) => switch (raw) {
    'player' => PickType.player,
    'fan' => PickType.fan,
    _ => PickType.editor,
  };
}

/// 원정 구장 근처 맛집. DB `restaurants` 행과 1:1.
class Restaurant {
  final String id;
  final String name;
  final PickType pickType;
  final String? category;
  final String? description;
  final String sourceUrl;

  const Restaurant({
    required this.id,
    required this.name,
    required this.pickType,
    this.category,
    this.description,
    required this.sourceUrl,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) => Restaurant(
    id: json['id'] as String,
    name: json['name'] as String,
    pickType: PickType.parse(json['pick_type'] as String),
    category: json['category'] as String?,
    description: json['description'] as String?,
    sourceUrl: json['source_url'] as String,
  );
}
