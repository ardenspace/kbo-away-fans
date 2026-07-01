/// 우천 대비 플랜B 장소(실내 코스 등). DB `planb_places` 행과 1:1.
class PlanbPlace {
  final String id;
  final String name;
  final String category;
  final String? description;
  final String sourceUrl;

  const PlanbPlace({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.sourceUrl,
  });

  factory PlanbPlace.fromJson(Map<String, dynamic> json) => PlanbPlace(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    description: json['description'] as String?,
    sourceUrl: json['source_url'] as String,
  );
}
