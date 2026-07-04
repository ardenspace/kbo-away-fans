// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stamp_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 기준 시각 seam — R13 잠실 칸 배정의 KST 달력일 계산에 쓴다.
/// 테스트에서 `stampClockProvider.overrideWithValue(() => 고정시각)` 로 주입한다.

@ProviderFor(stampClock)
final stampClockProvider = StampClockProvider._();

/// 기준 시각 seam — R13 잠실 칸 배정의 KST 달력일 계산에 쓴다.
/// 테스트에서 `stampClockProvider.overrideWithValue(() => 고정시각)` 로 주입한다.

final class StampClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// 기준 시각 seam — R13 잠실 칸 배정의 KST 달력일 계산에 쓴다.
  /// 테스트에서 `stampClockProvider.overrideWithValue(() => 고정시각)` 로 주입한다.
  StampClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stampClockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stampClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return stampClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$stampClockHash() => r'09f01d4cdd65fe0246eb7e0fea975c3b5d9a0242';

/// 발급 컨트롤러.

@ProviderFor(StampController)
final stampControllerProvider = StampControllerProvider._();

/// 발급 컨트롤러.
final class StampControllerProvider
    extends $NotifierProvider<StampController, StampIssueState> {
  /// 발급 컨트롤러.
  StampControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stampControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stampControllerHash();

  @$internal
  @override
  StampController create() => StampController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StampIssueState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StampIssueState>(value),
    );
  }
}

String _$stampControllerHash() => r'a20ce19511859a743c30513bfd10b533b41ead6b';

/// 발급 컨트롤러.

abstract class _$StampController extends $Notifier<StampIssueState> {
  StampIssueState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<StampIssueState, StampIssueState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StampIssueState, StampIssueState>,
              StampIssueState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
