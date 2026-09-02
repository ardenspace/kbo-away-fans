/// 적대적 탐침 3 — `_bindSessionStream` 의 첫 줄이 실제로 지키는 것을 재는 자리.
///
/// `auth_firebase.dart` 의 `_publish(_toAuthUser(_auth.currentUser))` 를 통째로
/// 지워도 `test/backend/` 의 기존 단언은 전부 통과한다. 까닭은 모든 대역의
/// `authStateChanges()` 가 실 SDK 를 본떠 **구독하는 순간 `currentUser` 를 먼저
/// 되풀이**하기 때문이다 — 그 줄이 없어도 같은 값이 한 마이크로태스크 뒤에
/// 스트림으로 도착하므로, 스트림을 재는 단언은 그대로 초록불이 된다.
///
/// 그런데 그 줄이 보장하는 것은 스트림이 아니라 **동기 조회**다.
/// `AuthService` 는 `currentUser` 를 노출하고(`auth.dart`) 구현은 그것을 `_last`
/// 로 답하는데, 그 줄이 없으면 생성 직후의 조회가 세션이 복원돼 있는데도 null 을
/// 답한다. 지금 `lib/` 안에 그 값을 읽는 자리는 없지만, 2.3 의 카카오 커스텀
/// 토큰과 2.4 의 사용자 문서가 `AuthService.currentUser` 를 읽는 순간 그대로
/// 밟는다.
///
/// 그래서 이 탐침은 **되풀이가 도착하기 전의 창**을 잰다. 대역의 되풀이를
/// 완료기([_RestoredSessionPlatform.replayGate])로 붙들어 두고 그 창에서 동기
/// 조회를 읽는다: 스트림을 한 번이라도 pump 한 뒤에 재면 되풀이가 값을 채워
/// 버려서, 그 줄이 없어도 통과해 버리기 때문이다. 붙들어 두는 것이 실 SDK 와
/// 어긋나지도 않는다 — 실 플러그인의 되풀이도 `async*` 생성기를 지나 오므로
/// 생성자가 끝나는 그 시점에는 아직 도착해 있지 않다. 이 대역은 그 시차를
/// 시험이 볼 수 있을 만큼 벌려 둘 뿐이다.
///
/// `FirebaseAuthService._instance` 는 static 이고 되돌릴 길이 없다 — 한 파일에
/// 인스턴스는 하나뿐이고, 그 하나가 **어떤 상태에서 태어나는가**가 곧 시나리오다.
/// 그래서 로그아웃 상태에서 태어나는 짝은 다른 파일
/// (`firebase_auth_signed_out_sync_probe_test.dart`)에 있다.
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

/// 영속 세션이 **이미 복원된 뒤**의 플랫폼 상태.
///
/// Dart 캐시 `currentUser` 에는 복원된 사용자가 들어 있고, 구독 시의 되풀이는
/// 실 플러그인과 같은 순서(`yield currentUser` → 네이티브 스트림)로 흐른다.
/// 다만 그 되풀이가 **언제** 도착할지는 [replayGate] 가 정한다 — 되풀이가 값을
/// 채우기 전의 창을 시험이 볼 수 있게 하려는 것이다.
class _RestoredSessionPlatform extends FirebaseAuthPlatform {
  _RestoredSessionPlatform() : super();

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

  /// 네이티브가 말했다 — Dart 캐시를 채우고 이벤트를 흘린다.
  void emitNative(UserPlatform? user) {
    _current = user;
    native.add(user);
  }
}

// ---------------------------------------------------------------- 탐침

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RestoredSessionPlatform platform;
  const restored = AuthUser(uid: 'uid-restored', displayName: '복원된 원정러');

  setUpAll(() async {
    FirebasePlatform.instance = _FakeCore();
    platform = _RestoredSessionPlatform();
    // 앱이 켜지기 전에 세션이 이미 복원돼 있었다.
    platform.currentUser = _FakeUser(platform, 'uid-restored', '복원된 원정러');
    FirebaseAuthPlatform.instance = platform;
    await FirebaseAuthService.ensureInitialized();
  });

  test('탐침 1: 되풀이가 도착하기 전에도 동기 조회가 복원된 세션을 답한다', () {
    // 이 창에서는 스트림이 아직 한 값도 흘리지 않았다 — 그것을 못 박아 둔다.
    // (열려 있으면 아래 단언이 "그 줄"이 아니라 대역의 되풀이를 재게 된다.)
    expect(
      platform.replayGate.isCompleted,
      isFalse,
      reason: '되풀이가 이미 도착했다면 이 탐침은 동기 조회를 재는 것이 아니다',
    );

    expect(
      FirebaseAuthService.instance.currentUser,
      restored,
      reason:
          '생성 직후의 동기 조회가 복원된 세션을 답해야 한다 — '
          '`_bindSessionStream` 의 첫 줄(`_publish(_toAuthUser(_auth.currentUser))`)이 '
          '지키는 것이 바로 이 자리이고, 그 줄이 없으면 세션이 있는데도 null 이 나온다',
    );
  });

  test('탐침 2: 되풀이가 도착해도 같은 값이라 동기 조회가 흔들리지 않는다', () async {
    platform.replayGate.complete();

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(authStateProvider, (_, _) {});
    await pumpEventQueue();

    expect(sub.read().hasValue, isTrue);
    expect(sub.read().value, restored);
    expect(FirebaseAuthService.instance.currentUser, restored);
  });

  test('탐침 3: 네이티브가 로그아웃을 말하면 동기 조회도 그 자리에서 null 로 바뀐다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(authStateProvider, (_, _) {});
    await pumpEventQueue();
    expect(sub.read().value, restored);

    platform.emitNative(null);
    await pumpEventQueue();

    expect(sub.read().value, isNull);
    expect(
      FirebaseAuthService.instance.currentUser,
      isNull,
      reason: '스트림과 동기 조회가 같은 사실을 말해야 한다',
    );
  });
}
