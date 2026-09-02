/// 카카오 커스텀 토큰 경로 — `FirebaseAuthService` **그 자체**를 돌려서 잰다.
///
/// 대역은 둘뿐이다: 카카오의 두 걸음([FakeKakaoAuthGateway])과 Firebase Auth
/// 플랫폼([_FakeAuthPlatform]). 그 사이의 모든 판단 — 교환 결과를 세션으로
/// 옮기고, 세션이 실제로 섰는지 확인하고, 닉네임을 프로필에 심고, 실패를
/// 도메인 오류로 옮기는 자리 — 은 실제 구현이 한다.
///
/// 플랫폼 대역은 `firebase_auth_service_adversarial_probe_test.dart` 의 것과
/// 같은 모양이고(`MethodChannelFirebaseAuth` 를 본뜬 순서), 여기서는
/// `signInWithCustomToken` 과 `updateProfile` 두 자리가 더 있다.
/// `FirebaseAuthService._instance` 는 static 이라 파일 하나에 인스턴스 하나이고,
/// 케이스들은 그 하나를 순서대로 지나간다.
library;

import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/auth_firebase.dart';
import 'package:kbo_away_fans/backend/auth_kakao.dart';
import 'package:kbo_away_fans/backend/errors.dart';

import 'fake_backend.dart';

// ---------------------------------------------------------------- 대역

class _FakeApp extends FirebaseAppPlatform {
  _FakeApp()
    : super(
        defaultFirebaseAppName,
        const FirebaseOptions(
          apiKey: 'fake',
          appId: 'fake',
          messagingSenderId: 'fake',
          projectId: 'fake',
        ),
      );
}

class _FakeCore extends FirebasePlatform {
  final FirebaseAppPlatform _app = _FakeApp();

  @override
  List<FirebaseAppPlatform> get apps => <FirebaseAppPlatform>[_app];

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async => _app;

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) => _app;
}

class _NoMultiFactor extends MultiFactorPlatform {
  _NoMultiFactor(super.auth);
}

/// 프로필 갱신이 **플러그인 캐시의 사용자를 갈아 끼운다**는 성질까지 재현한다
/// (`firebase_auth-6.6.1` 의 `MethodChannelUser.updateProfile`). 이 성질이
/// 없으면 구현이 갱신 뒤에 캐시를 다시 읽는 까닭이 시험에 드러나지 않는다.
class _FakeUser extends UserPlatform {
  _FakeUser(this._platform, String uid, String? displayName)
    : super(
        _platform,
        _NoMultiFactor(_platform),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: uid,
            displayName: displayName,
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: const <Map<Object?, Object?>?>[],
        ),
      );

  final _FakeAuthPlatform _platform;

  /// 프로필 갱신이 실패하는 경우 (구현이 그 실패를 삼키는지 재는 자리).
  static Object? nextUpdateError;

  /// 실제로 서버까지 나간 갱신 값들.
  static final List<String?> updatedDisplayNames = <String?>[];

  @override
  Future<void> updateProfile(Map<String, String?> profile) async {
    final error = nextUpdateError;
    if (error != null) throw error;
    final displayName = profile['displayName'];
    updatedDisplayNames.add(displayName);
    // 캐시의 사용자를 새 객체로 갈아 끼운다 — 자격 증명이 들고 있던 사본은
    // 이 시점부터 옛 값이다.
    _platform.currentUser = _FakeUser(_platform, uid, displayName);
  }
}

class _FakeCredential extends UserCredentialPlatform {
  _FakeCredential({required super.auth, super.user});
}

class _FakeAuthPlatform extends FirebaseAuthPlatform {
  _FakeAuthPlatform() : super();

  final StreamController<UserPlatform?> native =
      StreamController<UserPlatform?>.broadcast();

  UserPlatform? _current;

  /// `signInWithCustomToken` 이 받은 토큰들 — 순서대로.
  final List<String> customTokens = <String>[];

  /// 세션이 서지 않는 경우의 재현: 자격 증명의 user 도 캐시도 비어 있다.
  bool sessionFailsToStand = false;

  /// `signInWithCustomToken` 이 던질 오류 (null 이면 성공).
  Object? nextCustomTokenError;

  @override
  UserPlatform? get currentUser => _current;

