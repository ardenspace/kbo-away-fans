/// 카카오 로그인의 앱 쪽 두 걸음 — 카카오 SDK 로그인, 그리고 커스텀 토큰 교환.
///
/// 카카오는 Firebase Auth 의 기본 제공자가 아니라서 구글·애플과 걸음 수가 다르다:
/// 카카오 SDK 로 액세스 토큰을 받고 → 서울 리전의 callable
/// [kKakaoCustomTokenCallable] 이 그 토큰을 검증해 Firebase 커스텀 토큰을 주고 →
/// 그 토큰으로 Firebase 세션이 선다. 앞의 두 걸음만 이 파일에 있고, 마지막
/// 걸음(`signInWithCustomToken`)은 다른 두 제공자와 같은 자리
/// (`auth_firebase.dart` 의 `signIn`)에 있다 — 세션이 섰는지 판정하는 규칙을
/// 제공자마다 따로 두지 않으려는 것이다.
///
/// 두 걸음을 [KakaoAuthGateway] 라는 계약 뒤로 넣은 것은 그 둘만이 단위
/// 테스트에서 돌 수 없는 부분이기 때문이다(카카오 SDK 는 플랫폼 채널을,
/// callable 은 네트워크를 탄다). 그 계약을 가짜로 갈아 끼우면 나머지 경로 —
/// 교환 결과를 Firebase 세션으로 옮기고 실패를 도메인 오류로 옮기는 자리 — 가
/// 통째로 테스트로 덮인다.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'auth_firebase.dart' show kSignInCanceledCode;
import 'errors.dart';

/// 카카오 네이티브 앱 키 — **저장소에 그대로 적는 값이다.**
///
/// 감출 값이 아니다. 카카오의 네 앱 키 중 감추라고 경고되는 것은 Admin 키와
/// client secret 이고(그 둘은 백엔드에서만 쓴다), 네이티브 앱 키는 REST API
/// 키·JavaScript 키와 함께 **앱에 내장되는 것을 전제로 설계된 플랫폼 키**다 —
/// APK·IPA 를 뜯으면 그대로 나오므로 저장소에서 감추는 데 실질이 없다. 이 키를
/// 지키는 것은 감춤이 아니라 **플랫폼 등록**이다: 콘솔에 등록한 안드로이드 키
/// 해시와 iOS 번들 ID 를 가진 바이너리에서만 쓸 수 있다
/// (`.wellbegun/decisions.md` 의 [S] 판별 기준 — 감출지 말지는 "이 값이
/// 바이너리에 실려 나가는가"로 가른다).
///
/// **소비처가 셋이고 값이 하나여야 한다.** 여기(`KakaoSdk.init`),
/// `android/app/src/main/AndroidManifest.xml` 의 리다이렉트 액티비티 스킴
/// (`kakao{키}`), `ios/Runner/Info.plist` 의 `CFBundleURLTypes`. 셋이 어긋나면
/// 로그인이 돌아오는 길을 잃는데, 그 증상은 실기기에서만 보인다. 그래서
/// `test/backend/kakao_app_key_sync_test.dart` 가 세 자리를 대조한다 — 값을
/// 바꿀 때는 세 파일을 함께 고치고 그 테스트로 확인한다.
///
/// 빈 문자열은 "아직 카카오 앱을 등록하지 않았다"는 뜻이고, 그 실행에서 카카오
/// 로그인은 [kKakaoKeyMissingCode] 로 드러나게 실패한다.
const String kKakaoNativeAppKey = 'fe1a15ceb43fbb468f94e71ee21028f7';

/// 커스텀 토큰 함수가 사는 리전 — `functions/index.js` 의 `setGlobalOptions` 와
/// 같은 값이어야 한다. 다르면 호출은 존재하지 않는 함수로 나가 `not-found` 로
/// 실패한다.
const String kKakaoFunctionRegion = 'asia-northeast3';

/// callable 이름 — `functions/index.js` 가 export 하는 그 이름.
const String kKakaoCustomTokenCallable = 'kakaoCustomToken';

