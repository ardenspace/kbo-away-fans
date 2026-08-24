/// 콘텐츠 JSON 4종의 앱 쪽 모델 — 원격 JSON 은 신뢰 불가 입력이므로
/// 파싱 시점에 계약(`content-pipeline/schema/`)을 검증하고,
/// 위반이면 [ContentContractViolation] 으로 문서 전체를 거부한다.
///
/// 검증 범위: 필수 필드·타입·enum 멤버십·값 범위·개수·교차 id 참조.
/// 미지의 추가 키는 무시한다(additionalProperties 강제는 파이프라인
/// validate 의 몫). 특히 `themeKey` 는 `TeamThemes.byId` 에 실제로
/// 존재해야 통과시켜, 하위 위젯(TeamThemeScope)이 미지 키로 죽지 않게
/// 로더/모델 계층에서 차단한다.
library;

import '../design/team_themes.dart';
import 'content_ids.dart';

/// 원격 JSON 이 콘텐츠 계약을 위반했음을 나타낸다.
///
/// 로더는 이 예외를 받으면 갱신을 거부하고 기존 캐시를 유지한다.
class ContentContractViolation implements Exception {
  ContentContractViolation(this.message);

  /// 어떤 계약이 어떻게 깨졌는지 (사람이 읽는 진단용).
  final String message;

  @override
  String toString() => 'ContentContractViolation: $message';
}

final RegExp _slugPattern = RegExp(r'^[a-z][a-z0-9-]*$');
final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

Never _violate(String message) => throw ContentContractViolation(message);

Map<String, Object?> _object(Object? value, String context) {
  if (value is! Map<String, Object?>) {
    _violate('$context: 객체가 아님');
  }
  return value;
}

List<Object?> _array(Map<String, Object?> json, String field, String context) {
  final value = json[field];
  if (value is! List<Object?>) {
    _violate('$context.$field: 배열이 아니거나 없음');
  }
  return value;
}

String _string(Map<String, Object?> json, String field, String context) {
  final value = json[field];
  if (value is! String || value.isEmpty) {
    _violate('$context.$field: 비어 있지 않은 문자열이 아님');
  }
  return value;
}

String? _optionalString(
  Map<String, Object?> json,
  String field,
  String context,
) {
  if (!json.containsKey(field)) return null;
  return _string(json, field, context);
}

bool _bool(Map<String, Object?> json, String field, String context) {
  final value = json[field];
  if (value is! bool) {
    _violate('$context.$field: boolean 이 아니거나 없음');
  }
  return value;
}

double _coordinate(
  Map<String, Object?> json,
  String field,
  String context, {
  required double min,
  required double max,
}) {
  final value = json[field];
  if (value is! num) {
    _violate('$context.$field: 숫자가 아니거나 없음');
  }
  if (value < min || value > max) {
    _violate('$context.$field: $value 는 [$min, $max] 범위 밖');
  }
  return value.toDouble();
}

double _latitude(Map<String, Object?> json, String context) =>
    _coordinate(json, 'lat', context, min: 33, max: 39);

double _longitude(Map<String, Object?> json, String context) =>
    _coordinate(json, 'lng', context, min: 124, max: 132);

String _teamId(Map<String, Object?> json, String field, String context) {
  final value = _string(json, field, context);
  if (!kTeamIds.contains(value)) {
    _violate('$context.$field: 미지의 팀 id "$value"');
  }
  return value;
}

String _stadiumId(Map<String, Object?> json, String field, String context) {
  final value = _string(json, field, context);
  if (!kStadiumIds.contains(value)) {
    _violate('$context.$field: 미지의 구장 id "$value"');
  }
  return value;
}

void _requireUnique(Iterable<String> ids, String context) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      _violate('$context: 중복 id "$id"');
    }
  }
}

// ---------------------------------------------------------------------------
// teams.json
// ---------------------------------------------------------------------------

/// 팀 1개 — teams.schema.json `$defs/team`.
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.shortName,
    required this.themeKey,
  });

  factory Team.fromJson(Object? raw) {
    final json = _object(raw, 'team');
    final id = _teamId(json, 'id', 'team');
    final context = 'team($id)';
    final themeKey = _string(json, 'themeKey', context);
    if (!_slugPattern.hasMatch(themeKey)) {
      _violate('$context.themeKey: slug 형식이 아님 "$themeKey"');
    }
    if (!TeamThemes.byId.containsKey(themeKey)) {
      _violate('$context.themeKey: TeamThemes 에 없는 테마 키 "$themeKey"');
    }
    return Team(
      id: id,
      name: _string(json, 'name', context),
      shortName: _string(json, 'shortName', context),
      themeKey: themeKey,
    );
  }

  /// common.defs teamId (안정 id).
  final String id;
  final String name;
  final String shortName;

  /// `lib/design/team_themes.dart` 테마 토큰 키 — 계약상 테마 조회 포인터.
  /// 파싱을 통과했다면 [TeamThemes.byId] 조회가 항상 성공한다.
  final String themeKey;

  /// 이 팀의 테마 토큰 (파싱 검증 덕에 null 불가).
  TeamTheme get theme => TeamThemes.byId[themeKey]!;
}

