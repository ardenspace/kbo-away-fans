/// 지도 마커 데이터 모델 (R9).
///
/// 렌더링(Google Map 위젯·Client ID)과 분리된 순수 데이터 —
/// [map_domain.dart] 가 구장·스탬프로부터 이 모델 리스트를 구성한다.
library;

/// 지도에 찍히는 구장 마커 하나.
///
/// 잠실 두 행(같은 좌표)은 [map_domain] 에서 마커 1개로 병합되므로,
/// 마커 1개가 구장 1곳(또는 병합된 잠실 한 곳)에 대응한다.
class MapMarker {
  /// 대표 구장 id — 병합된 잠실은 canonical("잠실야구장") 행의 id.
  final String id;

  /// 표시명 — 잠실 병합 마커는 canonical "잠실야구장" (합성 "(LG)" 노출 안 함).
  final String name;

  final double lat;
  final double lng;

  /// 방문 여부. 병합 잠실은 두 칸 중 하나라도 방문이면 true (R9).
  final bool isVisited;

  const MapMarker({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.isVisited,
  });
}
