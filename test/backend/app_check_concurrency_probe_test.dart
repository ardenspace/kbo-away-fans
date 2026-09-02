/// App Check 활성화의 **겹친 호출**을 잰다 — 순서대로 부르는 경우가 아니라.
///
/// `app_check_activation_test.dart`·`app_check_retry_test.dart` 는 호출이
/// 하나씩 끝난 뒤 다음이 오는 경우를 잰다. 실제 앱에서 이 두 호출은 겹칠 수
/// 있다: `main` 이 켠 시도가 아직 플랫폼 채널 위에 있는 동안 사람이 카카오
/// 로그인을 누르면, `_signInWithKakao` 가 같은 자리를 한 번 더 부른다.
///
/// 그때 잘못될 수 있는 것이 둘이다.
///
///  - **두 번 켜기.** `FirebaseAppCheck.activate` 가 두 번 나가면 증명 제공자
///    등록이 겹치고, 디버그 제공자에서는 토큰이 다시 발급된다.
///  - **재시도 자리를 잃기.** 겹친 두 호출이 함께 실패했는데 그 실패를 기억해
///    버리면, 그 실행에서 App Check 을 다시 켤 길이 사라진다 — 함수가
///    `enforceAppCheck: true` 라 그 실행의 카카오 로그인은 앱을 다시 켜기
///    전까지 전부 401 로 죽는다.
///
/// 그래서 여기서는 `activate` 를 **완료를 미룰 수 있는 대역**으로 갈아 끼워
/// 겹치는 창을 실제로 만든다.
library;

import 'dart:async';

import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/app_check.dart';

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

/// 완료를 테스트가 쥐고 있는 App Check 플랫폼 — 겹치는 창을 만드는 대역.
class _HeldAppCheck extends FirebaseAppCheckPlatform {
  _HeldAppCheck() : super();

  static int activateCalls = 0;
  static Completer<void>? held;
  static Completer<void>? entered;
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
    if (entered != null && !entered!.isCompleted) entered!.complete();
    final gate = held;
    if (gate != null) await gate.future;
    final error = nextError;
    if (error != null) throw error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FirebasePlatform.instance = _FakeCore();
    FirebaseAppCheckPlatform.instance = _HeldAppCheck();
  });

  test('겹친 두 호출이 함께 실패해도 재시도 자리가 남는다', () async {
    // 첫 시도를 열어 둔 채 두 번째 호출이 들어온다 — `main` 의 활성화가 아직
    // 끝나지 않았는데 사람이 카카오 로그인을 누른 모양이다.
    final gate = _HeldAppCheck.held = Completer<void>();
    final entered = _HeldAppCheck.entered = Completer<void>();
    _HeldAppCheck.nextError = StateError('일시적 활성화 실패');

    final first = BackendAppCheck.ensureInitialized();
    final second = BackendAppCheck.ensureInitialized();

    // 첫 시도가 `activate` 안에 들어가 멈춰 선 창 — 두 호출이 실제로 겹쳐 있다.
    await entered.future;

    expect(
      _HeldAppCheck.activateCalls,
      1,
      reason: '겹친 호출은 같은 시도를 함께 기다려야 한다 — 두 번 켜면 제공자 등록이 겹친다',
    );

    gate.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(
      BackendAppCheck.isActivated,
      isFalse,
      reason: '실패한 활성화는 켜졌다고 기억하지 않는다',
    );

    // 그 실행의 다음 시도가 처음부터 다시 켤 수 있어야 한다. 이것이 없으면
    // 함수의 `enforceAppCheck: true` 앞에서 그 실행의 카카오 로그인이 전부
    // 401 로 죽고, 빠져나갈 길은 앱을 다시 켜는 것뿐이다.
    _HeldAppCheck.held = null;
    _HeldAppCheck.entered = null;
    _HeldAppCheck.nextError = null;
    await BackendAppCheck.ensureInitialized();

    expect(_HeldAppCheck.activateCalls, 2);
    expect(BackendAppCheck.isActivated, isTrue);
  });

  test('켜진 뒤에는 겹쳐 불러도 다시 켜지 않는다', () async {
    await Future.wait(<Future<void>>[
      BackendAppCheck.ensureInitialized(),
      BackendAppCheck.ensureInitialized(),
    ]);

    expect(_HeldAppCheck.activateCalls, 2);
  });
}
