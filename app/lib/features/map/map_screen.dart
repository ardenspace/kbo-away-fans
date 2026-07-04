/// 지도 화면 골격 — map_view seam + Client ID degrade + 마커 전달 (R9·R12).
///
/// Client ID 미주입 시([shouldDegradeMap] true) 네이티브 지도 위젯을 만들지 않고
/// 중앙 안내 텍스트만 렌더한다 (crash 없음, R12). 주입 시에는 [mapViewBuilder]
/// (기본값 = 실제 네이버맵 경로 `buildNaverMapView`) 로 지도 표면을 구성하고,
/// 마커 목록([markers]) 을 그대로 전달한다.
///
/// 내 위치/권한 view-state 와 경로 애니메이션, 마커 provider 조회 배선은 Task 2.5,
/// `/map` 라우트 등록은 Task 2.6 범위 — 이 화면은 골격까지만 담당한다.
library;

import 'package:flutter/material.dart';

import 'map_models.dart';
import 'map_view.dart';
import 'naver_map_config.dart';
import 'naver_map_view.dart';

/// Client ID 미주입 degrade 시 지도 화면 중앙에 렌더하는 안내 문구 (R12).
const String mapUnavailableMessage = '지도를 표시할 수 없어요.\n지도 설정이 완료되면 구장 위치를 볼 수 있어요.';

class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    this.markers = const [],
    this.clientId = ncpMapClientId,
    this.mapViewBuilder = buildNaverMapView,
  });

  /// 지도에 얹을 구장 마커 목록 (Task 2.1 [buildMapMarkers] 산출물). map_view 로 전달.
  final List<MapMarker> markers;

  /// NCP Maps Client ID. 기본값은 dart-define 주입 상수 [ncpMapClientId].
  /// 테스트가 degrade/실경로 분기를 강제할 수 있도록 파라미터로 노출한다.
  final String clientId;

  /// 지도 표면 builder seam. 기본값은 실제 네이버맵 경로([buildNaverMapView]);
  /// 위젯 테스트는 fake builder 를 주입해 네이티브 SDK 를 밟지 않는다.
  final MapViewBuilder mapViewBuilder;

  @override
  Widget build(BuildContext context) {
    if (shouldDegradeMap(clientId)) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(mapUnavailableMessage, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    return Scaffold(body: mapViewBuilder(context, markers));
  }
}
