/// 적대적 탐침 2 — "첫 null 하나만 버린다"는 판별의 바닥을 재는 자리.
///
/// `FirebaseAuthService._bindSessionStream` 은 SDK 스트림의 첫 값이 null 이면
/// **무조건** 버린다. 그 판별에는 "이 null 이 Dart 캐시의 빈 값인가, 네이티브가
/// 말한 확정된 로그아웃인가"를 가르는 근거가 없고, 오직 **네이티브의 첫 이벤트가
/// 구독보다 늦게 온다**는 순서 가정 하나만 있다.
///
/// 오늘의 앱에서 그 가정은 참이다: `FirebaseAuth` 의 delegate 는 게으르게
/// 만들어지고(`_delegatePackingProperty ??=`), 그 delegate 를 처음 건드리는 자리가
/// `_bindSessionStream` 안의 `authStateChanges()` 그 자체라, 네이티브 리스너 등록
/// (pigeon 왕복)이 시작되기도 전에 Dart 쪽 구독이 이미 붙어 있다.
///
/// 이 탐침은 그 순서가 뒤집혔을 때 무슨 일이 일어나는지를 못 박는다. 뒤집히는
/// 경로는 하나뿐이다: **누군가 `ensureInitialized` 보다 먼저 `FirebaseAuth` 의
/// delegate 를 만든다**(`FirebaseAuth.instance.currentUser` 를 읽기만 해도 만들어
/// 진다). 2.3·2.4 가 카카오 커스텀 토큰이나 사용자 문서를 붙이면서 그런 자리를
/// 하나 만들면, **로그아웃한 사람의 콜드 스타트가 로그인 화면이 아니라 영원한
/// 스피너가 된다** — 로그인 화면이 뜨지 않으므로 나갈 길도 없다.
library;

import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/auth_firebase.dart';

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

/// 네이티브가 **이미** "로그아웃"이라고 말해 둔 뒤의 플랫폼 상태.
///
/// 실 플러그인과 같은 모양이다: 이벤트는 replay 없는 broadcast 컨트롤러로
/// 흘렀고(구독자가 없었으므로 사라졌다), 그 사실은 Dart 캐시 `currentUser` 에만
/// null 로 남아 있다. 확정된 로그아웃과 아직 모름이 같은 null 이 되는 그 자리다.
class _AlreadySignedOutPlatform extends FirebaseAuthPlatform {
  _AlreadySignedOutPlatform() : super();

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
    yield currentUser;
    yield* native.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('네이티브의 첫 이벤트가 구독보다 먼저 지나가면 로그아웃이 영영 확정되지 않는다', () async {
    FirebasePlatform.instance = _FakeCore();
    final platform = _AlreadySignedOutPlatform();
    FirebaseAuthPlatform.instance = platform;

    // 구독 전에 네이티브가 이미 말했다 — 컨트롤러에 구독자가 없어 사라진다.
    platform.native.add(null);

    await FirebaseAuthService.ensureInitialized();

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(authStateProvider, (_, _) {});
    await pumpEventQueue();

    // 이 사람은 **확정된 로그아웃**이다. 게이트는 로그인 화면을 띄워야 한다.
    // 그런데 구현은 그 null 을 "Dart 캐시의 빈 값"으로 읽고 버렸다.
    expect(
      sub.read().hasValue,
      isTrue,
      reason:
          '확정된 로그아웃인데 값이 없으면 게이트가 로딩 갈래(스피너)에 갇힌다 — '
          '로그인 화면이 뜨지 않으므로 사용자가 빠져나갈 길이 없다',
    );
    expect(sub.read().value, isNull);
  });
}
