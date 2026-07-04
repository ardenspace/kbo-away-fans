/// 스탬프 기능 데이터 모델 + repository 공용 에러 타입.
///
/// UI·도메인은 이 모델과 [stamp_repository.dart]/[stadium_repository.dart] 의
/// 인터페이스만 본다 — Supabase 직접 참조 금지.
library;

/// 스탬프 발급 기록. DB `stamps` 행과 1:1 (R1).
class Stamp {
  final String id;
  final String userId;
  final String stadiumId;
  final double lat;
  final double lng;
  final DateTime stampedAt;

  const Stamp({
    required this.id,
    required this.userId,
    required this.stadiumId,
    required this.lat,
    required this.lng,
    required this.stampedAt,
  });

  factory Stamp.fromJson(Map<String, dynamic> json) => Stamp(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    stadiumId: json['stadium_id'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    stampedAt: DateTime.parse(json['stamped_at'] as String),
  );
}

/// 스탬프북용 구장. DB `stadiums` + `teams` join.
///
/// 팀 식별 필드([teamId]·[teamAbbr])를 여기서 미리 갖춘다 —
/// task 1.4(두산 vs LG 칸 식별)와 1.6(칸별 팀 컬러 도장, `kTeamColors[abbr]`)이
/// 이 필드에 의존한다. 가이드 화면용 `features/stadium/stadium.dart` 와 별개 모델.
class StampStadium {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final int stampRadiusM;

  /// 구장 소속 팀 id (`stadiums.team_id`).
  final String teamId;

  /// 팀 abbr — `kTeamColors` 의 컬러 키 (`teams.abbr`).
  final String teamAbbr;

  const StampStadium({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.stampRadiusM,
    required this.teamId,
    required this.teamAbbr,
  });

  factory StampStadium.fromJson(Map<String, dynamic> json) {
    final team = json['team'] as Map<String, dynamic>;
    return StampStadium(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      stampRadiusM: json['stamp_radius_m'] as int,
      teamId: json['team_id'] as String,
      teamAbbr: team['abbr'] as String,
    );
  }
}

/// UNIQUE(user_id, stadium_id) 위반 — 이미 그 칸에 스탬프가 있다 (R3).
/// 호출부는 이 타입으로 "중복" 을 식별해 중복 안내 UX 로 수렴시킨다.
class DuplicateStampException implements Exception {
  const DuplicateStampException();

  @override
  String toString() => 'DuplicateStampException: 이미 발급된 (user, stadium) 스탬프';
}

/// 네트워크·서버 오류 단일 타입 — 오프라인·백엔드 다운·5xx·타임아웃을
/// 구분하지 않고 동일 취급한다 (보안 제약). 중복([DuplicateStampException])과만 구분.
class StampNetworkException implements Exception {
  const StampNetworkException([this.cause]);

  /// 원인 예외 (로깅용). 분기용으로 쓰지 않는다.
  final Object? cause;

  @override
  String toString() => 'StampNetworkException(cause: $cause)';
}
