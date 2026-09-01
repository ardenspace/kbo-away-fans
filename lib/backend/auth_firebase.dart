/// 인증 계층의 실제 구현 — Firebase Auth 위의 구글·애플 로그인.
///
/// `auth.dart` 가 계약(타입)이고 이 파일이 그 계약의 몸이다. 둘을 나눈 것은
/// 계약을 읽는 사람이 SDK 사정을 함께 읽지 않아도 되게 하려는 것이고,
/// `firebase_auth`·`google_sign_in` import 가 이 한 파일에만 있으면 SDK 를
/// 바꿀 때 볼 자리도 하나이기 때문이다 (경계는 `lib/backend/` 전체이므로
/// 훅 기준으로는 어느 쪽에 두어도 같지만, 읽는 사람 기준으로는 다르다).
///
/// 세 제공자 중 둘만 여기 있다. 카카오는 커스텀 토큰 교환이 먼저라 step 2.3
/// 이 같은 자리에 붙인다 — 그전까지 카카오 로그인은
/// [kSignInProviderNotWiredCode] 로 실패한다(조용히 성공한 척하지 않는다).
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth.dart';
import 'errors.dart';

/// Firebase 설정 파일이 없어 인증이 연결되지 않았다.
///
/// 분석 래퍼(`lib/analytics/analytics.dart`)는 설정이 없으면 조용히 no-op
/// 하지만 인증은 그럴 수 없다 — 계정 없이 쓰는 경로가 없다는 결정(소셜 로그인
/// 필수, 되돌리기 비용 XL)
/// 아래에서 "조용한 no-op 인증"은 곧 "아무도 로그인하지 않은 상태로 앱이
/// 멀쩡히 도는 것"이라, 설정을 빠뜨린 실행이 실행 중에 드러나지 않는다.
/// 그래서 설정이 없으면 이 코드로 **드러나게** 실패하고, 루트 게이트는 그것을
/// "로그인 화면 + 안내"로 받는다.
const String kFirebaseUnconfiguredCode = 'firebase-unconfigured';

/// 제공자 로그인은 끝났는데 세션의 사용자를 얻지 못했다.
///
/// "제공자 로그인이 끝났다"와 "세션이 섰다"는 같은 사실이 아니다. 이 구현은
/// 둘이 어긋난 채로 성공을 돌려주지 않는다 — 로그인 화면의 잠금을 푸는 자리가
/// 게이트뿐이라, 성공했는데 세션이 없으면 앱을 다시 켜는 것 말고 나갈 길이
/// 없어진다([M] 2026-09-02 세션 수립 판정 결정).
const String kSessionNotEstablishedCode = 'session-not-established';

/// 아직 이 구현에 붙지 않은 제공자로 로그인을 시도했다 (지금은 카카오 — 2.3).
const String kSignInProviderNotWiredCode = 'provider-not-wired';

/// 사용자가 제공자 화면을 스스로 닫았을 때의 코드 (구글·애플 공통으로 옮긴다).
const String kSignInCanceledCode = 'canceled';

/// Firebase Auth 가 OAuth 웹 흐름의 취소에 쓰는 코드.
const String kSignInWebCanceledCode = 'web-context-canceled';

