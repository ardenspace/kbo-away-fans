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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../stamp/location_provider.dart';
import 'map_controller.dart';
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

/// 지도 라이브 화면 — 마커·경로 데이터 조회 + 내위치/권한 + 경로 애니 트리거 (R9·R10).
///
/// 골격([MapScreen])이 정적 마커 pass-through/degrade 만 담당하는 데 비해, 이 화면은
/// provider 를 구독해 view-state 를 구성한다:
///  - 마커·경로: [mapDataProvider] (AsyncValue) — 조회 실패면 빈 지도가 아니라
///    오류+재시도([MapErrorView]). 로딩은 인디케이터.
///  - 내 위치: [currentLocationProvider] 1회 조회 → [resolveMyLocation] 로 파생.
///    위치 실패(권한 거부/서비스 꺼짐)는 마커·경로를 막지 않고 내위치만 off + 안내.
///  - 경로 애니 트리거: 방문 ≥2(경로 길이 ≥2) 로 진입할 때마다 1회 발화한다.
///    이 위젯이 마운트될 때 상태가 초기화되므로 재진입(재마운트)마다 다시 발화한다.
///
/// `/map` 라우트 등록은 Task 2.6, 네이티브 플랫폼 설정은 Task 2.7 범위.
class MapView extends ConsumerStatefulWidget {
  const MapView({
    super.key,
    this.clientId = ncpMapClientId,
    this.surfaceBuilder = buildNaverMapSurface,
  });

  /// NCP Maps Client ID. 미주입(빈 값)이면 degrade 안내로 렌더한다 (R12).
  final String clientId;

  /// 지도 표면 builder seam. 기본값은 실제 네이버맵 경로([buildNaverMapSurface]);
  /// 위젯 테스트는 fake builder 를 주입해 view-state 전달값을 검증한다.
  final MapSurfaceBuilder surfaceBuilder;

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  /// 이 마운트에서 경로 애니 트리거를 이미 발화했는지 — 같은 진입 내 중복 발화 방지.
  /// 재진입은 새 State 라 false 로 초기화되어 다시 발화한다 (R10).
  bool _animationFired = false;

  @override
  Widget build(BuildContext context) {
    if (shouldDegradeMap(widget.clientId)) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(mapUnavailableMessage, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final dataAsync = ref.watch(mapDataProvider);
    final locationAsync = ref.watch(currentLocationProvider);

    return Scaffold(
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => MapErrorView(
          onRetry: () => ref.invalidate(mapDataProvider),
        ),
        data: (data) {
          _maybeFireRouteAnimation(data.route);
          final myLocation = locationAsync.maybeWhen(
            data: resolveMyLocation,
            orElse: () => const MapMyLocation(enabled: false),
          );
          return widget.surfaceBuilder(
            context,
            MapSurfaceData(
              markers: data.markers,
              route: data.route,
              myLocation: myLocation,
            ),
          );
        },
      ),
    );
  }

  /// 방문 ≥2(경로 길이 ≥2)면 이 진입에서 1회 트리거를 발화한다 (R10).
  void _maybeFireRouteAnimation(List<(double, double)> route) {
    if (_animationFired || route.length < 2) return;
    _animationFired = true;
    final observer = ref.read(mapRouteAnimationObserverProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => observer?.call(route));
  }
}

/// 마커·경로 조회 실패 상태 — 빈 지도 대신 오류 안내 + 재시도 (R9).
class MapErrorView extends StatelessWidget {
  const MapErrorView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('지도를 불러오지 못했어요'),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
