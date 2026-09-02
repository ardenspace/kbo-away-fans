/// 카카오로 **다시 로그인한 사람의 표시 이름**을 잰다 — 처음 만든 계정이 아니라.
///
/// `kakao_sign_in_test.dart` 는 언제나 표시 이름이 빈 계정에서 시작한다(커스텀
/// 토큰으로 갓 만들어진 계정의 모양). 그래서 구현의
/// `(user.displayName ?? '').isNotEmpty` 한 줄 — **이미 이름이 있으면 심지
/// 않는다** — 은 그 파일의 어느 케이스도 지나가지 않는다. 지워도 초록불이다.
///
/// 그 줄이 지키는 자리는 **두 번째 로그인부터**다. 2.4 가 사용자 문서를 세우고
/// 사람이 앱에서 이름을 바꾼 뒤(표시 이름의 출처는 세 제공자 모두 Firebase
/// 하나라는 것이 이 단계의 결정이다) 로그아웃했다가 다시 카카오로 들어오면,
/// 함수는 **카카오 콘솔의 닉네임**을 다시 실어 보낸다. 심기를 막지 않으면 그
/// 순간 사람이 고른 이름이 카카오 닉네임으로 조용히 되돌아간다 — 실패도 오류도
/// 없이, 로그인할 때마다.
library;

import 'dart:async';

import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/auth_firebase.dart';
import 'package:kbo_away_fans/backend/auth_kakao.dart';

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

  static final List<String?> updatedDisplayNames = <String?>[];

  @override
  Future<void> updateProfile(Map<String, String?> profile) async {
    final displayName = profile['displayName'];
    updatedDisplayNames.add(displayName);
    _platform.currentUser = _FakeUser(_platform, uid, displayName);
  }
}

class _FakeCredential extends UserCredentialPlatform {
  _FakeCredential({required super.auth, super.user});
}

/// 커스텀 토큰으로 들어오는 계정이 **이미 표시 이름을 들고 있다** — 돌아온
/// 사람의 모양이다.
class _FakeAuthPlatform extends FirebaseAuthPlatform {
  _FakeAuthPlatform() : super();

  final StreamController<UserPlatform?> native =
      StreamController<UserPlatform?>.broadcast();

  UserPlatform? _current;

  /// 세션이 설 때 그 사용자가 이미 들고 있는 표시 이름 (null 이면 갓 만든 계정).
  String? standingDisplayName;

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
    final user = _FakeUser(this, 'kakao:1234567890', standingDisplayName);
    _current = user;
    return _FakeCredential(auth: this, user: user);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    native.add(null);
  }
}

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
    _FakeUser.updatedDisplayNames.clear();
    kakao.customToken = const KakaoCustomToken(
      customToken: 'custom-token',
      uid: 'kakao:1234567890',
      nickname: '카카오닉네임',
    );
  });

  test('이미 이름이 선 계정에는 카카오 닉네임을 다시 심지 않는다', () async {
    platform.standingDisplayName = '내가 고친 이름';

    final user = await FirebaseAuthService.instance.signIn(
      AuthProviderId.kakao,
    );

    expect(
      _FakeUser.updatedDisplayNames,
      isEmpty,
      reason:
          '심으면 사람이 고른 이름이 로그인할 때마다 카카오 닉네임으로 조용히 '
          '되돌아간다 — 실패도 오류도 없이',
    );
    expect(user.displayName, '내가 고친 이름');
    expect(FirebaseAuthService.instance.currentUser?.displayName, '내가 고친 이름');
  });

  test('빈 문자열 표시 이름은 "없음"과 같이 다뤄 닉네임을 심는다', () async {
    // 커스텀 토큰 계정의 표시 이름이 null 대신 빈 문자열로 오는 실행이 있다.
    // 그 갈래를 "이름이 있다"로 읽으면 닉네임이 영영 심기지 않는다.
    platform.standingDisplayName = '';
    await FirebaseAuthService.instance.signOut();

    await FirebaseAuthService.instance.signIn(AuthProviderId.kakao);

    expect(_FakeUser.updatedDisplayNames, ['카카오닉네임']);
  });
}
