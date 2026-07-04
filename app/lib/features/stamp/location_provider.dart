import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_provider.g.dart';

/// GPS fix 대기 상한 (R4/보안 제약: 유한 타임아웃 — 로딩 무한 고착 금지).
/// 실내 등 fix 미획득 시 이 시간이 지나면 [LocationTimeout] 을 반환한다.
const kLocationFixTimeout = Duration(seconds: 8);

/// 위치 조회 결과 — 4분기를 구분되는 타입으로 반환 (R4·R11).
sealed class LocationResult {
  const LocationResult();
}

/// 좌표 획득 성공.
class LocationAcquired extends LocationResult {
  const LocationAcquired({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

/// 권한 거부. [permanently] 가 true 면 재요청 불가 → 설정 앱 유도 대상.
class LocationPermissionDenied extends LocationResult {
  const LocationPermissionDenied({required this.permanently});

  final bool permanently;
}

/// 기기 위치 서비스(GPS) 꺼짐.
class LocationServiceDisabled extends LocationResult {
  const LocationServiceDisabled();
}

/// [kLocationFixTimeout] 내 fix 미획득.
class LocationTimeout extends LocationResult {
  const LocationTimeout();
}

/// 권한 상태 — 플러그인 enum 을 그대로 노출하지 않기 위한 추상화.
enum LocationPermissionStatus { granted, denied, deniedForever }

/// 플랫폼 위치 기능의 최소 인터페이스.
/// geolocator 직접 참조는 [GeolocatorLocationClient] 안에만 둔다 —
/// 단위 테스트는 이 인터페이스의 fake 를 provider override 로 주입한다 (R11).
abstract interface class LocationClient {
  Future<bool> isServiceEnabled();

  Future<LocationPermissionStatus> checkAndRequestPermission();

  /// 원시 좌표 조회. 타임아웃은 호출 측([currentLocation])에서 건다.
  Future<({double lat, double lng})> getPosition();
}

/// geolocator 실구현 — 포그라운드 1회 조회 전용(백그라운드 위치 없음).
class GeolocatorLocationClient implements LocationClient {
  const GeolocatorLocationClient();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermissionStatus> checkAndRequestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        LocationPermissionStatus.granted,
      LocationPermission.deniedForever =>
        LocationPermissionStatus.deniedForever,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine =>
        LocationPermissionStatus.denied,
    };
  }

  @override
  Future<({double lat, double lng})> getPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // 플러그인 자체 상한도 동일 상수로 — 어느 쪽이 먼저든 유한 종료.
        timeLimit: kLocationFixTimeout,
      ),
    );
    return (lat: position.latitude, lng: position.longitude);
  }
}

/// 실구현 주입점. 테스트에서 `locationClientProvider.overrideWithValue(fake)`.
@riverpod
LocationClient locationClient(Ref ref) => const GeolocatorLocationClient();

/// 위치 1회 조회 — (서비스 꺼짐 → 권한 → 좌표) 순으로 판정하고,
/// 좌표 대기에 [kLocationFixTimeout] 유한 타임아웃을 건다.
/// autoDispose: 발급 시도마다 새로 조회.
@riverpod
Future<LocationResult> currentLocation(Ref ref) async {
  final client = ref.watch(locationClientProvider);

  if (!await client.isServiceEnabled()) {
    return const LocationServiceDisabled();
  }

  switch (await client.checkAndRequestPermission()) {
    case LocationPermissionStatus.denied:
      return const LocationPermissionDenied(permanently: false);
    case LocationPermissionStatus.deniedForever:
      return const LocationPermissionDenied(permanently: true);
    case LocationPermissionStatus.granted:
      break;
  }

  try {
    final position = await client.getPosition().timeout(kLocationFixTimeout);
    return LocationAcquired(lat: position.lat, lng: position.lng);
  } on TimeoutException {
    return const LocationTimeout();
  }
}
