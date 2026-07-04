// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 실구현 주입점. 테스트에서 `locationClientProvider.overrideWithValue(fake)`.

@ProviderFor(locationClient)
final locationClientProvider = LocationClientProvider._();

/// 실구현 주입점. 테스트에서 `locationClientProvider.overrideWithValue(fake)`.

final class LocationClientProvider
    extends $FunctionalProvider<LocationClient, LocationClient, LocationClient>
    with $Provider<LocationClient> {
  /// 실구현 주입점. 테스트에서 `locationClientProvider.overrideWithValue(fake)`.
  LocationClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locationClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locationClientHash();

  @$internal
  @override
  $ProviderElement<LocationClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocationClient create(Ref ref) {
    return locationClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocationClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocationClient>(value),
    );
  }
}

String _$locationClientHash() => r'f22b7c24c6073b6c4e137fdda77e980fa5ec4b3c';

/// 위치 1회 조회 — (서비스 꺼짐 → 권한 → 좌표) 순으로 판정하고,
/// 좌표 대기에 [kLocationFixTimeout] 유한 타임아웃을 건다.
/// autoDispose: 발급 시도마다 새로 조회.

@ProviderFor(currentLocation)
final currentLocationProvider = CurrentLocationProvider._();

/// 위치 1회 조회 — (서비스 꺼짐 → 권한 → 좌표) 순으로 판정하고,
/// 좌표 대기에 [kLocationFixTimeout] 유한 타임아웃을 건다.
/// autoDispose: 발급 시도마다 새로 조회.

final class CurrentLocationProvider
    extends
        $FunctionalProvider<
          AsyncValue<LocationResult>,
          LocationResult,
          FutureOr<LocationResult>
        >
    with $FutureModifier<LocationResult>, $FutureProvider<LocationResult> {
  /// 위치 1회 조회 — (서비스 꺼짐 → 권한 → 좌표) 순으로 판정하고,
  /// 좌표 대기에 [kLocationFixTimeout] 유한 타임아웃을 건다.
  /// autoDispose: 발급 시도마다 새로 조회.
  CurrentLocationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentLocationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentLocationHash();

  @$internal
  @override
  $FutureProviderElement<LocationResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LocationResult> create(Ref ref) {
    return currentLocation(ref);
  }
}

String _$currentLocationHash() => r'6551131b28f0d07fd7d223213eec1f5d30ac4071';
