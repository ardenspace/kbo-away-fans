/// 지도 view-state 데이터 계층 — 마커·경로 조회 + 내위치 파생 + 경로 애니 트리거 seam
/// (R9·R10).
///
/// 마커·경로의 소스(stadiums/stamps)는 기존 repository 에서 온다. 두 원격 조회 중
/// 하나라도 실패하면 AsyncError 로 전파되어 화면이 빈 지도가 아니라 오류+재시도를
/// 그린다(스탬프북 [stampbookProvider] 와 동일한 패턴). 내 위치는 이와 독립적으로
/// [currentLocationProvider] 4분기에서 파생한다 — 위치 실패는 마커·경로를 막지 않는다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../stamp/location_provider.dart';
import '../stamp/stamp_repository.dart';
import '../stamp/stadium_repository.dart';
import 'map_domain.dart';
import 'map_models.dart';
import 'map_view.dart';

part 'map_controller.g.dart';

/// 지도의 마커·경로 view-state (R9·R10).
///
/// [markers] 는 Task 2.1 [buildMapMarkers], [route] 는 Task 2.2
/// [buildStadiumRouteSequence] 결과를 그대로 담는다(재구현 없음).
class MapData {
  const MapData({required this.markers, required this.route});

  final List<MapMarker> markers;
  final List<(double, double)> route;
}

/// 지도 마커·경로 데이터 — 구장 목록 + 내 스탬프를 합쳐 마커/경로를 만든다.
///
/// 클라우드가 진실원천: 두 원격 조회 중 하나라도 실패하면 AsyncError 로 전파된다
/// (화면은 오류+재시도). 로컬 폴백 없음.
@riverpod
Future<MapData> mapData(Ref ref) async {
  final stadiums = await ref.watch(stadiumRepositoryProvider).listStadiums();
  final stamps = await ref.watch(stampRepositoryProvider).myStamps();
  return MapData(
    markers: buildMapMarkers(stadiums: stadiums, stamps: stamps),
    route: buildStadiumRouteSequence(stadiums: stadiums, stamps: stamps),
  );
}

/// 위치 조회 결과 4분기 → 내 위치 view-state (R9).
///
/// 획득이면 내위치=on + 좌표(안내 없음), 그 외(권한 거부/서비스 꺼짐/타임아웃)는
/// 내위치=off + 짧은 안내. 마커·경로 표시와는 독립적이다.
MapMyLocation resolveMyLocation(LocationResult result) => switch (result) {
      LocationAcquired(:final lat, :final lng) =>
        MapMyLocation(enabled: true, lat: lat, lng: lng),
      LocationPermissionDenied() => const MapMyLocation(
          enabled: false,
          message: '위치 권한이 없어 내 위치를 표시할 수 없어요.',
        ),
      LocationServiceDisabled() => const MapMyLocation(
          enabled: false,
          message: '위치 서비스가 꺼져 있어 내 위치를 표시할 수 없어요.',
        ),
      LocationTimeout() => const MapMyLocation(
          enabled: false,
          message: '위치를 확인하지 못했어요.',
        ),
    };

/// 경로 애니메이션이 재생을 시작하는 순간(방문 ≥2 로 진입)을 관측하는 seam (R10).
///
/// 프로덕션 기본은 no-op(null). 위젯 테스트가 override 해서 발화 횟수·좌표 시퀀스·
/// 재진입 재발화를 기록한다. 스탬프 [stampCelebrationObserverProvider] 관측 패턴 동형.
typedef MapRouteAnimationObserver = void Function(List<(double, double)> route);

final mapRouteAnimationObserverProvider =
    Provider<MapRouteAnimationObserver?>((ref) => null);
