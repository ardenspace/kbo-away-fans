// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_team_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 내 응원팀 — 진실의 원천 = `profiles.favorite_team_id` (클라우드, 재설치 생존).
///
/// 상태가 바뀔 때마다(초기 로드·선택) `listenSelf` 로 [CurrentTeam] 에 abbr 를 sync 해
/// 테마 컬러(task-008)를 따라가게 한다. 선택은 낙관적 — 로컬 먼저, DB 실패 시 롤백.

@ProviderFor(FavoriteTeam)
final favoriteTeamProvider = FavoriteTeamProvider._();

/// 내 응원팀 — 진실의 원천 = `profiles.favorite_team_id` (클라우드, 재설치 생존).
///
/// 상태가 바뀔 때마다(초기 로드·선택) `listenSelf` 로 [CurrentTeam] 에 abbr 를 sync 해
/// 테마 컬러(task-008)를 따라가게 한다. 선택은 낙관적 — 로컬 먼저, DB 실패 시 롤백.
final class FavoriteTeamProvider
    extends $AsyncNotifierProvider<FavoriteTeam, Team?> {
  /// 내 응원팀 — 진실의 원천 = `profiles.favorite_team_id` (클라우드, 재설치 생존).
  ///
  /// 상태가 바뀔 때마다(초기 로드·선택) `listenSelf` 로 [CurrentTeam] 에 abbr 를 sync 해
  /// 테마 컬러(task-008)를 따라가게 한다. 선택은 낙관적 — 로컬 먼저, DB 실패 시 롤백.
  FavoriteTeamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoriteTeamProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoriteTeamHash();

  @$internal
  @override
  FavoriteTeam create() => FavoriteTeam();
}

String _$favoriteTeamHash() => r'468346ef14588b9c2da4afdf33168bf8c4f69eb5';

/// 내 응원팀 — 진실의 원천 = `profiles.favorite_team_id` (클라우드, 재설치 생존).
///
/// 상태가 바뀔 때마다(초기 로드·선택) `listenSelf` 로 [CurrentTeam] 에 abbr 를 sync 해
/// 테마 컬러(task-008)를 따라가게 한다. 선택은 낙관적 — 로컬 먼저, DB 실패 시 롤백.

abstract class _$FavoriteTeam extends $AsyncNotifier<Team?> {
  FutureOr<Team?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Team?>, Team?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Team?>, Team?>,
              AsyncValue<Team?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