  @override
  set currentUser(UserPlatform? user) => _current = user;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  Stream<UserPlatform?> authStateChanges() async* {
    yield currentUser;
    yield* native.stream;
  }

  @override
  Future<UserCredentialPlatform> signInWithCustomToken(String token) async {
    customTokens.add(token);
    final error = nextCustomTokenError;
    if (error != null) throw error;
    if (sessionFailsToStand) {
      _current = null;
      return _FakeCredential(auth: this, user: null);
    }
    // 커스텀 토큰의 uid 는 함수가 정한다 — 대역은 그 값을 교환 결과에서 읽지
    // 않고, 토큰과 짝지어 둔 uid 를 쓴다(실제로도 uid 는 토큰 안에 있다).
    final user = _FakeUser(this, uidForToken(token), null);
    _current = user;
    return _FakeCredential(auth: this, user: user);
  }

  /// 커스텀 토큰 → uid. 같은 토큰이면 같은 uid 다 (함수의 결정적 uid 재현).
  static String uidForToken(String token) => 'kakao:${token.hashCode.abs()}';

  @override
  Future<void> signOut() async {
    _current = null;
    native.add(null);
  }
}

// ---------------------------------------------------------------- 시험

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuthPlatform platform;
  final kakao = FakeKakaoAuthGateway();

  setUpAll(() async {
    FirebasePlatform.instance = _FakeCore();
    platform = _FakeAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    await FirebaseAuthService.ensureInitialized(kakaoGateway: kakao);
  });

  setUp(() {
    kakao
      ..loginFailure = null
      ..exchangeFailure = null
      ..loginCalls = 0
      ..exchangedTokens.clear()
      ..accessToken = 'kakao-access-token'
      ..customToken = const KakaoCustomToken(
        customToken: 'custom-token',
        uid: 'kakao:1234567890',
        nickname: '원정러',
      );
    platform
      ..sessionFailsToStand = false
      ..nextCustomTokenError = null
      ..customTokens.clear();
    _FakeUser.nextUpdateError = null;
    _FakeUser.updatedDisplayNames.clear();
  });

  Future<Object?> signInKakao() async {
    try {
      await FirebaseAuthService.instance.signIn(AuthProviderId.kakao);
      return null;
    } catch (error) {
      return error;
    }
  }

  test('성공: 카카오 액세스 토큰이 그대로 교환에 실려 가고 커스텀 토큰이 세션이 된다', () async {
    final user = await FirebaseAuthService.instance.signIn(
      AuthProviderId.kakao,
    );

    expect(kakao.loginCalls, 1);
    expect(
      kakao.exchangedTokens,
      ['kakao-access-token'],
      reason: 'SDK 가 준 액세스 토큰이 그대로 함수로 가야 한다 — 여기서 값이 바뀌면 함수는 남의 토큰을 검증한다',
    );
    expect(
      platform.customTokens,
      ['custom-token'],
      reason: '함수가 준 커스텀 토큰으로만 세션이 선다',
    );
    expect(user.uid, _FakeAuthPlatform.uidForToken('custom-token'));
  });

  test('성공: 카카오 닉네임이 세션의 표시 이름으로 심긴다 (2.4 의 씨앗값)', () async {
    await FirebaseAuthService.instance.signIn(AuthProviderId.kakao);

    expect(
      _FakeUser.updatedDisplayNames,
      ['원정러'],
      reason: '커스텀 토큰 계정은 표시 이름이 비어 있어서, 심지 않으면 닉네임이 이 자리에서 사라진다',
    );
    expect(
      FirebaseAuthService.instance.currentUser?.displayName,
      '원정러',
      reason: '프로필 갱신이 캐시의 사용자를 갈아 끼우므로, 구현은 갱신된 쪽을 읽어야 한다',
    );
  });

  test('성공: signIn 이 돌아온 직후 동기 조회와 새 구독의 첫 값이 모두 그 사용자다', () async {
    final user = await FirebaseAuthService.instance.signIn(
      AuthProviderId.kakao,
    );

    expect(FirebaseAuthService.instance.currentUser, user);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(authStateProvider, (_, _) {});
    expect(await container.read(authStateProvider.future), user);
  });

  test('같은 카카오 계정으로 다시 로그인하면 같은 uid 에 붙는다', () async {
    final first = await FirebaseAuthService.instance.signIn(
      AuthProviderId.kakao,
    );
    await FirebaseAuthService.instance.signOut();
    final second = await FirebaseAuthService.instance.signIn(
      AuthProviderId.kakao,
    );

    expect(
      second.uid,
      first.uid,
      reason:
          'uid 는 카카오 사용자 id 에서 결정적으로 나온다 — 재로그인이 새 계정을 만들면 '
          '도장과 좋아요가 매번 사라진다',
    );
  });

  test('닉네임이 없으면(동의 안 함) 심지 않고도 로그인은 그대로 성립한다', () async {
    kakao.customToken = const KakaoCustomToken(
      customToken: 'custom-token',
      uid: 'kakao:1234567890',
    );

    final user = await FirebaseAuthService.instance.signIn(
      AuthProviderId.kakao,
    );

    expect(_FakeUser.updatedDisplayNames, isEmpty);
    expect(user.displayName, isNull);
  });

  test('닉네임 심기가 실패해도 로그인은 성공한다 (세션은 이미 섰다)', () async {
    _FakeUser.nextUpdateError = FirebaseAuthException(code: 'unavailable');

    final user = await FirebaseAuthService.instance.signIn(
      AuthProviderId.kakao,
    );

    expect(
      user.displayName,
      isNull,
      reason: '심지 못한 결과는 닉네임에 동의하지 않은 사람과 같은 모양이고, 뒷단계가 이미 다루는 갈래다',
    );
    expect(FirebaseAuthService.instance.currentUser, user);
  });

  test('실패: 카카오 로그인 취소는 권한 갈래로 온다 (교환을 부르지 않는다)', () async {
    kakao.loginFailure = const BackendPermissionError(
      code: kSignInCanceledCode,
    );

    final thrown = await signInKakao();

    expect(thrown, isA<BackendPermissionError>());
    expect((thrown! as BackendError).code, kSignInCanceledCode);
    expect(
      kakao.exchangedTokens,
      isEmpty,
      reason: '취소한 사람의 토큰으로 함수를 부를 일이 없다',
    );
    expect(platform.customTokens, isEmpty);
  });

  test('실패: 함수가 닿지 않으면 네트워크 갈래로 오고 세션은 서지 않는다', () async {
    // callable 실패는 `FirebaseFunctionsException`(= FirebaseException) 으로
    // 오고, 코드 표를 지나 도메인이 정해진다 (`errors.dart`).
    kakao.exchangeFailure = FirebaseException(
      plugin: 'cloud_functions',
      code: 'unavailable',
    );

    final thrown = await signInKakao();

    expect(thrown, isA<BackendNetworkError>());
    expect((thrown! as BackendError).code, 'unavailable');
    expect(
      platform.customTokens,
      isEmpty,
      reason: '교환이 실패한 뒤에 세션을 세우려 들면 빈 토큰으로 SDK 를 부르게 된다',
    );
  });

  test('실패: 함수가 카카오 토큰을 거절하면(unauthenticated) 권한 갈래로 온다', () async {
    kakao.exchangeFailure = FirebaseException(
      plugin: 'cloud_functions',
      code: 'unauthenticated',
    );

    final thrown = await signInKakao();

    expect(thrown, isA<BackendPermissionError>());
    expect((thrown! as BackendError).code, 'unauthenticated');
  });

  test('실패: 커스텀 토큰은 받았는데 세션이 서지 않으면 session-not-established', () async {
    platform.sessionFailsToStand = true;

    final thrown = await signInKakao();

    expect(thrown, isA<BackendUnknownError>());
    expect((thrown! as BackendError).code, kSessionNotEstablishedCode);
  });

  test('실패: signInWithCustomToken 의 SDK 예외도 도메인 오류로 나간다', () async {
    platform.nextCustomTokenError = FirebaseAuthException(
      code: 'invalid-custom-token',
    );

    final thrown = await signInKakao();

    expect(thrown, isA<BackendUnknownError>());
    expect((thrown! as BackendError).code, 'invalid-custom-token');
  });

  test('실패한 로그인 뒤에도 다음 시도는 그대로 성공한다', () async {
    kakao.exchangeFailure = FirebaseException(
      plugin: 'cloud_functions',
      code: 'unavailable',
    );
    expect(await signInKakao(), isA<BackendNetworkError>());

    kakao.exchangeFailure = null;
    expect(await signInKakao(), isNull);
  });
}
