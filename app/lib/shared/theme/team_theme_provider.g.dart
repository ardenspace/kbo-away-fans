// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'team_theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 현재 응원팀 abbr. `null` = 미선택(중립 테마).
///
/// task-010(응원팀 설정 UI)·task-009(프로필 영속화)에서 이 notifier 에 연결된다.
/// 지금은 런타임 상태만 들고 영속화는 하지 않는다.

@ProviderFor(CurrentTeam)
final currentTeamProvider = CurrentTeamProvider._();

/// 현재 응원팀 abbr. `null` = 미선택(중립 테마).
///
/// task-010(응원팀 설정 UI)·task-009(프로필 영속화)에서 이 notifier 에 연결된다.
/// 지금은 런타임 상태만 들고 영속화는 하지 않는다.
final class CurrentTeamProvider
    extends $NotifierProvider<CurrentTeam, String?> {
  /// 현재 응원팀 abbr. `null` = 미선택(중립 테마).
  ///
  /// task-010(응원팀 설정 UI)·task-009(프로필 영속화)에서 이 notifier 에 연결된다.
  /// 지금은 런타임 상태만 들고 영속화는 하지 않는다.
  CurrentTeamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentTeamProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentTeamHash();

  @$internal
  @override
  CurrentTeam create() => CurrentTeam();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentTeamHash() => r'588ba5912ca9dcc138646a274cdfbfb9559ed6fe';

/// 현재 응원팀 abbr. `null` = 미선택(중립 테마).
///
/// task-010(응원팀 설정 UI)·task-009(프로필 영속화)에서 이 notifier 에 연결된다.
/// 지금은 런타임 상태만 들고 영속화는 하지 않는다.

abstract class _$CurrentTeam extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// 현재 팀에서 파생되는 앱 테마. 미선택이거나 알 수 없는 abbr 이면 중립 테마.

@ProviderFor(teamTheme)
final teamThemeProvider = TeamThemeProvider._();

/// 현재 팀에서 파생되는 앱 테마. 미선택이거나 알 수 없는 abbr 이면 중립 테마.

final class TeamThemeProvider
    extends $FunctionalProvider<ThemeData, ThemeData, ThemeData>
    with $Provider<ThemeData> {
  /// 현재 팀에서 파생되는 앱 테마. 미선택이거나 알 수 없는 abbr 이면 중립 테마.
  TeamThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'teamThemeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$teamThemeHash();

  @$internal
  @override
  $ProviderElement<ThemeData> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeData create(Ref ref) {
    return teamTheme(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeData>(value),
    );
  }
}

String _$teamThemeHash() => r'0a1a09be8c459540dfb5ed716245a932ed59e969';
