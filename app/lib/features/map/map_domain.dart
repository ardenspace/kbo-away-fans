/// 지도 마커 구성 순수 함수 — 잠실 병합 + 방문 플래그 (R9).
///
/// 네이티브·키 의존 없음: 구장 목록·스탬프 목록만 입력받아 마커 리스트를 만든다.
/// 렌더링(Client ID 필요)은 별도 계층.
library;

import '../stamp/stamp_domain.dart' show kJamsilCanonicalName;
import '../stamp/stamp_models.dart';
import 'map_models.dart';

/// 구장 목록 + 내 스탬프 목록 → 지도 마커 리스트 (R9).
///
/// - 동일 좌표(lat·lng) 행은 마커 1개로 병합한다 — 잠실 두 행만 좌표를 공유하므로
///   10구장이면 마커 9개가 된다. 잠실 외 구장은 1:1 로 매핑된다.
/// - 병합 그룹의 표시명·id 는 name == [kJamsilCanonicalName] 인 대표행을 우선 택한다
///   (없으면 그룹 첫 행) — 합성 "(LG)" 는 노출하지 않는다 (stamp_domain tie-break 정합).
/// - 방문 여부: 그룹 내 어떤 행이라도 스탬프가 있으면 isVisited=true.
///
/// 출력 순서는 입력 구장 목록에서 각 좌표가 처음 등장한 순서를 따른다 (결정적).
List<MapMarker> buildMapMarkers({
  required List<StampStadium> stadiums,
  required List<Stamp> stamps,
}) {
  final visitedStadiumIds = {for (final s in stamps) s.stadiumId};

  // 좌표 키 → 그 좌표를 공유하는 구장 행들. LinkedHashMap 로 등장 순서 보존.
  final groups = <(double, double), List<StampStadium>>{};
  for (final stadium in stadiums) {
    groups.putIfAbsent((stadium.lat, stadium.lng), () => []).add(stadium);
  }

  return [
    for (final rows in groups.values)
      _mergeGroup(rows, visitedStadiumIds),
  ];
}

/// 동일 좌표 그룹 하나를 마커 1개로 병합한다.
MapMarker _mergeGroup(List<StampStadium> rows, Set<String> visitedStadiumIds) {
  final representative = rows.firstWhere(
    (s) => s.name == kJamsilCanonicalName,
    orElse: () => rows.first,
  );
  final isVisited = rows.any((s) => visitedStadiumIds.contains(s.id));
  return MapMarker(
    id: representative.id,
    name: representative.name,
    lat: representative.lat,
    lng: representative.lng,
    isVisited: isVisited,
  );
}
