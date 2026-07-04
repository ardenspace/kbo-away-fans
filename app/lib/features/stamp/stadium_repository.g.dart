// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stadium_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 실구현 주입점. 테스트에서 `stadiumRepositoryProvider.overrideWithValue(fake)`.

@ProviderFor(stadiumRepository)
final stadiumRepositoryProvider = StadiumRepositoryProvider._();

/// 실구현 주입점. 테스트에서 `stadiumRepositoryProvider.overrideWithValue(fake)`.

final class StadiumRepositoryProvider
    extends
        $FunctionalProvider<
          StadiumRepository,
          StadiumRepository,
          StadiumRepository
        >
    with $Provider<StadiumRepository> {
  /// 실구현 주입점. 테스트에서 `stadiumRepositoryProvider.overrideWithValue(fake)`.
  StadiumRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stadiumRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stadiumRepositoryHash();

  @$internal
  @override
  $ProviderElement<StadiumRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StadiumRepository create(Ref ref) {
    return stadiumRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StadiumRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StadiumRepository>(value),
    );
  }
}

String _$stadiumRepositoryHash() => r'ce6cccd36fb70925c9689749d2d9a262f397150d';

/// 실구현 주입점. 테스트에서 `gamesRepositoryProvider.overrideWithValue(fake)`.

@ProviderFor(gamesRepository)
final gamesRepositoryProvider = GamesRepositoryProvider._();

/// 실구현 주입점. 테스트에서 `gamesRepositoryProvider.overrideWithValue(fake)`.

final class GamesRepositoryProvider
    extends
        $FunctionalProvider<GamesRepository, GamesRepository, GamesRepository>
    with $Provider<GamesRepository> {
  /// 실구현 주입점. 테스트에서 `gamesRepositoryProvider.overrideWithValue(fake)`.
  GamesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gamesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gamesRepositoryHash();

  @$internal
  @override
  $ProviderElement<GamesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GamesRepository create(Ref ref) {
    return gamesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GamesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GamesRepository>(value),
    );
  }
}

String _$gamesRepositoryHash() => r'3e792fe9b2bae4eb18b7eccf189a2e707b60ac02';
