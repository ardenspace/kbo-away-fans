// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'away_games_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 내 팀 원정 경기(= 내 팀이 away) 다가오는 순. on-demand: 화면 진입마다 DB 최신 1회 조회
/// (autoDispose → 재진입 = 재조회). 크롤러(task-006)가 유지하는 상태를 읽기만 한다.

@ProviderFor(awayGames)
final awayGamesProvider = AwayGamesProvider._();

/// 내 팀 원정 경기(= 내 팀이 away) 다가오는 순. on-demand: 화면 진입마다 DB 최신 1회 조회
/// (autoDispose → 재진입 = 재조회). 크롤러(task-006)가 유지하는 상태를 읽기만 한다.

final class AwayGamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Game>>,
          List<Game>,
          FutureOr<List<Game>>
        >
    with $FutureModifier<List<Game>>, $FutureProvider<List<Game>> {
  /// 내 팀 원정 경기(= 내 팀이 away) 다가오는 순. on-demand: 화면 진입마다 DB 최신 1회 조회
  /// (autoDispose → 재진입 = 재조회). 크롤러(task-006)가 유지하는 상태를 읽기만 한다.
  AwayGamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'awayGamesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$awayGamesHash();

  @$internal
  @override
  $FutureProviderElement<List<Game>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Game>> create(Ref ref) {
    return awayGames(ref);
  }
}

String _$awayGamesHash() => r'86e2bf6ee200393d0b200869b96ddf358b5f1c7f';
