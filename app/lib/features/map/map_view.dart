/// 지도 표면 seam — 마커 리스트를 받아 지도 위젯을 만드는 함수형 추상화 (R9·R12).
///
/// flutter_naver_map 의 `NaverMap` 은 네이티브 플랫폼 뷰라 위젯 테스트로 pump 할 수
/// 없다. 그래서 지도 화면([map_screen.dart])은 이 [MapViewBuilder] 뒤에 지도 표면을
/// 두고, 위젯 테스트는 마커 전달값을 노출하는 fake builder 로 대체 pump 한다
/// (네이티브 SDK 미로딩). 프로덕션 구현은 [naver_map_view.dart] 의 `buildNaverMapView`.
library;

import 'package:flutter/widgets.dart';

import 'map_models.dart';

/// 마커 리스트를 받아 지도 표면 위젯을 만드는 builder seam.
///
/// map_screen 은 이 함수를 주입받아(기본값 = 실제 네이버맵 경로) 위젯 테스트에서
/// fake 로 교체한다.
typedef MapViewBuilder = Widget Function(
  BuildContext context,
  List<MapMarker> markers,
);

/// 내 위치 view-state (R9).
///
/// 위치 권한 거부/서비스 꺼짐/타임아웃이면 [enabled] 는 false 이고 [message] 로
/// 짧은 안내를 준다(마커·경로는 이와 무관하게 정상 표시). 획득 성공이면 [enabled]
/// true 에 [lat]/[lng] 좌표가 채워지고 [message] 는 null 이다.
class MapMyLocation {
  const MapMyLocation({
    required this.enabled,
    this.lat,
    this.lng,
    this.message,
  });

  /// 지도에 "내 위치" 를 표시할지 여부.
  final bool enabled;

  /// [enabled] 일 때의 좌표 (그 외 null).
  final double? lat;
  final double? lng;

  /// 내위치=off 안내 문구 ([enabled] false 일 때 ≠null, 획득 시 null).
  final String? message;
}

/// 지도 표면이 받는 view-state 묶음 (R9·R10).
///
/// 마커(Task 2.1)·경로 좌표 시퀀스(Task 2.2)·내 위치 상태를 한데 묶어 map_view
/// 표면 builder 로 넘긴다. 위젯 테스트는 fake builder 로 이 전달값을 검증한다.
class MapSurfaceData {
  const MapSurfaceData({
    required this.markers,
    required this.route,
    required this.myLocation,
  });

  /// 구장 마커 목록 (Task 2.1 [buildMapMarkers] 산출물).
  final List<MapMarker> markers;

  /// 방문 순서 구장 좌표 시퀀스 (Task 2.2 [buildStadiumRouteSequence] 산출물).
  final List<(double, double)> route;

  /// 내 위치 표시 여부/좌표/안내.
  final MapMyLocation myLocation;
}

/// view-state 묶음을 받아 지도 표면 위젯을 만드는 builder seam (R9·R10).
///
/// 기존 마커-only [MapViewBuilder] 와 별개로, view-state(경로·내위치) 를 함께
/// 받는 지도 표면 seam. 프로덕션 구현은 [naver_map_view.dart] 의
/// `buildNaverMapSurface`, 위젯 테스트는 fake 로 교체해 네이티브 SDK 미로딩.
typedef MapSurfaceBuilder = Widget Function(
  BuildContext context,
  MapSurfaceData data,
);
