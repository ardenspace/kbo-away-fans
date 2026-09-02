/// 적대적 탐침 — `FirebaseAuthService` **그 자체**를 플랫폼 인터페이스 대역
/// 위에서 돌린다.
///
/// 트리에 이미 있는 2.2 테스트는 전부 `AuthService` 를 손으로 구현한 대역
/// (`FakeAuthService`·`UnknownSessionAuthService`·`_FlickerAuth` …)만 돌린다.
/// 그 대역들은 이번 단계에서 "구독하는 순간 아는 상태를 흘린다" 계약에 맞게
/// 고쳐졌으므로, 게이트가 통과하는 것은 **계약을 지키는 구현이 있다면** 게이트가
/// 옳다는 뜻일 뿐이다. 앱이 실제로 쓰는 구현(`FirebaseAuthService`)이 그 계약을
/// 지키는지는 한 줄도 재고 있지 않다.
///
/// 이 탐침은 `FirebaseAuthPlatform` 을 갈아 끼워 그 빈자리를 메운다. 대역의
/// `authStateChanges()` 는 `firebase_auth_platform_interface-9.0.7` 의
/// `MethodChannelFirebaseAuth.authStateChanges()`(`async* { yield currentUser;
/// yield* _authStateChangesListeners[...].stream }`) 를 그대로 베낀 모양이라,
/// 구현이 기대는 "첫 값은 Dart 캐시, 그다음부터 네이티브"라는 성질을 실제 SDK 와
/// 같은 순서로 재현한다.
///
/// `FirebaseAuthService._instance` 는 static 이고 되돌릴 길이 없으므로 이 파일의
/// 케이스들은 **한 인스턴스를 순서대로** 지나간다. 순서가 곧 시나리오다.
library;

import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/auth_firebase.dart';
import 'package:kbo_away_fans/backend/errors.dart';

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

class _FakeUser extends UserPlatform {
  _FakeUser(FirebaseAuthPlatform auth, String uid, String? displayName)
    : super(
        auth,
        _NoMultiFactor(auth),
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
}

class _FakeCredential extends UserCredentialPlatform {
  _FakeCredential({required super.auth, super.user});
}

class _FakeAuthPlatform extends FirebaseAuthPlatform {
  _FakeAuthPlatform() : super();

  /// 네이티브 인증 리스너가 흘리는 이벤트 — 실 플러그인의 broadcast 컨트롤러와
  /// 같은 자리다 (구독 전에 흘린 값은 아무도 못 받는다).
  final StreamController<UserPlatform?> native =
      StreamController<UserPlatform?>.broadcast();

  UserPlatform? _current;

  /// `signInWithProvider` 가 돌려줄 자격 증명 (null 이면 예외를 던진다).
  UserPlatform? nextCredentialUser;
  Object? nextCredentialError;

  /// 자격 증명의 `user` 를 비워 둘까 — "제공자는 끝났는데 세션이 없다"의 재현.
  bool credentialUserIsNull = false;

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

  /// 네이티브가 말했다 — Dart 캐시를 채우고 이벤트를 흘린다 (실 플러그인의
  /// `_handleAuthStateChangesListener` 와 같은 순서).
  void emitNative(UserPlatform? user) {
    _current = user;
    native.add(user);
  }

  @override
  Future<UserCredentialPlatform> signInWithProvider(
    AuthProvider provider,
  ) async {
    final error = nextCredentialError;
    if (error != null) throw error;
    if (!credentialUserIsNull) _current = nextCredentialUser;
    return _FakeCredential(
      auth: this,
      user: credentialUserIsNull ? null : nextCredentialUser,
    );
  }

  @override
  Future<void> signOut() async => emitNative(null);
}

// ---------------------------------------------------------------- 탐침

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuthPlatform platform;

  setUpAll(() async {
    FirebasePlatform.instance = _FakeCore();
    platform = _FakeAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    await FirebaseAuthService.ensureInitialized();
  });

  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('탐침 1: 설정이 있는 실행이면 instance 가 선다 (unconfigured 로 던지지 않는다)', () {
    expect(FirebaseAuthService.instance, isA<AuthService>());
  });

  // 탐침 2·3 의 첫 단언은 원래 "네이티브가 말하기 전에는 값이 없다"였다
  // (`isLoading isTrue`). 그 전제 — 플러그인이 네이티브의 첫 인증 이벤트로만
  // Dart 캐시를 채운다 — 는 SDK 를 읽어 보니 사실이 아니었다: `initializeApp()`
  // 이 돌려주는 플러그인 상수 `APP_CURRENT_USER` 가 delegate 를 만들 때
  // `setInitialValues` 로 캐시에 심긴다. 그래서 초기화가 끝난 뒤의 캐시는
  // 확정된 상태이고, 구현은 그 값으로 세션을 곧바로 확정한다
  // (`auth_firebase.dart` 의 `_bindSessionStream` 문서 참조).
  // 2026-09-02, 필수 1 수정에서 전제가 깨진 두 줄만 오늘의 사실로 바꾼다.
  test('탐침 2: 초기화가 끝나면 세션 상태가 곧바로 확정된다 (빈 캐시 = 확정된 로그아웃)', () async {
    final c = container();
    final sub = c.listen(authStateProvider, (_, _) {});
    await pumpEventQueue();

    expect(
      sub.read().hasValue,
      isTrue,
      reason: '확정된 상태를 값으로 내지 않으면 게이트가 로딩 갈래(스피너)에 갇힌다',
    );
    expect(sub.read().value, isNull);
    expect(FirebaseAuthService.instance.currentUser, isNull);
  });

