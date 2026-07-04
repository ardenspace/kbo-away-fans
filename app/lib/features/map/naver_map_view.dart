/// 지도 표면의 프로덕션 구현 — flutter_naver_map `NaverMap` 을 감싼다 (R9·R12).
///
/// 이 파일만 flutter_naver_map(네이티브 SDK) 에 의존한다. [NaverMapView.build] 는
/// 네이티브 초기화를 전제(assert)하므로 위젯 테스트에서는 절대 생성하지 않는다 —
/// map_screen 은 이 [buildNaverMapView] 를 [MapViewBuilder] 기본값으로만 참조하고,
/// 테스트는 fake builder 를 주입해 이 경로를 밟지 않는다.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'map_models.dart';
import 'map_view.dart';

/// [MapViewBuilder] 의 프로덕션 구현 — 실제 네이버맵 경로.
Widget buildNaverMapView(BuildContext context, List<MapMarker> markers) =>
    NaverMapView(markers: markers);

/// `MapSurfaceBuilder` 의 프로덕션 구현 — 마커만 실제 네이버맵에 얹는다.
///
/// 경로 선/내 위치 오버레이의 실제 네이티브 렌더링은 수동 확인 대상(R10) 이라
/// 이 골격에서는 마커까지 전달한다. view-state(경로 좌표·내위치)는 [MapSurfaceData]
/// 로 이미 계산돼 넘어오므로, 네이티브 오버레이 배선은 이 파일에만 국한된다.
Widget buildNaverMapSurface(BuildContext context, MapSurfaceData data) =>
    NaverMapView(markers: data.markers);

/// flutter_naver_map `NaverMap` 을 감싸 마커를 얹는 지도 표면.
///
/// 마커 스타일링·내 위치·경로 애니 등 view-state 는 Task 2.5 범위 — 여기서는
/// 마커 목록을 지도에 전달(오버레이 추가)하는 골격까지만 담당한다.
class NaverMapView extends StatelessWidget {
  const NaverMapView({super.key, required this.markers});

  final List<MapMarker> markers;

  @override
  Widget build(BuildContext context) {
    return NaverMap(
      onMapReady: (controller) {
        controller.addOverlayAll({
          for (final marker in markers)
            NMarker(id: marker.id, position: NLatLng(marker.lat, marker.lng)),
        });
      },
    );
  }
}
