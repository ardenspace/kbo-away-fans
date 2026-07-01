// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stadium_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 구장 상세 — id 로 1행 조회. on-demand: 화면 진입마다 최신 1회(autoDispose → 재진입=재조회).
/// task-010 awayGames 와 같은 읽기 패턴.

@ProviderFor(stadium)
final stadiumProvider = StadiumFamily._();

/// 구장 상세 — id 로 1행 조회. on-demand: 화면 진입마다 최신 1회(autoDispose → 재진입=재조회).
/// task-010 awayGames 와 같은 읽기 패턴.

final class StadiumProvider
    extends $FunctionalProvider<AsyncValue<Stadium>, Stadium, FutureOr<Stadium>>
    with $FutureModifier<Stadium>, $FutureProvider<Stadium> {
  /// 구장 상세 — id 로 1행 조회. on-demand: 화면 진입마다 최신 1회(autoDispose → 재진입=재조회).
  /// task-010 awayGames 와 같은 읽기 패턴.
  StadiumProvider._({
    required StadiumFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'stadiumProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$stadiumHash();

  @override
  String toString() {
    return r'stadiumProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Stadium> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Stadium> create(Ref ref) {
    final argument = this.argument as String;
    return stadium(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is StadiumProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$stadiumHash() => r'c3105878072adbb5d09634c9a9fe892460f494d1';

/// 구장 상세 — id 로 1행 조회. on-demand: 화면 진입마다 최신 1회(autoDispose → 재진입=재조회).
/// task-010 awayGames 와 같은 읽기 패턴.

final class StadiumFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Stadium>, String> {
  StadiumFamily._()
    : super(
        retry: null,
        name: r'stadiumProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 구장 상세 — id 로 1행 조회. on-demand: 화면 진입마다 최신 1회(autoDispose → 재진입=재조회).
  /// task-010 awayGames 와 같은 읽기 패턴.

  StadiumProvider call(String id) =>
      StadiumProvider._(argument: id, from: this);

  @override
  String toString() => r'stadiumProvider';
}
