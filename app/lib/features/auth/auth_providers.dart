import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

part 'auth_providers.g.dart';

/// 로그인/가입/카카오/로그아웃 액션 + 진행상태(AsyncValue).
///
/// 세션 자체는 supabase_flutter 가 들고 라우터가 `currentSession` 으로 게이팅한다.
/// 이 컨트롤러는 "동작 트리거 + 로딩/에러" 만 담당한다.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {}

  SupabaseClient get _client => ref.read(supabaseClientProvider);

  /// 커스텀 스킴 콜백 — GoTrue 웹 OAuth 가 카카오 로그인 후 앱으로 복귀하는 주소.
  /// 네이티브 딥링크 설정(AndroidManifest / Info.plist)·GoTrue redirect allowlist 와 일치해야 한다.
  static const _redirectUri = 'kboaway://login-callback';

  Future<void> signInEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signInWithPassword(email: email, password: password);
    });
  }

  Future<void> signUpEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signUp(email: email, password: password);
    });
  }

  Future<void> signInKakao() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _client.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: _redirectUri,
      );
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_client.auth.signOut);
  }
}