/// teams.json 문서 전체.
class TeamsDocument {
  const TeamsDocument({required this.teams});

  factory TeamsDocument.fromJson(Map<String, Object?> json) {
    final teams =
        _array(json, 'teams', 'teams.json').map(Team.fromJson).toList();
    if (teams.length != kTeamCount) {
      _violate('teams.json: 팀은 정확히 $kTeamCount개여야 함 (${teams.length}개)');
    }
    _requireUnique(teams.map((t) => t.id), 'teams.json');
    return TeamsDocument(teams: List.unmodifiable(teams));
  }

  final List<Team> teams;

  /// 안정 id 로 팀 조회. 미지 id 는 null (파싱 검증 덕에 로스터 10종은 보장).
  Team? byId(String id) {
    for (final team in teams) {
      if (team.id == id) return team;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// stadiums.json
// ---------------------------------------------------------------------------

/// 구장 1곳 — stadiums.schema.json `$defs/stadium`.
class Stadium {
  const Stadium({
    required this.id,
    required this.name,
    required this.city,
    required this.lat,
    required this.lng,
    required this.homeTeams,
  });

  factory Stadium.fromJson(Object? raw) {
    final json = _object(raw, 'stadium');
    final id = _stadiumId(json, 'id', 'stadium');
    final context = 'stadium($id)';
    final homeTeamsRaw = _array(json, 'homeTeams', context);
    if (homeTeamsRaw.isEmpty || homeTeamsRaw.length > 2) {
      _violate('$context.homeTeams: 1~2팀이어야 함 (${homeTeamsRaw.length}팀)');
    }
    final homeTeams = <String>[];
    for (final element in homeTeamsRaw) {
      if (element is! String || !kTeamIds.contains(element)) {
        _violate('$context.homeTeams: 미지의 팀 id "$element"');
      }
      homeTeams.add(element);
    }
    _requireUnique(homeTeams, '$context.homeTeams');
    return Stadium(
      id: id,
      name: _string(json, 'name', context),
      city: _string(json, 'city', context),
      lat: _latitude(json, context),
      lng: _longitude(json, context),
      homeTeams: List.unmodifiable(homeTeams),
    );
  }

  /// common.defs stadiumId — 스탬프 인증 대비 불변 식별자.
  final String id;
  final String name;
  final String city;
  final double lat;
  final double lng;

  /// 홈팀 목록 — 잠실만 2팀, 나머지는 1팀.
  final List<String> homeTeams;
}

/// stadiums.json 문서 전체.
class StadiumsDocument {
  const StadiumsDocument({required this.stadiums});

  factory StadiumsDocument.fromJson(Map<String, Object?> json) {
    final stadiums = _array(json, 'stadiums', 'stadiums.json')
        .map(Stadium.fromJson)
        .toList();
    if (stadiums.length != kStadiumCount) {
      _violate(
        'stadiums.json: 구장은 정확히 $kStadiumCount곳이어야 함 (${stadiums.length}곳)',
      );
    }
    _requireUnique(stadiums.map((s) => s.id), 'stadiums.json');
    return StadiumsDocument(stadiums: List.unmodifiable(stadiums));
  }

  final List<Stadium> stadiums;

  /// 안정 id 로 구장 조회.
  Stadium? byId(String id) {
    for (final stadium in stadiums) {
      if (stadium.id == id) return stadium;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// places.json
// ---------------------------------------------------------------------------

/// 추천 장소 카테고리 — places.schema.json category enum 5종
/// (추천 목록 필터 칩과 1:1 대응).
enum PlaceCategory {
  food('food'),
  cafe('cafe'),
  escapeRoom('escape_room'),
  activity('activity'),
  landmark('landmark');

  const PlaceCategory(this.contractValue);

  /// JSON 계약의 문자열 값.
  final String contractValue;

  static PlaceCategory parse(String value, String context) {
    for (final category in values) {
      if (category.contractValue == value) return category;
    }
    _violate('$context.category: 미지의 카테고리 "$value"');
  }
}

/// 추천 장소 1곳 — places.schema.json `$defs/place`.
class Place {
  const Place({
    required this.id,
    required this.stadiumId,
    required this.name,
    required this.category,
    required this.indoor,
    required this.source,
    required this.lat,
    required this.lng,
    this.address,
    this.description,
    this.shoutout,
  });

  factory Place.fromJson(Object? raw) {
    final json = _object(raw, 'place');
    final id = _string(json, 'id', 'place');
    if (!_slugPattern.hasMatch(id)) {
      _violate('place.id: slug 형식이 아님 "$id"');
    }
    final context = 'place($id)';
    final source = _string(json, 'source', context);
    if (source != 'curated') {
      // UGC 대비 예약 필드 — 값 추가는 schemaVersion 마이그레이션급.
      _violate('$context.source: "curated" 만 허용 ("$source")');
    }
    return Place(
      id: id,
      stadiumId: _stadiumId(json, 'stadiumId', context),
      name: _string(json, 'name', context),
      category: PlaceCategory.parse(
        _string(json, 'category', context),
        context,
      ),
      indoor: _bool(json, 'indoor', context),
      source: source,
      lat: _latitude(json, context),
      lng: _longitude(json, context),
      address: _optionalString(json, 'address', context),
      description: _optionalString(json, 'description', context),
      shoutout: _optionalString(json, 'shoutout', context),
    );
  }

  final String id;
  final String stadiumId;
  final String name;
  final PlaceCategory category;

  /// 실내 여부 — 우천 플랜B 필터 근거.
  final bool indoor;

  /// UGC 대비 예약 필드 — MVP 에서는 항상 "curated".
  final String source;
  final double lat;
  final double lng;
  final String? address;
  final String? description;

  /// 샤라웃 출처 문구 — PlaceCard 뱃지에 그대로 노출.
  final String? shoutout;
}

/// places.json 문서 전체.
class PlacesDocument {
  const PlacesDocument({required this.places});

  factory PlacesDocument.fromJson(Map<String, Object?> json) {
    final places =
        _array(json, 'places', 'places.json').map(Place.fromJson).toList();
    _requireUnique(places.map((p) => p.id), 'places.json');
    return PlacesDocument(places: List.unmodifiable(places));
  }

  final List<Place> places;

  /// 구장 기준 장소 필터.
  List<Place> forStadium(String stadiumId) =>
      places.where((p) => p.stadiumId == stadiumId).toList();
}

// ---------------------------------------------------------------------------
// schedule.json
// ---------------------------------------------------------------------------

/// 경기 상태 — schedule.schema.json status enum 3종.
enum GameStatus {
  scheduled('scheduled'),
  canceled('canceled'),
  rainCanceled('rain_canceled');

  const GameStatus(this.contractValue);

  /// JSON 계약의 문자열 값.
  final String contractValue;

  static GameStatus parse(String value, String context) {
    for (final status in values) {
      if (status.contractValue == value) return status;
    }
    _violate('$context.status: 미지의 경기 상태 "$value"');
  }
}

/// 경기 1건 — schedule.schema.json `$defs/game`.
class Game {
  const Game({
    required this.id,
    required this.date,
    required this.startTime,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.stadiumId,
    required this.status,
  });

  factory Game.fromJson(Object? raw) {
    final json = _object(raw, 'game');
    final id = _string(json, 'id', 'game');
    final context = 'game($id)';
    final date = _string(json, 'date', context);
    if (!_datePattern.hasMatch(date)) {
      _violate('$context.date: YYYY-MM-DD 형식이 아님 "$date"');
    }
    final startTime = _string(json, 'startTime', context);
    if (!_timePattern.hasMatch(startTime)) {
      _violate('$context.startTime: HH:MM 형식이 아님 "$startTime"');
    }
    return Game(
      id: id,
      date: date,
      startTime: startTime,
      homeTeamId: _teamId(json, 'homeTeamId', context),
      awayTeamId: _teamId(json, 'awayTeamId', context),
      stadiumId: _stadiumId(json, 'stadiumId', context),
      status: GameStatus.parse(_string(json, 'status', context), context),
    );
  }

  final String id;

  /// 경기 날짜 (KST, YYYY-MM-DD).
  final String date;

  /// 현지(KST) 시작 시각 HH:MM.
  final String startTime;
  final String homeTeamId;
  final String awayTeamId;
  final String stadiumId;
  final GameStatus status;
}

/// schedule.json 문서 전체.
class ScheduleDocument {
  const ScheduleDocument({required this.generatedAt, required this.games});

  factory ScheduleDocument.fromJson(Map<String, Object?> json) {
    final generatedAtRaw = _string(json, 'generatedAt', 'schedule.json');
    final generatedAt = DateTime.tryParse(generatedAtRaw);
    if (generatedAt == null) {
      _violate('schedule.json.generatedAt: ISO 8601 이 아님 "$generatedAtRaw"');
    }
    final games =
        _array(json, 'games', 'schedule.json').map(Game.fromJson).toList();
    _requireUnique(games.map((g) => g.id), 'schedule.json');
    return ScheduleDocument(
      generatedAt: generatedAt,
      games: List.unmodifiable(games),
    );
  }

  /// 크롤러 산출 시각.
  final DateTime generatedAt;
  final List<Game> games;
}
