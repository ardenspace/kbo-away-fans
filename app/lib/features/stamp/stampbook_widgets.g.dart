// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stampbook_widgets.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 스탬프북 데이터 — 구장 목록 + 내 스탬프를 합쳐 칸별 방문 여부로 만든다.
///
/// 클라우드가 진실원천 (R6): 두 원격 조회 중 하나라도 실패하면 AsyncError 로
/// 전파되어 화면이 오류+재시도를 그린다. 로컬 폴백 없음.

@ProviderFor(stampbook)
final stampbookProvider = StampbookProvider._();

/// 스탬프북 데이터 — 구장 목록 + 내 스탬프를 합쳐 칸별 방문 여부로 만든다.
///
/// 클라우드가 진실원천 (R6): 두 원격 조회 중 하나라도 실패하면 AsyncError 로
/// 전파되어 화면이 오류+재시도를 그린다. 로컬 폴백 없음.

final class StampbookProvider
    extends
        $FunctionalProvider<
          AsyncValue<StampbookView>,
          StampbookView,
          FutureOr<StampbookView>
        >
    with $FutureModifier<StampbookView>, $FutureProvider<StampbookView> {
  /// 스탬프북 데이터 — 구장 목록 + 내 스탬프를 합쳐 칸별 방문 여부로 만든다.
  ///
  /// 클라우드가 진실원천 (R6): 두 원격 조회 중 하나라도 실패하면 AsyncError 로
  /// 전파되어 화면이 오류+재시도를 그린다. 로컬 폴백 없음.
  StampbookProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stampbookProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stampbookHash();

  @$internal
  @override
  $FutureProviderElement<StampbookView> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<StampbookView> create(Ref ref) {
    return stampbook(ref);
  }
}

String _$stampbookHash() => r'2f04ec085301a657863851a2f21833ec48d758a9';
