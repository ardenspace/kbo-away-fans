/// App Check 활성화가 **한 실행 안에서 다시 시도되는가** — 첫 시도가 실패한
/// 뒤의 자리를 잰다.
///
/// `app_check_activation_test.dart` 는 활성화가 성공하는 실행을 잰다. 여기서
/// 재는 것은 그 반대편이다: `main` 의 1회 호출이 **던져서** 켜지지 않은 실행.
///
/// 그 실행에는 두 갈래가 섞여 있고 결과가 서로 다르다.
///
///  - 설정 파일이 없어서 실패한 갈래 — 인증도 서지 못해 `firebase-unconfigured`
///    로 드러나게 실패한다. App Check 이 조용히 넘어가도 같은 사실이 이미 한 번
///    말해진다(`lib/backend/app_check.dart` 의 문서가 삼킴을 정당화하는 근거).
///  - 설정은 있는데 `activate` 가 일시적으로 던진 갈래 — 인증은 멀쩡히 서고
///    로그인도 된다. 그런데 그 실행의 `kakaoCustomToken` 호출만 App Check 토큰
///    없이 나가고, 함수는 `enforceAppCheck: true` 라 **전부 401 로 거절한다.**
///    사용자에게는 "로그인이 완료되지 않았어요"만 보이고, 앱을 다시 켜기 전까지
///    몇 번을 눌러도 같은 결과다.
///
/// 두 번째 갈래에서 빠져나갈 길은 하나뿐이다 — **다음 카카오 로그인 시도가
/// 활성화를 다시 시도하는 것.** 같은 저장소의 `_ensureGoogleReady`·
/// `_ensureSdkReady` 가 "실패한 시도를 기억하지 않는다"를 명시적 규칙으로 세워
/// 둔 것과 같은 모양이고, 이 파일이 그 규칙을 App Check 자리에서 잰다.
library;

import 'dart:async';

import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/app_check.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/auth_firebase.dart';
import 'package:kbo_away_fans/backend/errors.dart';

import 'fake_backend.dart';

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

/// 활성화가 **던지는** App Check 플랫폼 — 설정은 있는데 `activate` 가 실패한
/// 실행의 대역이다 (`nextError` 를 비우면 그 뒤로는 성공한다).
class _FlakyAppCheck extends FirebaseAppCheckPlatform {
  _FlakyAppCheck() : super();

  static int activateCalls = 0;
  static Object? nextError;

  @override
  FirebaseAppCheckPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAppCheckPlatform setInitialValues() => this;

  @override
  Future<void> activate({
    WebProvider? webProvider,
    // ignore: deprecated_member_use
    AndroidProvider? androidProvider,
    // ignore: deprecated_member_use
    AppleProvider? appleProvider,
    AndroidAppCheckProvider? providerAndroid,
    AppleAppCheckProvider? providerApple,
    WindowsAppCheckProvider? providerWindows,
  }) async {
    activateCalls++;
    final error = nextError;
    if (error != null) throw error;
  }
}

/// 세션이 서지 않아도 되는 최소 인증 플랫폼 — 이 파일이 재는 것은 카카오
/// 경로가 **App Check 을 다시 켜는가**뿐이라, 교환 앞에서 실패시키고 끝낸다.
class _SignedOutAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutAuthPlatform() : super();

  final StreamController<UserPlatform?> native =
      StreamController<UserPlatform?>.broadcast();

  @override
  UserPlatform? get currentUser => null;

  @override
  set currentUser(UserPlatform? user) {}

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  Stream<UserPlatform?> authStateChanges() async* {
    yield null;
    yield* native.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final kakao = FakeKakaoAuthGateway();

  setUpAll(() async {
    FirebasePlatform.instance = _FakeCore();
    FirebaseAppCheckPlatform.instance = _FlakyAppCheck();
    FirebaseAuthPlatform.instance = _SignedOutAuthPlatform();
    await FirebaseAuthService.ensureInitialized(kakaoGateway: kakao);
  });

  test('설정은 있는데 activate 가 던지면 켜지지 않은 채 넘어간다 (앱은 계속 뜬다)', () async {
    _FlakyAppCheck.nextError = StateError('일시적 활성화 실패');

    await BackendAppCheck.ensureInitialized();

    expect(_FlakyAppCheck.activateCalls, 1);
    expect(
      BackendAppCheck.isActivated,
      isFalse,
      reason: '실패한 활성화를 켜졌다고 기억하면 다시 시도할 자리가 사라진다',
    );
  });

  test('그 실행의 다음 카카오 로그인이 활성화를 다시 시도한다', () async {
    _FlakyAppCheck.nextError = null;
    // 교환 앞에서 멈춰 세운다 — 여기서 재는 것은 세션이 아니라 활성화 재시도다.
    kakao.exchangeFailure = const BackendNetworkError(code: 'unavailable');

    await expectLater(
      FirebaseAuthService.instance.signIn(AuthProviderId.kakao),
      throwsA(isA<BackendError>()),
    );

    expect(
      _FlakyAppCheck.activateCalls,
      2,
      reason:
          '커스텀 토큰 함수는 App Check 토큰 없는 호출을 전부 401 로 거절한다 — '
          '첫 활성화가 실패한 실행에서 다시 시도하지 않으면, 앱을 다시 켜기 전까지 '
          '카카오 로그인이 몇 번을 눌러도 같은 자리에서 죽는다',
    );
    expect(BackendAppCheck.isActivated, isTrue);
  });

  test('켜진 뒤의 로그인은 다시 켜지 않는다 (성공은 기억한다)', () async {
    kakao.exchangeFailure = const BackendNetworkError(code: 'unavailable');

    await expectLater(
      FirebaseAuthService.instance.signIn(AuthProviderId.kakao),
      throwsA(isA<BackendError>()),
    );

    expect(_FlakyAppCheck.activateCalls, 2);
  });
}