  test('탐침 3: 네이티브가 "로그아웃"이라고 말해도 값은 그대로 null 이다', () async {
    final c = container();
    final sub = c.listen(authStateProvider, (_, _) {});
    await pumpEventQueue();
    expect(sub.read().value, isNull);

    platform.emitNative(null);
    await pumpEventQueue();

    expect(
      sub.read().hasValue,
      isTrue,
      reason: '실제 로그아웃까지 로딩으로 남으면 로그인 화면이 영영 안 뜬다',
    );
    expect(sub.read().value, isNull);
  });

  test('탐침 4: 네이티브가 사용자를 말하면 그 값이 흐르고 표시 이름 빈 문자열은 null 로 접힌다', () async {
    final c = container();
    final sub = c.listen(authStateProvider, (_, _) {});
    await pumpEventQueue();

    platform.emitNative(_FakeUser(platform, 'uid-native', ''));
    await pumpEventQueue();

    expect(sub.read().value, const AuthUser(uid: 'uid-native'));
    expect(sub.read().value!.displayName, isNull);
  });

  test('탐침 5: 이미 아는 상태가 있으면 새 구독은 그 값부터 받는다 (invalidate 뒤의 첫 값)', () async {
    final c = container();
    final sub = c.listen(authStateProvider, (_, _) {});
    await pumpEventQueue();
    expect(sub.read().value, const AuthUser(uid: 'uid-native'));

    c.invalidate(authStateProvider);
    final first = await c.read(authStateProvider.future);

    expect(
      first,
      const AuthUser(uid: 'uid-native'),
      reason: '로그인 화면의 세션 판정이 이 첫 값을 그대로 기다린다',
    );
  });

  test('탐침 6: 카카오는 조용히 성공하지 않고 provider-not-wired 로 실패한다', () async {
    Object? thrown;
    try {
      await FirebaseAuthService.instance.signIn(AuthProviderId.kakao);
    } catch (error) {
      thrown = error;
    }
    expect(thrown, isA<BackendUnknownError>());
    expect((thrown! as BackendError).code, kSignInProviderNotWiredCode);
  });

  test('탐침 7: 애플 취소(FirebaseAuthException canceled)는 권한 갈래로 옮겨진다', () async {
    platform.nextCredentialError = FirebaseAuthException(code: 'canceled');
    Object? thrown;
    try {
      await FirebaseAuthService.instance.signIn(AuthProviderId.apple);
    } catch (error) {
      thrown = error;
    }
    platform.nextCredentialError = null;

    expect(thrown, isA<BackendPermissionError>());
    expect((thrown! as BackendError).code, 'canceled');
  });

  test('탐침 8: 제공자는 끝났는데 세션이 없으면 session-not-established 로 실패한다', () async {
    // 자격 증명의 user 도 null 이고 세션의 currentUser 도 null 인 상태를 만든다.
    platform.currentUser = null;
    platform.credentialUserIsNull = true;

    Object? thrown;
    try {
      await FirebaseAuthService.instance.signIn(AuthProviderId.apple);
    } catch (error) {
      thrown = error;
    }
    platform.credentialUserIsNull = false;

    expect(thrown, isA<BackendUnknownError>());
    expect((thrown! as BackendError).code, kSessionNotEstablishedCode);
  });

  test('탐침 9: 성공한 signIn 직후 currentUser 가 채워지고 새 구독의 첫 값이 그 사용자다', () async {
    platform.nextCredentialUser = _FakeUser(platform, 'uid-apple', '원정러');

    final user = await FirebaseAuthService.instance.signIn(
      AuthProviderId.apple,
    );

    expect(user, const AuthUser(uid: 'uid-apple', displayName: '원정러'));
    expect(
      FirebaseAuthService.instance.currentUser,
      const AuthUser(uid: 'uid-apple', displayName: '원정러'),
      reason: '계약 2항이 명시한 확인 — signIn 성공 직후 currentUser 가 실제로 찬다',
    );

    // 게이트가 늘 구독을 붙들고 있는 실제 배치를 그대로 만든다 — riverpod 3 의
    // provider 는 기본이 auto-dispose 라, 구독 없이 `.future` 만 읽으면 첫 값이
    // 나오기 전에 element 가 버려진다 (로그인 화면의 판정은 게이트가 구독 중인
    // 상태에서만 도므로 이것이 실제 배치다).
    final c = container();
    c.listen(authStateProvider, (_, _) {});
    expect(
      await c.read(authStateProvider.future),
      const AuthUser(uid: 'uid-apple', displayName: '원정러'),
    );
  });

  test('탐침 10: 스트림 오류는 도메인 오류로 옮겨진다 (SDK 예외가 새지 않는다)', () async {
    final c = container();
    final sub = c.listen(authStateProvider, (_, _) {});
    await pumpEventQueue();

    platform.native.addError(FirebaseAuthException(code: 'unavailable'));
    await pumpEventQueue();

    expect(sub.read().hasError, isTrue);
    expect(sub.read().error, isA<BackendError>());
  });

  test('탐침 11: 오류 뒤에도 로그인은 다시 살아난다 (다시 세운 provider 의 첫 값)', () async {
    platform.nextCredentialUser = _FakeUser(platform, 'uid-again', null);

    await FirebaseAuthService.instance.signIn(AuthProviderId.apple);

    final c = container();
    c.listen(authStateProvider, (_, _) {});
    expect(
      await c.read(authStateProvider.future),
      const AuthUser(uid: 'uid-again'),
    );
  });
}