/// 카카오 앱을 아직 등록하지 않아 [kKakaoNativeAppKey] 가 비어 있는 실행.
///
/// 조용히 넘어가지 않는 것은 Firebase 설정 파일이 없을 때와 같은 까닭이다
/// (`auth_firebase.dart` 의 `kFirebaseUnconfiguredCode` 문서 참조) — 계정 없이
/// 쓰는 경로가 없는 앱에서 "로그인 버튼이 아무 일도 안 함"은 설정 실수를 숨긴다.
const String kKakaoKeyMissingCode = 'kakao-key-missing';

/// 카카오 SDK 가 액세스 토큰 없이 성공을 돌려줬다 (있을 수 없는 모양).
const String kKakaoAccessTokenMissingCode = 'kakao-access-token-missing';

/// callable 은 성공했는데 응답이 약속한 모양이 아니다.
///
/// 규약(`lib/backend/REGISTRY.md` 의 "이 폴더 밖에 있는 짝")은
/// `{ customToken, uid, nickname }` 이다. 함수를 고치다 응답이 어긋나면 여기서
/// 드러난다 — 빈 커스텀 토큰으로 `signInWithCustomToken` 을 부르면 SDK 쪽
/// 오류로 뭉개져서 무엇이 어긋났는지 읽히지 않는다.
const String kKakaoCustomTokenMalformedCode = 'kakao-custom-token-malformed';

/// 커스텀 토큰 교환의 결과 — callable 응답 그대로의 값 객체.
@immutable
class KakaoCustomToken {
  const KakaoCustomToken({
    required this.customToken,
    required this.uid,
    this.nickname,
  });

  /// Firebase 커스텀 토큰 — `signInWithCustomToken` 에 그대로 넘긴다.
  final String customToken;

  /// 이 토큰이 가리키는 Firebase uid (`kakao:{카카오 사용자 id}`).
  ///
  /// 세션이 선 뒤의 `User.uid` 와 같은 값이다. 앱은 세션 쪽 값을 쓰고 이
  /// 필드는 진단용으로 들고 간다 — 두 값이 갈라지는 일은 함수가 잘못됐다는
  /// 뜻이지 앱이 고를 문제가 아니다.
  final String uid;

  /// 사용자 문서(`users/{uid}.nickname`)의 씨앗값. 동의하지 않았으면 null 이고,
  /// 함수가 이미 길이 계약(UTF-16 20단위)에 맞춰 잘라서 보낸다.
  final String? nickname;

  @override
  bool operator ==(Object other) =>
      other is KakaoCustomToken &&
      other.customToken == customToken &&
      other.uid == uid &&
      other.nickname == nickname;

  @override
  int get hashCode => Object.hash(customToken, uid, nickname);

  @override
  String toString() => 'KakaoCustomToken($uid)';
}

/// 카카오 로그인의 두 걸음 — 테스트가 갈아 끼우는 경계.
///
/// **두 걸음의 실패는 서로 다른 모양으로 나온다.**
///
///  - [obtainAccessToken] — 카카오 SDK 예외를 이 안에서 [BackendError] 로
///    옮긴다. 옮기는 자리가 여기인 것은 카카오의 어휘(취소의 세 모양,
///    `ClientErrorCause`·`AuthErrorCause`)를 `errors.dart` 의 공통 표가 모르기
///    때문이다 — 카카오를 아는 유일한 자리가 이 파일이다.
///  - [exchange] — callable 실패([FirebaseFunctionsException])를 **그대로**
///    던진다. 그 예외는 이미 `FirebaseException` 이라 `errors.dart` 의 공통
///    코드 표가 그대로 읽고, 계층을 나가는 자리(`auth_firebase.dart` 의
///    `signIn` 을 감싼 `guardBackend`)가 도메인 오류로 옮긴다. 여기서 한 번 더
///    옮기면 같은 표가 두 벌이 되어 갈라진다.
///
/// 그래서 이 계약이 약속하는 것은 "구현이 모든 실패를 도메인 오류로 옮긴다"가
/// 아니라, **계층 밖으로는 [BackendError] 만 나간다**는 `lib/backend/CLAUDE.md`
/// 의 규칙이다(그 규칙이 지목하는 변환 자리가 `guardBackend` 다). 대역도 같은
/// 모양으로 흉내 낸다 — `test/backend/fake_backend.dart` 참조.
abstract class KakaoAuthGateway {
  const KakaoAuthGateway();

