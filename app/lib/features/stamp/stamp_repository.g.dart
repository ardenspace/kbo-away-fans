// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stamp_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 실구현 주입점. 테스트에서 `stampRepositoryProvider.overrideWithValue(fake)`.

@ProviderFor(stampRepository)
final stampRepositoryProvider = StampRepositoryProvider._();

/// 실구현 주입점. 테스트에서 `stampRepositoryProvider.overrideWithValue(fake)`.

final class StampRepositoryProvider
    extends
        $FunctionalProvider<StampRepository, StampRepository, StampRepository>
    with $Provider<StampRepository> {
  /// 실구현 주입점. 테스트에서 `stampRepositoryProvider.overrideWithValue(fake)`.
  StampRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stampRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stampRepositoryHash();

  @$internal
  @override
  $ProviderElement<StampRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StampRepository create(Ref ref) {
    return stampRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StampRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StampRepository>(value),
    );
  }
}

String _$stampRepositoryHash() => r'2d679d24d727dea0608147a63b9c4e5392fa7786';
