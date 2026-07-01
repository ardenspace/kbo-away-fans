// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teams_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 전체 10팀 1회 로드(거의 불변이라 keepAlive). 팀 선택 그리드·abbr↔id 해소의 원천.

@ProviderFor(teams)
final teamsProvider = TeamsProvider._();

/// 전체 10팀 1회 로드(거의 불변이라 keepAlive). 팀 선택 그리드·abbr↔id 해소의 원천.

final class TeamsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Team>>,
          List<Team>,
          FutureOr<List<Team>>
        >
    with $FutureModifier<List<Team>>, $FutureProvider<List<Team>> {
  /// 전체 10팀 1회 로드(거의 불변이라 keepAlive). 팀 선택 그리드·abbr↔id 해소의 원천.
  TeamsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'teamsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$teamsHash();

  @$internal
  @override
  $FutureProviderElement<List<Team>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Team>> create(Ref ref) {
    return teams(ref);
  }
}

String _$teamsHash() => r'786fc1a21ee3c65485be1f82b76ca1dedaa5b525';

/// abbr → Team. 로딩 중이면 빈 맵(룩업은 null).

@ProviderFor(teamsByAbbr)
final teamsByAbbrProvider = TeamsByAbbrProvider._();

/// abbr → Team. 로딩 중이면 빈 맵(룩업은 null).

final class TeamsByAbbrProvider
    extends
        $FunctionalProvider<
          Map<String, Team>,
          Map<String, Team>,
          Map<String, Team>
        >
    with $Provider<Map<String, Team>> {
  /// abbr → Team. 로딩 중이면 빈 맵(룩업은 null).
  TeamsByAbbrProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'teamsByAbbrProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$teamsByAbbrHash();

  @$internal
  @override
  $ProviderElement<Map<String, Team>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, Team> create(Ref ref) {
    return teamsByAbbr(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, Team> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, Team>>(value),
    );
  }
}

String _$teamsByAbbrHash() => r'984af7bf8722b79b062de49a8ae4da0921be9761';

/// id → Team. 로딩 중이면 빈 맵(룩업은 null).

@ProviderFor(teamsById)
final teamsByIdProvider = TeamsByIdProvider._();

/// id → Team. 로딩 중이면 빈 맵(룩업은 null).

final class TeamsByIdProvider
    extends
        $FunctionalProvider<
          Map<String, Team>,
          Map<String, Team>,
          Map<String, Team>
        >
    with $Provider<Map<String, Team>> {
  /// id → Team. 로딩 중이면 빈 맵(룩업은 null).
  TeamsByIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'teamsByIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$teamsByIdHash();

  @$internal
  @override
  $ProviderElement<Map<String, Team>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Map<String, Team> create(Ref ref) {
    return teamsById(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, Team> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, Team>>(value),
    );
  }
}

String _$teamsByIdHash() => r'b108f6f795c0f31103eacebc16ef7bc73df137a1';