  /// 카카오 계정으로 로그인하고 액세스 토큰을 얻는다.
  Future<String> obtainAccessToken();

  /// 액세스 토큰 → Firebase 커스텀 토큰 (서울 리전의 callable).
  Future<KakaoCustomToken> exchange(String accessToken);
}

/// 실제 구현 — 카카오 SDK + `cloud_functions`.
///
/// `package:kakao_flutter_sdk_user` import 가 `lib/` 안에서는 이 파일에만 있다
/// (`scripts/hooks/check-firebase-import-boundary.sh` 가 `lib/backend/` 밖을
/// 막고, 폴더 안에서 한 파일로 모으는 것은 읽는 사람을 위한 몫이다 —
/// `auth_firebase.dart` 가 `firebase_auth`·`google_sign_in` 을 모아 둔 것과
/// 같은 이유). 테스트는 카카오 예외를 **만들어야** 하므로 같은 패키지를
/// import 한다 — 계약이 막는 것은 `lib/backend/` 밖의 `lib/` 다.
///
/// **SDK 와 닿는 자리가 셋이고, 셋 다 [KakaoSdkAuthGateway.withSeams] 로 갈아
/// 끼울 수 있다**: 앱 키, `KakaoSdk.init`, 로그인 호출. 이 주입점이 없으면
/// [obtainAccessToken] 안쪽은 어떤 시험도 닿지 못한다 — 저장소의 앱 키가 비어
/// 있는 동안은 `_ensureSdkReady` 가 먼저 던지고, 키를 채우면 그다음 줄이
/// 플랫폼 채널을 타기 때문이다. 그래서 "설정이 없는 실행은 조용히 성공하지
/// 않는다"도, SDK 초기화 실패가 카카오 어휘를 지키는지도, 시험이 **스스로
/// 만든 조건** 위에서 재어진다(우연히 비어 있는 상수 위가 아니라).
class KakaoSdkAuthGateway extends KakaoAuthGateway {
  /// 앱이 쓰는 생성자 — 저장소의 앱 키와 실제 SDK 호출을 꽂는다.
  KakaoSdkAuthGateway()
    : this.withSeams(
        appKey: kKakaoNativeAppKey,
        sdkInit: _initKakaoSdk,
        sdkLogin: _loginWithKakaoSdk,
      );

  /// SDK 접점 셋을 갈아 끼우는 생성자 — 테스트 전용이다.
  @visibleForTesting
  KakaoSdkAuthGateway.withSeams({
    required String appKey,
    required Future<void> Function(String nativeAppKey) sdkInit,
    required Future<String> Function() sdkLogin,
  }) : _nativeAppKey = appKey,
       _initSdk = sdkInit,
       _login = sdkLogin;

  final String _nativeAppKey;
  final Future<void> Function(String nativeAppKey) _initSdk;
  final Future<String> Function() _login;

  /// `KakaoSdk.init()` 은 한 번만 부르면 된다 — 그 한 번을 기억한다.
  /// 실패한 시도는 기억하지 않는다(`_ensureGoogleReady` 와 같은 이유: 기억하면
  /// 첫 실패가 앱을 켜 있는 동안 카카오 로그인을 영구히 막는다).
  Future<void>? _sdkReady;

  static Future<void> _initKakaoSdk(String nativeAppKey) =>
      KakaoSdk.init(nativeAppKey: nativeAppKey);

  /// 카카오톡이 깔려 있으면 앱으로, 아니면 카카오계정 웹으로.
  ///
  /// 어느 로그인을 어떤 순서로 부를지의 규칙은 [kakaoLoginWithTalkFallback] 에
  /// 있다 — 여기는 그 규칙에 **실제 SDK 호출 세 개를 꽂는 배선**뿐이다.
  static Future<String> _loginWithKakaoSdk() async =>
      (await kakaoLoginWithTalkFallback<OAuthToken>(
        isTalkInstalled: isKakaoTalkInstalled,
        withTalk: UserApi.instance.loginWithKakaoTalk,
        withAccount: UserApi.instance.loginWithKakaoAccount,
      )).accessToken;

