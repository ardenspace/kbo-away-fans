/// 카카오 게이트웨이 **주입점 하나**의 성질을 잰다 — 두 번째 호출이 조용히
/// 버려지지 않는가.
///
/// `FirebaseAuthService.ensureInitialized({kakaoGateway})` 는 `_instance ??=` 라,
/// 이미 인스턴스가 서 있으면 새로 넘긴 게이트웨이가 **아무 신호 없이** 무시됐다.
/// 지금은 "테스트 파일당 인스턴스 하나"라는 규약으로 피해 있지만, 같은 프로세스
/// 에서 다른 게이트웨이를 끼우려는 파일이 하나 생기면 옛 것이 조용히 남아
/// 시험은 초록불인 채로 **재는 대상이 바뀐다**. 조용한 무시가 가장 비싼 자리다.
///
/// 그래서 규약을 문서가 아니라 코드가 말하게 한다: 다른 게이트웨이를 끼우려는
/// 두 번째 호출은 [StateError] 로 드러나게 실패한다. 앱의 `main` 은 인수 없이
/// 부르므로 이 갈래에 닿지 않는다.
library;

import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/auth_firebase.dart';

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

/// 세션이 서지 않는 최소 플랫폼 — 이 파일이 재는 것은 주입점뿐이라, 로그인은
/// 게이트웨이까지만 가고 거기서 끝난다.
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

  final first = FakeKakaoAuthGateway();
  final second = FakeKakaoAuthGateway();

  setUpAll(() async {
    FirebasePlatform.instance = _FakeCore();
    FirebaseAuthPlatform.instance = _SignedOutAuthPlatform();
    await FirebaseAuthService.ensureInitialized(kakaoGateway: first);
  });

  test('다른 게이트웨이를 끼우려는 두 번째 호출은 드러나게 실패한다', () async {
    await expectLater(
      FirebaseAuthService.ensureInitialized(kakaoGateway: second),
      throwsStateError,
    );
  });

  test('거절된 뒤에도 서 있는 것은 처음 끼운 게이트웨이다', () async {
    first.loginCalls = 0;
    second.loginCalls = 0;

    try {
      await FirebaseAuthService.instance.signIn(AuthProviderId.kakao);
    } catch (_) {
      // 세션은 서지 않는다 — 여기서 재는 것은 어느 게이트웨이가 불렸는가뿐이다.
    }

    expect(first.loginCalls, 1);
    expect(
      second.loginCalls,
      0,
      reason: '조용히 무시하면 시험은 새 게이트웨이를 끼웠다고 믿으면서 옛 것을 잰다',
    );
  });

  test('같은 게이트웨이를 다시 넘기는 것은 그대로 넘어간다 (멱등)', () async {
    await FirebaseAuthService.ensureInitialized(kakaoGateway: first);
  });

  test('인수 없는 호출은 언제나 그대로 넘어간다 (main 이 부르는 모양)', () async {
    await FirebaseAuthService.ensureInitialized();
  });
}
