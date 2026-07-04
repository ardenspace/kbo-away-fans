// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 지도 마커·경로 데이터 — 구장 목록 + 내 스탬프를 합쳐 마커/경로를 만든다.
///
/// 클라우드가 진실원천: 두 원격 조회 중 하나라도 실패하면 AsyncError 로 전파된다
/// (화면은 오류+재시도). 로컬 폴백 없음.

@ProviderFor(mapData)
final mapDataProvider = MapDataProvider._();

/// 지도 마커·경로 데이터 — 구장 목록 + 내 스탬프를 합쳐 마커/경로를 만든다.
///
/// 클라우드가 진실원천: 두 원격 조회 중 하나라도 실패하면 AsyncError 로 전파된다
/// (화면은 오류+재시도). 로컬 폴백 없음.

final class MapDataProvider
    extends $FunctionalProvider<AsyncValue<MapData>, MapData, FutureOr<MapData>>
    with $FutureModifier<MapData>, $FutureProvider<MapData> {
  /// 지도 마커·경로 데이터 — 구장 목록 + 내 스탬프를 합쳐 마커/경로를 만든다.
  ///
  /// 클라우드가 진실원천: 두 원격 조회 중 하나라도 실패하면 AsyncError 로 전파된다
  /// (화면은 오류+재시도). 로컬 폴백 없음.
  MapDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapDataProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapDataHash();

  @$internal
  @override
  $FutureProviderElement<MapData> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<MapData> create(Ref ref) {
    return mapData(ref);
  }
}

String _$mapDataHash() => r'd5ba9ba64d9ff37c0b8e0c60d08fa531cdba8a66';
