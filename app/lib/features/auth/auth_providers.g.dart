// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 로그인/가입/카카오/로그아웃 액션 + 진행상태(AsyncValue).
///
/// 세션 자체는 supabase_flutter 가 들고 라우터가 `currentSession` 으로 게이팅한다.
/// 이 컨트롤러는 "동작 트리거 + 로딩/에러" 만 담당한다.

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// 로그인/가입/카카오/로그아웃 액션 + 진행상태(AsyncValue).
///
/// 세션 자체는 supabase_flutter 가 들고 라우터가 `currentSession` 으로 게이팅한다.
/// 이 컨트롤러는 "동작 트리거 + 로딩/에러" 만 담당한다.
final class AuthControllerProvider
    extends $AsyncNotifierProvider<AuthController, void> {
  /// 로그인/가입/카카오/로그아웃 액션 + 진행상태(AsyncValue).
  ///
  /// 세션 자체는 supabase_flutter 가 들고 라우터가 `currentSession` 으로 게이팅한다.
  /// 이 컨트롤러는 "동작 트리거 + 로딩/에러" 만 담당한다.
  AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();
}

String _$authControllerHash() => r'4bb42dde037baa37a9ff059f875e61a6dcaa4276';

/// 로그인/가입/카카오/로그아웃 액션 + 진행상태(AsyncValue).
///
/// 세션 자체는 supabase_flutter 가 들고 라우터가 `currentSession` 으로 게이팅한다.
/// 이 컨트롤러는 "동작 트리거 + 로딩/에러" 만 담당한다.

abstract class _$AuthController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
