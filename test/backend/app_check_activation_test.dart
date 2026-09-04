/// App Check 클라이언트 배선을 **동작으로** 잰다 — 소스 문자열 검사가 아니라.
///
/// `functions/test/index.test.js` 는 함수 쪽 강제(`enforceAppCheck: true`)를 재고,
/// 이 파일은 그 짝인 클라이언트 쪽을 잰다. 둘 중 하나만 서면 아무것도 막지
/// 못하는데(`lib/backend/app_check.dart` 참조), 배선이 통째로 사라져도 나머지
/// 시험은 전부 초록불이라 그 사실이 어디에서도 드러나지 않는다.
///
/// 플랫폼 인터페이스를 갈아 끼워 실제 [BackendAppCheck] 를 돌리는 방식은
/// `firebase_auth_service_adversarial_probe_test.dart` 의 선례와 같다.
///
/// **증명 제공자가 빌드 모드로 갈리는지**도 여기서 잰다 — 릴리스에 디버그
/// 제공자가 실리면 앱에 박힌 토큰 하나로 강제가 통째로 무력해지는데, 그 실수는
/// 빌드에도 analyze 에도 잡히지 않는다 (`.wellbegun/decisions.md` 2026-09-03 [S]).
library;

import 'dart:io';

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

class _FakeAppCheck extends FirebaseAppCheckPlatform {
  _FakeAppCheck() : super();

  static int activateCalls = 0;
  static AndroidAppCheckProvider? lastAndroid;
  static AppleAppCheckProvider? lastApple;
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
    lastAndroid = providerAndroid;
    lastApple = providerApple;
    final error = nextError;
    if (error != null) throw error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FirebasePlatform.instance = _FakeCore();
    FirebaseAppCheckPlatform.instance = _FakeAppCheck();
  });

  test('ensureInitialized 는 실제로 App Check 을 켠다 (배선이 사라지면 여기서 잡힌다)', () async {
    await BackendAppCheck.ensureInitialized();
    expect(_FakeAppCheck.activateCalls, 1);
    expect(BackendAppCheck.isActivated, isTrue);
  });

  test('디버그 실행은 디버그 제공자를 쓴다 (릴리스 제공자와 갈린다)', () async {
    expect(_FakeAppCheck.lastAndroid, isA<AndroidDebugProvider>());
    expect(_FakeAppCheck.lastApple, isA<AppleDebugProvider>());
  });

  test('두 번 불러도 activate 는 한 번이다', () async {
    await BackendAppCheck.ensureInitialized();
    expect(_FakeAppCheck.activateCalls, 1);
  });

  test('사람을 붙잡는 상한이 실제로 사람이 견딜 길이다', () {
    // 상한이 **있는지**는 `kakao_app_check_stall_probe_test.dart` 가 재지만,
    // 그 탐침은 넉넉한 시간(10초)을 밀어 보므로 값이 얼마인지는 말하지 못한다 —
    // 5초를 120초로 바꿔도 저 탐침만 빼면 전체가 초록불이었다. 이 상수는
    // "얼마면 켜지는가"가 아니라 "얼마부터 사람이 앱이 죽었다고 읽는가"의
    // 값이므로(`app_check.dart` 의 주석), 그 길이 자체를 여기서 못 박는다.
    // 짝인 서버 상한 `kProfileServerConfirmGrace` 에 같은 모양의 시험이 이미
    // 서 있다 (`probe_profile_watch_wiring_test.dart`).
    expect(kAppCheckActivationTimeout, greaterThan(Duration.zero));
    expect(
      kAppCheckActivationTimeout,
      lessThanOrEqualTo(const Duration(seconds: 10)),
      reason: '이 값이 곧 스플래시가 걷히지 않는 최대 시간이고, 카카오 로그인 버튼이 '
          '잠긴 채 스피너만 도는 최대 시간이다 — 늘리면 그만큼 사람이 앉아 있는다',
    );
  });

  _releaseBranchStandsInSource();
}

/// 릴리스 갈래는 **동작으로 잴 수 없다** — `flutter test` 는 언제나 디버그라
/// `kDebugMode` 가 참이고, 그래서 위 시험은 릴리스에 무엇이 실리는지 말하지
/// 못한다. 그런데 거기서 나는 실수(릴리스에 디버그 제공자가 실림)는 App Check
/// 을 통째로 무력화한다 — 앱에 박힌 토큰 하나면 누구나 함수를 부를 수 있다.
/// 빌드에도 analyze 에도 잡히지 않으므로, 잴 수 있는 만큼만이라도 여기서 잰다:
/// **갈림 자체와 릴리스 쪽 제공자 이름이 소스에 서 있는가.**
void _releaseBranchStandsInSource() {
  test('릴리스 갈래가 소스에 서 있다 (디버그 제공자가 릴리스로 새지 않는다)', () {
    final source = File('lib/backend/app_check.dart').readAsStringSync();

    expect(
      source.contains('kDebugMode'),
      isTrue,
      reason: '갈림이 사라지면 한쪽 제공자가 두 빌드 모두에 실린다',
    );
    expect(
      source.contains('AndroidPlayIntegrityProvider'),
      isTrue,
      reason: '릴리스 안드로이드의 증명 제공자가 사라졌다 — 디버그 토큰만 남으면 강제가 무력해진다',
    );
    expect(
      source.contains('AppleDeviceCheckProvider'),
      isTrue,
      reason: '릴리스 iOS 의 증명 제공자가 사라졌다',
    );
  });
}