  Future<void> _ensureSdkReady() async {
    if (_nativeAppKey.isEmpty) {
      // SDK 를 건드리기 **전에** 막는다 — `KakaoSdk.init` 은 플랫폼 정보를
      // 읽으러 채널을 타므로, 키가 없다는 사실이 채널 오류로 뭉개진다.
      throw const BackendUnknownError(code: kKakaoKeyMissingCode);
    }
    final pending = _sdkReady;
    if (pending != null) return pending;
    final started = _initSdk(_nativeAppKey);
    _sdkReady = started;
    try {
      await started;
    } catch (_) {
      _sdkReady = null;
      rethrow;
    }
  }

  @override
  Future<String> obtainAccessToken() async {
    try {
      // 초기화도 이 try 안이다. 밖에 두면 `KakaoSdk.init` 이 던지는
      // `KakaoException`·`PlatformException` 이 옮겨지지 않은 채 `guardBackend`
      // 로 가서 `unknown` 이 되고, 이 파일이 약속하는 `kakao-client-*`·
      // `kakao-platform-*` 진단 코드가 함수 로그와 버그 리포트에서 사라진다.
      // 앱 키 없음 갈래는 이미 `BackendError` 라 이 catch 들을 그냥 지나간다.
      await _ensureSdkReady();
      final accessToken = await _login();
      if (accessToken.isEmpty) {
        throw const BackendUnknownError(code: kKakaoAccessTokenMissingCode);
      }
      return accessToken;
    } on KakaoException catch (error, stackTrace) {
      Error.throwWithStackTrace(backendErrorFromKakao(error), stackTrace);
    } on PlatformException catch (error, stackTrace) {
      Error.throwWithStackTrace(backendErrorFromPlatform(error), stackTrace);
    }
  }

  @override
  Future<KakaoCustomToken> exchange(String accessToken) async {
    final callable = FirebaseFunctions.instanceFor(
      region: kKakaoFunctionRegion,
    ).httpsCallable(kKakaoCustomTokenCallable);
    final result = await callable.call<Object?>(<String, Object?>{
      'accessToken': accessToken,
    });
    return kakaoCustomTokenFromCallable(result.data);
  }
}

/// 카카오톡 로그인과 계정 로그인 중 **어느 것을 어떤 순서로 부르는가**.
///
/// 함수 밖으로 꺼내 둔 것은 `kakaoCustomTokenFromCallable` 과 같은 까닭이다 —
/// 이 규칙은 SDK 없이 재는 조각이고, 세 호출을 인수로 받으므로 시험은 SDK 를
/// 세우지 않고 **순서만** 잰다 (`test/backend/kakao_error_mapping_test.dart`).
/// 게이트웨이 안에 두었다면 [KakaoSdkAuthGateway.withSeams] 로 닿기는 하지만,
/// 그 길로는 로그인 호출 하나를 통째로 갈아 끼우게 되어 순서를 재려면 SDK 의
/// 어휘를 함께 세워야 한다.
///
/// 규칙은 둘이다 ([S] 2026-09-03 결정):
///
///  1. 카카오톡이 깔려 있으면 앱으로 로그인한다. 그 로그인이 **취소가 아닌**
///     이유로 실패하면 계정 로그인으로 한 번 갈아탄다 — 카카오톡이 깔려 있어도
///     로그인돼 있지 않거나 앱이 응답하지 못하는 기기가 흔하고, 갈아타지 않으면
///     그 사람에게 카카오 로그인은 아예 없는 것이 된다.
///  2. 취소면 갈아타지 않는다. 화면을 스스로 닫은 사람에게 다른 로그인 창을
///     곧바로 다시 띄우면 앱이 사용자의 선택을 무시하는 모양이 된다.
///
/// 토큰 타입을 열어 둔 것은 이 규칙이 **어떤 값이 돌아오는지와 무관**하기
/// 때문이다 (실제로는 언제나 `OAuthToken` 이다).
@visibleForTesting
Future<T> kakaoLoginWithTalkFallback<T>({
  required Future<bool> Function() isTalkInstalled,
  required Future<T> Function() withTalk,
  required Future<T> Function() withAccount,
}) async {
  if (await isTalkInstalled()) {
    try {
      return await withTalk();
    } catch (error) {
      if (kakaoSignInWasCanceled(error)) rethrow;
      return withAccount();
    }
  }
  return withAccount();
}