/// Firebase Auth 위의 인증 구현 — 앱이 실제로 쓰는 [AuthService].
///
/// 설정 파일(`google-services.json` / `GoogleService-Info.plist`)이 있는
/// 실행에서만 선다. 없는 실행에서는 [ensureInitialized] 가 조용히 넘어가고
/// [instance] 가 [kFirebaseUnconfiguredCode] 로 던진다.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService._(this._auth) {
    _bindSessionStream();
  }

  static FirebaseAuthService? _instance;

  /// main 에서 1회 호출한다 — 분석 래퍼의 `ensureInitialized` 와 같은 모양이고
  /// 같은 이유다: 설정이 없거나 초기화가 실패하면 예외를 삼키고 연결되지 않은
  /// 채 남아 앱이 계속 뜬다.
  ///
  /// 여기서 미리 서 두는 것은 세션 스트림 때문이다. Firebase Auth 는 네이티브가
  /// 영속 세션을 복원해 첫 이벤트를 보내 줄 때까지 로그인 여부를 모르는데,
  /// 그 구독을 앱이 시작할 때 걸어 두면 모르는 구간이 스플래시 뒤로 숨는다.
  /// 게이트가 처음 상태를 읽는 시점에는 대개 이미 알고 있다.
  static Future<void> ensureInitialized() async {
    try {
      await Firebase.initializeApp();
      _instance ??= FirebaseAuthService._(FirebaseAuth.instance);
    } catch (_) {
      // 설정 없는 클론·초기화 실패 — 연결하지 않고 넘어간다.
    }
  }

  /// 연결된 인증 서비스. 설정이 없으면 [BackendUnknownError] 로 던진다.
  static AuthService get instance {
    final service = _instance;
    if (service == null) {
      throw const BackendUnknownError(code: kFirebaseUnconfiguredCode);
    }
    return service;
  }

  final FirebaseAuth _auth;

  /// 이 구현이 내보내는 세션 스트림 — SDK 스트림을 그대로 흘리지 않는다
  /// ([_bindSessionStream] 의 까닭 참조).
  final StreamController<AuthUser?> _sessions =
      StreamController<AuthUser?>.broadcast();

  /// 세션 상태를 한 번이라도 확인했는가. false 인 동안은 "로그아웃"이 아니라
  /// **아직 모름**이고, 그 구간에서는 아무 값도 내보내지 않는다.
  bool _known = false;

  /// 마지막으로 확인된 세션.
  AuthUser? _last;

  /// `GoogleSignIn.initialize()` 는 한 번만 불러야 한다 — 그 한 번을 기억한다.
  Future<void>? _googleReady;

  @override
  AuthUser? get currentUser => _last;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    // 이미 아는 상태가 있으면 구독하는 순간 그것부터 흘린다 (계약).
    // 모르는 동안에는 아무것도 흘리지 않고 기다린다 — 그 침묵이 게이트에서
    // "아직 갈래를 못 정했다"(스피너)로 읽힌다.
    if (_known) yield _last;
    yield* _sessions.stream;
  }

  @override
  Future<AuthUser> signIn(AuthProviderId provider) => guardBackend(() async {
    try {
      final credential = switch (provider) {
        AuthProviderId.google => await _signInWithGoogle(),
        AuthProviderId.apple => await _auth.signInWithProvider(
          AppleAuthProvider(),
        ),
        AuthProviderId.kakao => throw const BackendUnknownError(
          code: kSignInProviderNotWiredCode,
        ),
      };
      // 제공자 흐름이 끝났다는 것과 세션이 섰다는 것을 여기서 맞춰 본다.
      final user = _toAuthUser(credential.user ?? _auth.currentUser);
      if (user == null) {
        throw const BackendUnknownError(code: kSessionNotEstablishedCode);
      }
      // 세션이 섰다는 사실을 우리 스트림에도 곧바로 세운다. 네이티브 리스너도
      // 곧 같은 값을 보내지만, 로그인 화면이 성공 직후에 세션을 확인하는
      // 경로(`authStateProvider` 를 다시 세워 첫 값을 읽는다)가 그 이벤트를
      // 기다리며 멈춰 있지 않게 한다.
      _publish(user);
      return user;
    } on GoogleSignInException catch (error, stackTrace) {
      Error.throwWithStackTrace(_fromGoogleSignIn(error), stackTrace);
    } on FirebaseAuthException catch (error, stackTrace) {
      Error.throwWithStackTrace(_fromFirebaseAuth(error), stackTrace);
    }
  });

  @override
  Future<void> signOut() => guardBackend(() async {
    await _auth.signOut();
    // 구글 쪽 세션도 함께 끊는다 — 안 끊으면 다음 로그인에서 계정 선택 화면
    // 없이 같은 계정으로 곧장 들어가서, 계정을 바꿀 길이 사라진다.
    // 이 정리가 실패해도 Firebase 로그아웃은 이미 끝났으므로 삼킨다
    // (초기화 전이라 플랫폼이 거절하는 경우가 여기 해당한다).
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    _publish(null);
  });

  /// 구글 계정 선택 → id 토큰 → Firebase 자격 증명.
  Future<UserCredential> _signInWithGoogle() async {
    await _ensureGoogleReady();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      // 모바일 두 플랫폼에서는 항상 지원된다 — 여기 오는 것은 지원 범위 밖의
      // 실행이므로 조용히 실패하지 않고 코드를 남긴다.
      throw const BackendUnknownError(code: 'google-authenticate-unsupported');
    }
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      // 안드로이드에서 google-services.json 에 웹 OAuth 클라이언트가 없으면
      // 여기로 온다 (계정은 골랐는데 id 토큰이 없다).
      throw const BackendUnknownError(code: 'google-id-token-missing');
    }
    return _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  /// `GoogleSignIn.initialize()` 를 성공할 때까지 한 번만.
  ///
  /// 실패한 시도는 기억하지 않는다 — 기억하면 첫 실패가 앱을 켜 있는 동안
  /// 구글 로그인을 영구히 막는다. 식별자는 넘기지 않는다: 두 플랫폼 모두
  /// 설정 파일(`google-services.json` / `GoogleService-Info.plist`)에서
  /// 읽으므로, 여기에 값을 적으면 설정의 출처가 둘로 갈린다.
  Future<void> _ensureGoogleReady() async {
    final pending = _googleReady;
    if (pending != null) return pending;
    final started = GoogleSignIn.instance.initialize();
    _googleReady = started;
    try {
      await started;
    } catch (_) {
      _googleReady = null;
      rethrow;
    }
  }

  /// SDK 세션 스트림을 구독해 이 구현의 스트림으로 옮긴다.
  ///
  /// 그대로 흘리지 않는 까닭은 첫 값 하나 때문이다. `firebase_auth` 의
  /// `authStateChanges()` 는 구독 즉시 **Dart 쪽 캐시**를 한 번 흘리고 그다음부터
  /// 네이티브 리스너 이벤트를 흘리는데, 그 캐시는 네이티브가 첫 이벤트를 보내기
  /// 전까지 null 이다 (플러그인이 그 이벤트로만 캐시를 채운다). 그래서 로그인해
  /// 둔 사람도 첫 값이 null 이고, 그 null 을 확정된 로그아웃으로 읽으면 콜드
  /// 스타트에서 로그인 화면이 한 번 번쩍인 뒤 홈으로 바뀐다.
  ///
  /// 그 첫 null 만 버리고, 네이티브가 말한 것부터 듣는다. 첫 값이 null 이
  /// 아니면 그것은 이미 네이티브에서 온 값이므로 그대로 쓴다.
  void _bindSessionStream() {
    var first = true;
    _auth.authStateChanges().listen(
      (user) {
        final synthetic = first && user == null;
        first = false;
        if (synthetic) return;
        _publish(_toAuthUser(user));
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_sessions.isClosed) {
          _sessions.addError(BackendError.from(error), stackTrace);
        }
      },
    );
  }

  void _publish(AuthUser? user) {
    _known = true;
    _last = user;
    if (!_sessions.isClosed) _sessions.add(user);
  }
}

