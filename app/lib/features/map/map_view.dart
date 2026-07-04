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
