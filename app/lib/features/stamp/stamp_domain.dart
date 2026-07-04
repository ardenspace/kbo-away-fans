/// 스탬프 도메인 순수 함수 — 근접 판정·거리 계산·잠실 칸 배정 (R1·R2·R13).
///
/// 전부 순수 Dart: 플러그인·실기기 시계 의존 없음. 좌표는 위치 계층(R4)에서,
/// 기준 시각·잠실 경기 팀 목록은 호출부(task 1.5 controller)가 주입한다.
library;

import 'dart:math' as math;

import 'stamp_models.dart';

/// 지구 평균 반지름 (m) — 하버사인 공식용.
const double _earthRadiusM = 6371000;

/// KST(UTC+9) 고정 오프셋 — DST 없음.
const kKstOffset = Duration(hours: 9);

/// 두산 베어스 abbr — seed `teams.json` 의 실제 값은 `OB` 다 (`DB` 아님).
const kDoosanAbbr = 'OB';

/// LG 트윈스 abbr.
const kLgAbbr = 'LG';

/// 잠실 두 칸의 팀 abbr 집합 — {두산, LG} (R13).
const kJamsilSlotAbbrs = {kDoosanAbbr, kLgAbbr};

/// 반경 밖 표시용 잠실 정식 명칭 — 기존 행 name. 내부 합성 name
/// "잠실야구장 (LG)" 는 UI 에 노출하지 않는다 (R2 동률 tie-break).
const kJamsilCanonicalName = '잠실야구장';

double _degToRad(double deg) => deg * math.pi / 180;

/// 하버사인 대원 거리 (m).
double haversineMeters({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final sinLat = math.sin(dLat / 2);
  final sinLng = math.sin(dLng / 2);
  final a = sinLat * sinLat +
      math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * sinLng * sinLng;
  return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(a)));
}

/// 좌표가 구장 반경 내인지 판정 — 경계(거리 == 반경)는 반경 내 (R1·R2).
bool isWithinRadius({
  required double lat,
  required double lng,
  required double stadiumLat,
  required double stadiumLng,
  required num radiusM,
}) =>
    haversineMeters(lat1: lat, lng1: lng, lat2: stadiumLat, lng2: stadiumLng) <=
    radiusM;

/// 최근접 구장 + 남은 거리 (R2 표시 재료).
class NearestStadium {
  const NearestStadium({required this.stadium, required this.distanceMeters});

  final StampStadium stadium;
  final double distanceMeters;

  /// "N.Nkm" — km 소수 1자리 (R2).
  String get distanceText => formatDistanceKm(distanceMeters);
}

/// 거리(m) → "N.Nkm" (km 소수 1자리) 포맷.
String formatDistanceKm(double meters) =>
    '${(meters / 1000).toStringAsFixed(1)}km';

/// 목록에서 가장 가까운 구장을 고른다. 빈 목록이면 null.
///
/// 동일 좌표 동률(잠실 두 행)이면 name == [kJamsilCanonicalName] 행을 택한다 —
/// 목록 순서와 무관하게 결정적 (R2).
NearestStadium? nearestStadium({
  required List<StampStadium> stadiums,
  required double lat,
  required double lng,
}) {
  StampStadium? best;
  var bestDistance = double.infinity;
  for (final stadium in stadiums) {
    final d = haversineMeters(
      lat1: lat,
      lng1: lng,
      lat2: stadium.lat,
      lng2: stadium.lng,
    );
    final closer = d < bestDistance;
    final tieBreak = d == bestDistance &&
        stadium.name == kJamsilCanonicalName &&
        best?.name != kJamsilCanonicalName;
    if (closer || tieBreak) {
      best = stadium;
      bestDistance = d;
    }
  }
  if (best == null) return null;
  return NearestStadium(stadium: best, distanceMeters: bestDistance);
}

/// 주입된 기준 시각(UTC 저장 좌표)을 KST 달력일로 역변환한다 (R13).
///
/// 반환값은 시각 없는 날짜(y·m·d)만 의미를 갖는다 —
/// `GamesRepository.teamAbbrsInGamesOn(kstDay:)` 에 그대로 넘긴다.
DateTime kstDayOf(DateTime instant) {
  final kst = instant.toUtc().add(kKstOffset);
  return DateTime(kst.year, kst.month, kst.day);
}

/// 잠실 칸 배정 — 해당 날짜 잠실 경기에 등장하는 팀 ∩ {두산, LG} (R13).
///
/// - 교집합이 한 팀이면 그 칸에만 발급.
/// - 맞대결(두 팀 다)·무경기(빈 목록)·교집합 공집합이면 두 칸 모두.
Set<String> jamsilTargetSlotAbbrs(Set<String> gameTeamAbbrs) {
  final intersection = gameTeamAbbrs.intersection(kJamsilSlotAbbrs);
  return intersection.length == 1 ? intersection : {...kJamsilSlotAbbrs};
}

/// 반경 내 구장 집합 → 발급 대상 칸 (R1·R13).
///
/// 잠실만 두 행이 같은 좌표를 공유하므로, OB·LG 행이 함께 반경 내면 잠실로 보고
/// [jamsilTargetSlotAbbrs] 로 거른다. 잠실 외 8구장은 반경 판정만으로 단일 칸.
List<StampStadium> resolveTargetSlots({
  required List<StampStadium> stadiumsInRadius,
  required Set<String> jamsilGameTeamAbbrs,
}) {
  final abbrs = stadiumsInRadius.map((s) => s.teamAbbr).toSet();
  if (!abbrs.containsAll(kJamsilSlotAbbrs)) return List.of(stadiumsInRadius);
  final targets = jamsilTargetSlotAbbrs(jamsilGameTeamAbbrs);
  return stadiumsInRadius
      .where((s) => targets.contains(s.teamAbbr))
      .toList();
}

/// 근접 판정 결과 — 반경 내/밖 2분기를 구분되는 타입으로 (house style).
sealed class StampProximity {
  const StampProximity();
}

/// 어떤 구장 반경 내 — 잠실이면 두 행이 함께 담긴다 (칸 배정은 이후 단계).
class StampInRange extends StampProximity {
  const StampInRange({required this.stadiumsInRadius});

  final List<StampStadium> stadiumsInRadius;
}

/// 전 구장 반경 밖 — 최근접 구장과 남은 거리로 안내한다 (R2).
class StampOutOfRange extends StampProximity {
  const StampOutOfRange({required this.nearest});

  final NearestStadium nearest;
}

/// 좌표 하나로 전체 구장 근접 판정 (R1·R2 분기).
///
/// [stadiums] 는 비어 있으면 안 된다 (구장 목록 로드 실패는 호출 전에 걸러진다).
StampProximity evaluateStampProximity({
  required List<StampStadium> stadiums,
  required double lat,
  required double lng,
}) {
  if (stadiums.isEmpty) {
    throw ArgumentError.value(stadiums, 'stadiums', '구장 목록이 비어 있다');
  }
  final inRadius = [
    for (final s in stadiums)
      if (isWithinRadius(
        lat: lat,
        lng: lng,
        stadiumLat: s.lat,
        stadiumLng: s.lng,
        radiusM: s.stampRadiusM,
      ))
        s,
  ];
  if (inRadius.isNotEmpty) return StampInRange(stadiumsInRadius: inRadius);
  return StampOutOfRange(
    nearest: nearestStadium(stadiums: stadiums, lat: lat, lng: lng)!,
  );
}
