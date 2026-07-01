// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'places_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 구장 근처 맛집 — on-demand(autoDispose.family). pick_type 순 정렬.

@ProviderFor(restaurants)
final restaurantsProvider = RestaurantsFamily._();

/// 구장 근처 맛집 — on-demand(autoDispose.family). pick_type 순 정렬.

final class RestaurantsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Restaurant>>,
          List<Restaurant>,
          FutureOr<List<Restaurant>>
        >
    with $FutureModifier<List<Restaurant>>, $FutureProvider<List<Restaurant>> {
  /// 구장 근처 맛집 — on-demand(autoDispose.family). pick_type 순 정렬.
  RestaurantsProvider._({
    required RestaurantsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'restaurantsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$restaurantsHash();

  @override
  String toString() {
    return r'restaurantsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Restaurant>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Restaurant>> create(Ref ref) {
    final argument = this.argument as String;
    return restaurants(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RestaurantsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$restaurantsHash() => r'6fc168e9dc610a35874ad8bfc7a06186ece838ff';

/// 구장 근처 맛집 — on-demand(autoDispose.family). pick_type 순 정렬.

final class RestaurantsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Restaurant>>, String> {
  RestaurantsFamily._()
    : super(
        retry: null,
        name: r'restaurantsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 구장 근처 맛집 — on-demand(autoDispose.family). pick_type 순 정렬.

  RestaurantsProvider call(String stadiumId) =>
      RestaurantsProvider._(argument: stadiumId, from: this);

  @override
  String toString() => r'restaurantsProvider';
}

/// 구장 근처 플랜B 장소 — on-demand(autoDispose.family).

@ProviderFor(planbPlaces)
final planbPlacesProvider = PlanbPlacesFamily._();

/// 구장 근처 플랜B 장소 — on-demand(autoDispose.family).

final class PlanbPlacesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PlanbPlace>>,
          List<PlanbPlace>,
          FutureOr<List<PlanbPlace>>
        >
    with $FutureModifier<List<PlanbPlace>>, $FutureProvider<List<PlanbPlace>> {
  /// 구장 근처 플랜B 장소 — on-demand(autoDispose.family).
  PlanbPlacesProvider._({
    required PlanbPlacesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'planbPlacesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$planbPlacesHash();

  @override
  String toString() {
    return r'planbPlacesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<PlanbPlace>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PlanbPlace>> create(Ref ref) {
    final argument = this.argument as String;
    return planbPlaces(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanbPlacesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$planbPlacesHash() => r'0f59da47459c1b9509c108f00689b6d8806cef50';

/// 구장 근처 플랜B 장소 — on-demand(autoDispose.family).

final class PlanbPlacesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<PlanbPlace>>, String> {
  PlanbPlacesFamily._()
    : super(
        retry: null,
        name: r'planbPlacesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 구장 근처 플랜B 장소 — on-demand(autoDispose.family).

  PlanbPlacesProvider call(String stadiumId) =>
      PlanbPlacesProvider._(argument: stadiumId, from: this);

  @override
  String toString() => r'planbPlacesProvider';
}
