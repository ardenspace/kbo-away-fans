/// 적대적 탐침 3 의 짝 — 로그아웃한 사람의 생성 직후 동기 조회.
///
/// `firebase_auth_restored_session_sync_probe_test.dart` 는 세션이 복원된 쪽을
/// 잰다. 그런데 `_bindSessionStream` 의 첫 줄이 지키는 보장은 "값이 찬다"가
/// 아니라 "**지금의 사실을 답한다**"이므로, 로그아웃한 사람에게 null 을 답하는
/// 것도 같은 보장의 반쪽이다. 그 반쪽이 없으면 "생성 직후에는 무조건 사용자가
/// 있다"는 식의 채우기로도 앞의 탐침을 통과시킬 수 있다.
///
/// 여기서도 대역의 되풀이를 완료기로 붙들어 두고 그 전의 창에서 읽는다 —
/// 스트림을 pump 한 뒤에 재면 무엇을 재는지가 흐려지기 때문이다.
///
/// `FirebaseAuthService._instance` 는 static 이라 한 파일에 인스턴스는 하나뿐이고,
/// 그 하나가 태어나는 상태가 곧 시나리오다. 그래서 이 짝이 별도 파일에 있다.
library;

import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/auth_firebase.dart';

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
  _FakeUser(FirebaseAuthPlatform auth, String uid)
    : super(
        auth,
        _NoMultiFactor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: uid,
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: const <Map<Object?, Object?>?>[],
        ),
      );
}

/// 복원할 세션이 없는 실행 — Dart 캐시가 비어 있고, 그 빈 값이 **확정된
/// 로그아웃**이다 (`_bindSessionStream` 문서의 그 판단).
class _SignedOutPlatform extends FirebaseAuthPlatform {
  _SignedOutPlatform() : super();

  final StreamController<UserPlatform?> native =
      StreamController<UserPlatform?>.broadcast();

  /// 열기 전까지 구독의 첫 되풀이를 붙들어 둔다.
  final Completer<void> replayGate = Completer<void>();

  UserPlatform? _current;

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
    await replayGate.future;
    yield currentUser;
    yield* native.stream;
  }

  void emitNative(UserPlatform? user) {
    _current = user;
    native.add(user);
  }
}

// ---------------------------------------------------------------- 탐침

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SignedOutPlatform platform;

  setUpAll(() async {
    FirebasePlatform.instance = _FakeCore();
    platform = _SignedOutPlatform();
    FirebaseAuthPlatform.instance = platform;
    await FirebaseAuthService.ensureInitialized();
  });

  test('탐침 1: 되풀이가 도착하기 전의 동기 조회가 로그아웃을 null 로 답한다', () {
    expect(
      platform.replayGate.isCompleted,
      isFalse,
      reason: '되풀이가 이미 도착했다면 이 탐침은 동기 조회를 재는 것이 아니다',
    );

    expect(
      FirebaseAuthService.instance.currentUser,
      isNull,
      reason: '동기 조회는 지금의 사실을 답해야 한다 — 세션이 없으면 null 이다',
    );
  });

  test('탐침 2: 그 뒤 로그인이 들어오면 동기 조회가 그 사용자로 바뀐다', () async {
    platform.replayGate.complete();

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(authStateProvider, (_, _) {});
    await pumpEventQueue();
    expect(sub.read().hasValue, isTrue);
    expect(sub.read().value, isNull);

    platform.emitNative(_FakeUser(platform, 'uid-later'));
    await pumpEventQueue();

    expect(sub.read().value, const AuthUser(uid: 'uid-later'));
    expect(
      FirebaseAuthService.instance.currentUser,
      const AuthUser(uid: 'uid-later'),
    );
  });
}
