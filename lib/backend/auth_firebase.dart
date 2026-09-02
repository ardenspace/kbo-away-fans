/// 인증 계층의 실제 구현 — Firebase Auth 위의 세 제공자 로그인.
///
/// `auth.dart` 가 계약(타입)이고 이 파일이 그 계약의 몸이다. 둘을 나눈 것은
/// 계약을 읽는 사람이 SDK 사정을 함께 읽지 않아도 되게 하려는 것이고,
/// `firebase_auth`·`google_sign_in` import 가 이 한 파일에만 있으면 SDK 를
/// 바꿀 때 볼 자리도 하나이기 때문이다 (경계는 `lib/backend/` 전체이므로
/// 훅 기준으로는 어느 쪽에 두어도 같지만, 읽는 사람 기준으로는 다르다).
///
/// 세 제공자가 여기서 만난다. 구글·애플은 Firebase Auth 의 기본 제공자라 이
/// 파일이 처음부터 끝까지 맡고, 카카오는 앞의 두 걸음(SDK 로그인 → 커스텀
/// 토큰 교환)이 `auth_kakao.dart` 의 [KakaoAuthGateway] 뒤에 있다. 마지막
/// 걸음부터는 셋이 같은 길을 지난다 — 세션이 실제로 섰는지 판정하는 규칙을
/// 제공자마다 따로 두지 않는다.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_check.dart';
import 'auth.dart';
import 'auth_kakao.dart';
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
  FirebaseAuthService._(this._auth, this._kakao) {
    _bindSessionStream();
  }

  static FirebaseAuthService? _instance;

  /// main 에서 1회 호출한다 — 분석 래퍼의 `ensureInitialized` 와 같은 모양이고
  /// 같은 이유다: 설정이 없거나 초기화가 실패하면 예외를 삼키고 연결되지 않은
  /// 채 남아 앱이 계속 뜬다.
  ///
  /// 여기서 미리 서 두는 것은 세션 상태 때문이다. `Firebase.initializeApp()` 이
  /// 끝나야 영속 세션이 복원된 결과를 읽을 수 있고([_bindSessionStream] 의
  /// 까닭 참조), 그 확정을 앱이 시작할 때 해 두면 게이트가 처음 상태를 읽는
  /// 시점에는 이미 답이 나와 있다.
  ///
  /// [kakaoGateway] 는 카카오의 두 걸음(SDK 로그인 → 커스텀 토큰 교환)을 갈아
  /// 끼우는 자리다. 기본값은 실제 구현이고, 넘기는 곳은 테스트뿐이다 — 그 둘만
  /// 단위 테스트에서 돌 수 없어서(플랫폼 채널·네트워크) 주입점을 이 한 자리에
  /// 두었다. 앱의 `main` 은 인수 없이 부른다.
  ///
  /// **이미 선 인스턴스에 다른 게이트웨이를 끼우려 하면 [StateError] 로 드러나게
  /// 실패한다.** 조용히 버리면 그렇게 부른 테스트는 새 게이트웨이를 끼웠다고
  /// 믿으면서 옛 것을 재게 되고, 그 착각은 초록불 뒤에 숨는다 — 인스턴스가
  /// 파일당 하나라는 규약을 사람의 기억이 아니라 여기서 지킨다. 인수 없는
  /// 호출과 같은 게이트웨이를 다시 넘기는 호출은 그대로 넘어간다(멱등).
  static Future<void> ensureInitialized({
    KakaoAuthGateway? kakaoGateway,
  }) async {
    final standing = _instance;
    if (standing != null) {
      if (kakaoGateway != null && !identical(standing._kakao, kakaoGateway)) {
        throw StateError(
          '이미 선 FirebaseAuthService 에 다른 카카오 게이트웨이를 끼울 수 없다 — '
          '주입은 인스턴스가 서기 전 한 번뿐이다(테스트 파일당 하나).',
        );
      }
      return;
    }
    try {
      await Firebase.initializeApp();
      _instance ??= FirebaseAuthService._(
        FirebaseAuth.instance,
        kakaoGateway ?? KakaoSdkAuthGateway(),
      );
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

  /// 카카오의 두 걸음 — 이 계층 밖에서는 보이지 않는다.
  final KakaoAuthGateway _kakao;

  /// 이 구현이 내보내는 세션 스트림 — SDK 스트림을 그대로 흘리지 않는다
  /// ([_bindSessionStream] 의 까닭 참조).
  final StreamController<AuthUser?> _sessions =
      StreamController<AuthUser?>.broadcast();

  /// 마지막으로 확인된 세션.
  ///
  /// 이 구현에는 "아직 모름" 구간이 없다 — 생성자의 [_bindSessionStream] 이
  /// 초기 상태를 곧바로 확정하기 때문이다(그 까닭은 그 메서드의 문서에 있다).
  /// 그래서 이 값의 null 은 언제나 **확정된 로그아웃**이다.
  AuthUser? _last;

  /// `GoogleSignIn.initialize()` 는 한 번만 불러야 한다 — 그 한 번을 기억한다.
  Future<void>? _googleReady;

  @override
  AuthUser? get currentUser => _last;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    // 구독하는 순간 지금 아는 상태부터 흘린다 (계약). 계약이 말하는 "아직
    // 모르면 침묵한다"는 구간은 이 구현에 없다 — 생성자가 이미 확정했다.
    yield _last;
    yield* _sessions.stream;
  }

  @override
  Future<AuthUser> signIn(AuthProviderId provider) => guardBackend(() async {
    try {
      // 세 갈래가 각자 제공자 흐름을 끝내고 **세션의 사용자**로 만난다.
      // 자격 증명 객체가 아니라 사용자로 모으는 것은 카카오 때문이다: 닉네임을
      // 세션에 심는 걸음이 SDK 캐시의 사용자 객체를 갈아 끼우므로, 자격 증명이
      // 들고 있던 사본은 그 시점에 이미 옛 값이 된다([_signInWithKakao] 참조).
      final signedIn = switch (provider) {
        AuthProviderId.google => (await _signInWithGoogle()).user,
        AuthProviderId.apple =>
          (await _auth.signInWithProvider(AppleAuthProvider())).user,
        AuthProviderId.kakao => await _signInWithKakao(),
      };
      // 제공자 흐름이 끝났다는 것과 세션이 섰다는 것을 여기서 맞춰 본다.
      final user = _toAuthUser(signedIn ?? _auth.currentUser);
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

  /// 카카오 SDK 로그인 → 커스텀 토큰 교환 → Firebase 세션.
  ///
  /// 앞의 두 걸음은 [KakaoAuthGateway] 뒤에 있고(`auth_kakao.dart`), 여기서
  /// 하는 일은 그 결과를 Firebase 세션으로 옮기는 것과 **닉네임을 심는 것**
  /// 둘이다.
  ///
  /// 닉네임을 심는 까닭: 커스텀 토큰으로 만들어진 계정은 표시 이름이 비어 있고,
  /// 카카오가 준 닉네임은 함수 응답에만 실려 온다(사용자 문서의 씨앗값이라
  /// 클레임에 싣지 않기로 했다 — `functions/custom-token.js` 참조). 그 값을
  /// 여기서 Firebase 프로필에 한 번 심어 두면 표시 이름의 출처가 세 제공자
  /// 모두 Firebase 하나로 남는다. 대신 반환 값에만 실어 나르면 다음 세션부터
  /// (또는 네이티브가 세션을 다시 말하는 순간) 같은 사람의 표시 이름이 조용히
  /// null 로 바뀐다.
  ///
  /// 심기가 실패해도 삼킨다 — 세션은 이미 섰고, 여기서 던지면 **로그인에
  /// 성공한 사람에게 실패 안내가** 뜬다. 심지 못했을 때의 결과는 닉네임에
  /// 동의하지 않은 사람과 같은 모양(표시 이름 없음)이라 뒷단계가 이미 다루는
  /// 갈래다.
  Future<User?> _signInWithKakao() async {
    final accessToken = await _kakao.obtainAccessToken();
    // 교환은 **App Check 토큰을 요구하는 유일한 호출**이다(함수 쪽이
    // `enforceAppCheck: true`). `main` 이 이미 한 번 켰지만 그 시도가 던졌을
    // 수도 있고, 그 실행에서 다시 켤 자리는 여기뿐이다 — 켜져 있으면 이 줄은
    // 아무 일도 하지 않는다(`app_check.dart` 의 "실패한 시도는 기억하지 않는다").
    //
    // **이 줄은 로그인을 붙잡지 않는다.** 기다림에는
    // `kAppCheckActivationTimeout` 의 상한이 있고, 넘으면 켜지지 않은 채
    // 교환으로 넘어간다 — 그 호출은 함수가 `unauthenticated` 로 거절하고
    // 화면은 이미 그 갈래를 안내로 옮긴다. 여기서 무한정 기다리면 로그인
    // 화면은 버튼 셋이 잠긴 채 스피너만 돌아, 앱을 다시 켜는 것 말고 나갈
    // 길이 없어진다(`kakao_app_check_stall_probe_test.dart` 가 잰다).
    await BackendAppCheck.ensureInitialized();
    final exchanged = await _kakao.exchange(accessToken);
    final credential = await _auth.signInWithCustomToken(exchanged.customToken);
    final user = credential.user ?? _auth.currentUser;
    final nickname = exchanged.nickname;
    if (user == null || nickname == null || (user.displayName ?? '').isNotEmpty) {
      return user;
    }
    try {
      await user.updateDisplayName(nickname);
    } catch (_) {
      return user;
    }
    // `updateProfile` 은 플러그인의 캐시 사용자를 새 객체로 갈아 끼운다
    // (`firebase_auth-6.6.1` 의 `MethodChannelUser.updateProfile`). 그래서
    // 방금 심은 이름을 들고 있는 쪽은 `credential.user` 가 아니라 캐시다.
    return _auth.currentUser ?? user;
  }

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

  /// 초기 세션 상태를 확정하고, 그 뒤의 변화를 SDK 스트림에서 옮긴다.
  ///
  /// **초기 상태를 스트림의 첫 값이 아니라 [FirebaseAuth.currentUser] 에서
  /// 읽는다.** 이 자리는 [ensureInitialized] 가 `Firebase.initializeApp()` 을
  /// 이미 await 한 뒤이고, 그 호출이 돌려준 플러그인 상수의 `APP_CURRENT_USER`
  /// 가 delegate 를 만들 때 캐시에 그대로 심긴다
  /// (`firebase_auth_platform_interface-9.0.7` 의
  /// `platform_interface_firebase_auth.dart` `instanceFor` →
  /// `setInitialValues(currentUser: ...)`). 그 상수를 채우는 네이티브 코드는
  /// 영속 세션이 이미 복원된 뒤의 `Auth.auth(app:).currentUser`(iOS) /
  /// `FirebaseAuth.getInstance(app).currentUser`(안드로이드)를 읽는다
  /// (`firebase_auth-6.6.1` 의 `FLTFirebaseAuthPlugin.swift`
  /// `pluginConstants(for:)`, `FlutterFirebaseAuthPlugin.kt`
  /// `getPluginConstantsForFirebaseApp`). 그래서 초기화가 끝난 뒤의 이 캐시는
  /// "아직 모름"이 아니라 **확정된 상태**다 — 로그인해 둔 사람이면 사용자가,
  /// 로그아웃한 사람이면 null 이 들어 있다.
  ///
  /// 스트림의 첫 값으로 가르지 않는 까닭은 그 판별에 근거가 없기 때문이다.
  /// 첫 값이 null 일 때 그것이 아직 안 채워진 캐시인지 확정된 로그아웃인지를
  /// 스트림만 보고는 알 수 없고, "첫 null 은 버린다"가 성립하려면 **네이티브의
  /// 첫 이벤트가 우리 구독보다 늦게 온다**는 순서 가정이 필요하다. 그 가정은
  /// 이 파일 밖에서 누가 `FirebaseAuth` 를 먼저 건드리는 것만으로 뒤집힌다
  /// (`FirebaseAuth.instance.currentUser` 를 한 번 읽기만 해도 delegate 가
  /// 생기고 네이티브 리스너 등록이 시작된다). 뒤집히면 네이티브의 첫 이벤트가
  /// 구독 전에 지나가 사라지고, 로그아웃한 사람에게는 그 뒤로 아무 이벤트도
  /// 오지 않아 콜드 스타트가 로그인 화면이 아니라 **영원한 스피너**가 된다 —
  /// 로그인 화면이 안 뜨므로 나갈 길도 없다. 캐시를 근거로 삼으면 순서가 어느
  /// 쪽이든 답이 같다.
  void _bindSessionStream() {
    // 이 한 줄이 확정하는 것은 **동기 조회**다: 이 줄이 없어도 대역이든 실 SDK 든
    // 구독의 첫 되풀이가 같은 값을 곧 흘려 주므로 스트림 쪽 단언은 그대로 통과
    // 하지만, 그 되풀이가 도착하기 전의 [currentUser] 는 세션이 복원돼 있는데도
    // null 을 답하게 된다. 그 창을 재는 자리가
    // `test/backend/firebase_auth_restored_session_sync_probe_test.dart` 와
    // 그 짝(`..._signed_out_sync_probe_test.dart`)이다.
    _publish(_toAuthUser(_auth.currentUser));
    _auth.authStateChanges().listen(
      (user) {
        // 구독 직후 SDK 가 한 번 흘리는 첫 값은 방금 읽은 그 캐시의 되풀이다.
        // 같은 값이면 흘리지 않는다 (세션이 바뀌지 않았는데 게이트를 흔들지
        // 않으려는 것이고, 되풀이가 아닌 진짜 변화는 언제나 값이 다르다).
        final next = _toAuthUser(user);
        if (next == _last) return;
        _publish(next);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_sessions.isClosed) {
          _sessions.addError(BackendError.from(error), stackTrace);
        }
      },
    );
  }

  void _publish(AuthUser? user) {
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
