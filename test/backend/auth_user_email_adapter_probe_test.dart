/// 통합 검증 탐침 — `AuthUser.email`(3.4)을 **실제로 채우는 유일한 자리**를
/// 잰다: `auth_firebase.dart` 의 `_toAuthUser`.
///
/// 왜 이 파일이 필요한가. 마이페이지(3.4)는 `user?.email ?? '카카오 계정으로
/// 로그인했어요'` 한 줄로 이메일 자리를 채우고, 그 화면의 시험들은 전부
/// `AuthUser(email: ...)` 를 손으로 지어 넣는 대역(`FakeAuthService`)을 쓴다.
/// 그래서 실 구현이 Firebase 의 `User.email` 을 세션 값으로 옮기는 줄을
/// `email: null` 로 바꿔도 저장소 전체가 초록불이었다(실측: 변이 주입,
/// `flutter test` 609통과·1스킵). 그 줄이 무너지면 구글·애플로 들어온
/// 사람에게 "카카오 계정으로 로그인했어요"라는 **사실이 아닌 문장**이 뜬다 —
/// 실패도 오류도 없이.
///
/// 대역은 이 폴더의 선례(`kakao_display_name_probe_test.dart` ·
/// `firebase_auth_service_adversarial_probe_test.dart`)와 같은 모양으로
/// `FirebaseAuthPlatform` 을 갈아 끼워 `FirebaseAuthService` **그 자체**를
/// 돌린다.
library;

import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _NoMultiFactor extends MultiFactorPlatform {
  _NoMultiFactor(super.auth);
}

class _FakeUser extends UserPlatform {
  _FakeUser(
    FirebaseAuthPlatform auth, {
    required String uid,
    String? email,
    String? displayName,
  }) : super(
         auth,
         _NoMultiFactor(auth),
         InternalUserDetails(
           userInfo: InternalUserInfo(
             uid: uid,
             email: email,
             displayName: displayName,
             isAnonymous: false,
             isEmailVerified: true,
           ),
           providerData: const <Map<Object?, Object?>?>[],
         ),
       );
}

class _FakeAuthPlatform extends FirebaseAuthPlatform {
  _FakeAuthPlatform() : super();

  final StreamController<UserPlatform?> native =
      StreamController<UserPlatform?>.broadcast();

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
    yield currentUser;
    yield* native.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuthPlatform platform;

  setUpAll(() async {
    FirebasePlatform.instance = _FakeCore();
    platform = _FakeAuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    // 복원된 세션이 이메일을 들고 있는 실행 — 구글·애플 계정의 모양이다.
    platform.currentUser = _FakeUser(
      platform,
      uid: 'google-uid',
      email: 'fan@example.com',
      displayName: '원정러',
    );
    await FirebaseAuthService.ensureInitialized(
      kakaoGateway: FakeKakaoAuthGateway(),
    );
  });

  tearDownAll(() async {
    await platform.native.close();
  });

  test('제공자가 준 이메일이 세션 값(AuthUser.email)까지 그대로 온다', () {
    expect(
      FirebaseAuthService.instance.currentUser?.email,
      'fan@example.com',
      reason: '이 줄이 무너지면 구글·애플 사용자의 마이페이지에 '
          '"카카오 계정으로 로그인했어요"가 뜬다',
    );
    expect(FirebaseAuthService.instance.currentUser?.uid, 'google-uid');
  });

  test('세션 스트림으로 흐르는 사용자도 같은 이메일을 들고 온다', () async {
    final seen = <String?>[];
    final subscription = FirebaseAuthService.instance.authStateChanges().listen(
      (user) => seen.add(user?.email),
    );
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);

    expect(seen, ['fan@example.com']);
  });

  test('이메일이 빈 문자열인 계정은 null 로 정규화된다 — 화면이 제공자 문구로 갈리는 갈래', () async {
    final seen = <Object?>[];
    final subscription = FirebaseAuthService.instance.authStateChanges().listen(
      (user) => seen.add(user == null ? #signedOut : user.email),
    );
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);
    seen.clear();

    platform.native.add(
      _FakeUser(platform, uid: 'kakao:1', email: '', displayName: null),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      seen,
      [null],
      reason: '빈 문자열을 그대로 흘리면 마이페이지가 빈칸을 그린다 '
          '(acceptance: 빈칸으로 남지 않는다)',
    );
  });

  test('이메일을 주지 않는 계정(카카오)은 null 로 온다', () async {
    final seen = <Object?>[];
    final subscription = FirebaseAuthService.instance.authStateChanges().listen(
      (user) => seen.add(user == null ? #signedOut : user.email),
    );
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);
    seen.clear();

    platform.native.add(
      _FakeUser(platform, uid: 'kakao:2', email: null, displayName: '카카오'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(seen, [null]);
  });
}
