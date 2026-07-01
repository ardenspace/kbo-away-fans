/// KBO 구장. DB `stadiums` 행과 1:1. 가이드 화면에 쓰는 표시 필드만.
class Stadium {
  final String id;
  final String name;
  final String city;
  final String address;
  final String? parkingInfo;
  final String? seatingInfo;
  final String? routeInfo;
  final String? convenienceInfo;

  const Stadium({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    this.parkingInfo,
    this.seatingInfo,
    this.routeInfo,
    this.convenienceInfo,
  });

  factory Stadium.fromJson(Map<String, dynamic> json) => Stadium(
    id: json['id'] as String,
    name: json['name'] as String,
    city: json['city'] as String,
    address: json['address'] as String,
    parkingInfo: json['parking_info'] as String?,
    seatingInfo: json['seating_info'] as String?,
    routeInfo: json['route_info'] as String?,
    convenienceInfo: json['convenience_info'] as String?,
  );
}