/// callable 응답 → [KakaoCustomToken].
///
/// 함수 밖으로 꺼내 둔 것은 이 판정이 SDK 없이 테스트되는 유일한 조각이기
/// 때문이다 — 응답 모양이 규약을 벗어나는 갈래가 여기에 다 모여 있다.
@visibleForTesting
KakaoCustomToken kakaoCustomTokenFromCallable(Object? data) {
  if (data is! Map) {
    throw const BackendUnknownError(code: kKakaoCustomTokenMalformedCode);
  }
  final customToken = data['customToken'];
  final uid = data['uid'];
  if (customToken is! String ||
      customToken.isEmpty ||
      uid is! String ||
      uid.isEmpty) {
    throw const BackendUnknownError(code: kKakaoCustomTokenMalformedCode);
  }
  final nickname = data['nickname'];
  return KakaoCustomToken(
    customToken: customToken,
    uid: uid,
    // 빈 문자열은 null 로 접는다 — 사용자 문서의 닉네임 길이 계약이 1자
    // 이상이라, 빈 값을 씨앗으로 들고 가면 2.4 가 만드는 문서가 규칙에서
    // 거부된다 ([AuthUser.displayName] 이 빈 이름을 접는 것과 같은 자리).
    nickname: (nickname is String && nickname.isNotEmpty) ? nickname : null,
  );
}

/// 사용자가 스스로 닫았는가 — 카카오는 이 사실을 **세 모양**으로 말한다.
///
/// 셋을 한 함수에 모은 것은 판별이 갈래마다 흩어지면 한 모양만 놓쳐도 그 사람의
/// 취소가 "알 수 없는 실패"로 안내되기 때문이고, 꺼내 둔 것은 이 판별이 SDK 를
/// 타지 않는 조각이기 때문이다 ([kakaoLoginWithTalkFallback] 의 까닭과 같다).
@visibleForTesting
bool kakaoSignInWasCanceled(Object error) =>
    (error is KakaoClientException &&
        error.reason == ClientErrorCause.cancelled) ||
    (error is KakaoAuthException &&
        error.error == AuthErrorCause.accessDenied) ||
    (error is PlatformException && error.code == 'CANCELED');

/// 카카오 SDK 예외 → 도메인 오류.
///
/// 취소를 권한 갈래로 옮기는 까닭은 구글과 같다: 세 갈래 중 권한만이 "사용자가
/// 로그인을 끝내지 않았다"를 사용자의 말로 옮긴다 (`_fromGoogleSignIn` 참조).
/// 나머지는 `kakao-` 접두를 붙여 알 수 없음으로 보낸다 — 화면이 갈래를 더
/// 나눌 수 없고, 진단에 필요한 것은 도메인이 아니라 이 코드다.
@visibleForTesting
BackendError backendErrorFromKakao(KakaoException error) {
  if (kakaoSignInWasCanceled(error)) {
    return BackendPermissionError(code: kSignInCanceledCode, cause: error);
  }
  if (error is KakaoClientException) {
    return BackendUnknownError(
      code: 'kakao-client-${error.reason.name}',
      cause: error,
    );
  }
  if (error is KakaoAuthException) {
    return BackendUnknownError(
      code: 'kakao-auth-${error.error.name}',
      cause: error,
    );
  }
  return BackendUnknownError(code: 'kakao-unknown', cause: error);
}

/// 플랫폼 채널 예외 → 도메인 오류 (카카오톡 앱을 띄우는 자리가 이 길로 온다).
@visibleForTesting
BackendError backendErrorFromPlatform(PlatformException error) =>
    kakaoSignInWasCanceled(error)
    ? BackendPermissionError(code: kSignInCanceledCode, cause: error)
    : BackendUnknownError(code: 'kakao-platform-${error.code}', cause: error);