/// SDK 사용자 → 앱의 사용자 값. 이메일·사진 등 나머지는 옮기지 않는다
/// ([AuthUser] 가 uid 와 표시 이름만 드는 까닭은 그 타입의 문서에 있다).
///
/// 빈 표시 이름은 null 로 접는다 — 애플은 두 번째 로그인부터 이름을 주지
/// 않고, 제공자에 따라 빈 문자열로 오기도 해서 "없음"이 두 모양이 된다.
AuthUser? _toAuthUser(User? user) {
  if (user == null) return null;
  final displayName = user.displayName;
  return AuthUser(
    uid: user.uid,
    displayName: (displayName == null || displayName.isEmpty)
        ? null
        : displayName,
  );
}

/// 구글 로그인 실패 → 도메인 오류.
///
/// 취소를 권한 갈래로 옮기는 것은 화면 문구 때문이다. 세 갈래 중 권한이
/// "로그인이 완료되지 않았어요"라고 말하는데, 사용자가 계정 선택 화면을 스스로
/// 닫은 상황을 정확히 서술하는 문구가 그것이다 — "잠시 뒤 다시 시도해 주세요"
/// (네트워크·알 수 없음)는 사용자가 한 일을 앱의 고장처럼 말한다.
BackendError _fromGoogleSignIn(GoogleSignInException error) =>
    switch (error.code) {
      GoogleSignInExceptionCode.canceled ||
      GoogleSignInExceptionCode.interrupted => BackendPermissionError(
        code: error.code.name,
        cause: error,
      ),
      _ => BackendUnknownError(code: error.code.name, cause: error),
    };

/// Firebase Auth 실패 → 도메인 오류.
///
/// 취소만 여기서 가로채고 나머지는 [BackendError.from] 의 공통 표에 맡긴다
/// (애플 로그인의 취소는 `canceled`, OAuth 웹 흐름의 취소는
/// `web-context-canceled` 로 온다).
BackendError _fromFirebaseAuth(FirebaseAuthException error) =>
    switch (error.code) {
      kSignInCanceledCode || kSignInWebCanceledCode => BackendPermissionError(
        code: error.code,
        cause: error,
      ),
      _ => BackendError.from(error),
    };
