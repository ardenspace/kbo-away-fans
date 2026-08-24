import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../design/tokens.dart';

/// 지도에 찍을 마커 값 객체.
///
/// SDK 타입(NMarker/NLatLng)을 래퍼 밖으로 새지 않게 하는 경계 —
/// 호출자는 좌표·라벨만 넘기고 SDK 변환은 [StadiumMapView] 안에서 한다.
class StadiumMapMarker {
  const StadiumMapMarker({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
  });

  /// 마커 식별자 (예: 'stadium-sajik', 'place-gukbap').
  final String id;

  /// 지도 위 캡션으로 뜨는 라벨 (구장·장소 이름).
  final String label;

  final double lat;
  final double lng;
}

/// flutter_naver_map 래퍼 — 앱 내 모든 지도 표시 지점.
///
/// 계약: 지도 SDK 코드(import 포함)는 이 파일 안에만 존재한다.
///
/// 네이버 클라우드 클라이언트 ID 는 `--dart-define=NAVER_MAP_CLIENT_ID` 로
/// 주입하고 [ensureInitialized] 가 앱 시작 시 SDK 를 초기화한다.
/// 키 미주입·초기화 실패 시에는 자리 표시 폴백을 렌더해
/// 키 없이도 빌드·테스트가 통과한다 (위젯 테스트의 mock 래퍼 경로).
class StadiumMapView extends StatelessWidget {
  const StadiumMapView({
    super.key,
    required this.centerLat,
    required this.centerLng,
    this.markers = const [],
    this.initialZoom = defaultInitialZoom,
  });

  /// 초기 카메라 줌 기본값 — 구장과 주변 장소가 한 화면에 들어오는 수준.
  static const double defaultInitialZoom = 14;

  /// 초기 카메라 중심 좌표.
  final double centerLat;
  final double centerLng;

  /// 지도에 찍을 마커 목록 (구장·장소).
  final List<StadiumMapMarker> markers;

  /// 초기 카메라 줌.
  final double initialZoom;

  static bool _sdkReady = false;

  /// 네이버 지도 SDK 초기화 — 앱 시작 시(main) 한 번 호출한다.
  ///
  /// 클라이언트 ID(`NAVER_MAP_CLIENT_ID` dart-define)가 없으면 조용히
  /// 건너뛰고, 이후 모든 지도는 [_placeholder] 폴백으로 렌더된다.
  static Future<void> ensureInitialized() async {
    if (_sdkReady) return;
    const clientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');
    if (clientId.isEmpty) return;
    try {
      await FlutterNaverMap().init(
        clientId: clientId,
        onAuthFailed: (ex) => debugPrint('네이버 지도 인증 실패: $ex'),
      );
      _sdkReady = true;
    } on Exception catch (e) {
      debugPrint('네이버 지도 SDK 초기화 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RadiusTokens.md),
      child: _sdkReady ? _map() : _placeholder(),
    );
  }

  /// 실 SDK 지도 — 초기 카메라를 중심 좌표에 두고 마커를 얹는다.
  Widget _map() {
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: NLatLng(centerLat, centerLng),
          zoom: initialZoom,
        ),
      ),
      onMapReady: (controller) {
        controller.addOverlayAll({
          for (final marker in markers)
            NMarker(
              id: marker.id,
              position: NLatLng(marker.lat, marker.lng),
              caption: NOverlayCaption(text: marker.label),
            ),
        });
      },
    );
  }

  /// SDK 미초기화(키 없음) 폴백 — 마커 라벨을 텍스트로 나열해
  /// 위젯 테스트가 "구장·장소 마커"를 트리에서 관찰할 수 있게 한다.
  Widget _placeholder() {
    return ColoredBox(
      color: ColorTokens.surfaceDim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(SpaceTokens.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '지도 준비 중',
                style: TextStyle(
                  fontFamily: TypeTokens.fontFamily,
                  fontSize: TypeTokens.label,
                  fontWeight: TypeTokens.weightBold,
                  color: ColorTokens.textSecondary,
                ),
              ),
              for (final marker in markers) ...[
                const SizedBox(height: SpaceTokens.xs),
                Text(
                  marker.label,
                  style: const TextStyle(
                    fontFamily: TypeTokens.fontFamily,
                    fontSize: TypeTokens.caption,
                    fontWeight: TypeTokens.weightMedium,
                    color: ColorTokens.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
