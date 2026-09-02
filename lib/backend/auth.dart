/// 인증 공통 계층 — 세 제공자 로그인·로그아웃·세션 상태를 한 타입 뒤로.
///
/// - Firebase Auth·카카오 SDK 는 이 계층의 **구현**에만 들어온다. 화면은
///   [AuthService]·[AuthUser]·[AuthProviderId] 세 타입만 소비한다.
/// - 실패는 전부 `errors.dart` 의 도메인 오류로 나온다 (SDK 예외 금지).
/// - 구현은 `auth_firebase.dart` 에 있다 (2.2 구글·애플, 2.3 카카오). 계약과
///   구현을 나눈 것은 이 파일을 읽는 사람이 SDK 사정을 함께 읽지 않아도 되게
///   하려는 것이고, 계약이 먼저 선 것은 게이트와 화면이 기대는 모양을 못 박아
///   두어야 구현이 그 모양을 따라오기 때문이다.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_firebase.dart';
import 'errors.dart';

/// 로그인 제공자 셋 — decisions.md 의 소셜 로그인 L 결정.
///
/// 구글·애플은 Firebase Auth 기본 제공자이고, 카카오는 Cloud Functions 가
/// 발급한 커스텀 토큰으로 같은 Firebase 세션에 붙는다. 그 차이는 구현
/// 안쪽 사정이라 화면에는 값 하나로만 보인다.
enum AuthProviderId {
  /// 구글 (Firebase Auth 기본 제공자).
  google,

  /// 애플 (Firebase Auth 기본 제공자 — iOS 심사 지침이 요구한다).
  apple,

  /// 카카오 (커스텀 토큰).
  kakao,
}

/// 로그인한 사용자 — 세션이 들고 있는 값 전부.
///
/// 이메일을 두지 않는다. 카카오에서 이메일을 받으려면 비즈니스 채널이 필요한
/// 추가 동의 항목이 붙고, 앱이 이메일로 하는 일이 하나도 없다 — 계정을
/// 가리키는 것은 [uid] 이고 사람에게 보이는 것은 사용자 문서의 닉네임이다.
@immutable
class AuthUser {
  const AuthUser({required this.uid, this.displayName});

  /// Firebase Auth uid — 사용자 문서 경로(`users/{uid}`)의 그 값이다.
  final String uid;

  /// 제공자가 준 표시 이름. 없을 수 있고, 앱의 닉네임 원본이 아니다
  /// (원본은 사용자 문서의 `nickname` — 첫 문서를 만들 때 씨앗으로만 쓴다).
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(uid, displayName);

  @override
  String toString() => 'AuthUser($uid)';
}

/// 인증 경계 — 로그인·로그아웃·세션 상태.
///
/// 구현은 실패를 `guardBackend` 로 감싸 도메인 오류만 던진다.
abstract class AuthService {
  /// 지금까지 **확인된** 세션의 사용자. 없거나 아직 확인 전이면 null.
  ///
  /// 화면 분기에 쓰지 않는다. 계약상 "로그아웃"과 "아직 모름"이 같은 null 로
  /// 올 수 있기 때문이다. 분기는 [authStateChanges] 로 한다 — 거기서는
  /// "아직 모름"이 값의 부재로 구분된다.
  /// (Firebase 구현은 `Firebase.initializeApp()` 직후에 상태를 확정하므로
  /// 실제로는 모르는 구간이 없지만, 계약을 그 구현 하나에 맞춰 좁히지 않는다.)
  AuthUser? get currentUser;

  /// 세션 변화 — 로그인·로그아웃·토큰 만료가 여기로 흐른다.
  /// 루트 게이트(2.1)가 이 스트림 하나로 화면을 가른다.
  ///
  /// **계약:** 구독하는 순간 지금 아는 세션 상태를 한 번 흘린다. 아직 모르면
  /// (세션 복원 전) 아무것도 흘리지 않고 알게 될 때까지 기다린다. 구현이 그
  /// 침묵을 지켜야 게이트가 "아직 갈래를 못 정했다"와 "로그아웃"을 구분할 수
  /// 있다.
  Stream<AuthUser?> authStateChanges();

  /// [provider] 로 로그인하고 세션의 사용자를 돌려준다.
  Future<AuthUser> signIn(AuthProviderId provider);

  /// 로그아웃 — 이후 [currentUser] 는 null 이다.
  Future<void> signOut();
}

/// 화면이 소비하는 인증 서비스 주입 지점.
///
/// 기본값은 Firebase 구현이다. 설정 파일이 없는 실행에서는 그 구현이 서지
/// 못하고 [BackendUnknownError] 로 던진다 — 조용히 "로그아웃 상태"를 돌려주는
/// 대역을 기본값으로 두지 않는 것은, 설정을 빠뜨린 실행이 오류 대신
/// "로그인하지 않은 사람"처럼 보이면 그 실수가 실행 중에 드러나지 않기
/// 때문이다. 테스트는 여전히 override 로 가짜 구현을 주입한다.
final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (ref) => FirebaseAuthService.instance,
);

/// 지금의 로그인 상태 — 루트 게이트가 화면을 가르는 값 하나.
///
/// 값은 [AuthService.authStateChanges] 하나에서만 온다. [AuthService.currentUser]
/// 로 첫 값을 미리 채우지 않는 것은 계약상 그 값이 "로그아웃"과 "아직 모름"을
/// 같은 null 로 말할 수 있기 때문이다 — 확정되지 않은 null 을 첫 값으로 흘리면
/// 콜드 스타트에서 로그인 화면이 한 번 번쩍인 뒤 홈으로 바뀐다. 스트림에서는
/// "아직 모름"이 값의 부재(= 게이트의 로딩 갈래)로 구분되므로 그 일이 없다.
///
/// 스트림 오류는 [guardBackendStream] 이 [BackendError] 로 옮긴다 — 게이트는
/// 그 실패를 "로그인 화면 + 안내"로 받는다. 세션을 확인하지 못한 실행을
/// 로그인한 것으로 볼 수는 없고, 아무 말 없이 로그인 화면으로 되돌리면
/// 사용자에게는 까닭 없이 로그아웃된 것으로 보이기 때문이다.
///
/// 인증 서비스가 서지 못한 실행(설정 파일 없음, 또는 주입 없는 테스트)에서는
/// 이 provider 가 오류 상태가 된다 — 조용히 "로그아웃한 사람"이 되지 않는다는
/// 1.6 의 판단이 게이트까지 그대로 이어진다.
final StreamProvider<AuthUser?> authStateProvider = StreamProvider<AuthUser?>(
  (ref) => guardBackendStream(ref.watch(authServiceProvider).authStateChanges()),
  // 자동 재시도를 끈다. riverpod 의 기본 재시도는 실패한 provider 를 잠시 뒤
  // 다시 세우는데, 여기서 그러면 게이트가 "로그인 화면 → (몇백 ms) → 홈"으로
  // 저 혼자 튀고 그 사이 사용자는 자기가 무엇을 봤는지 알 수 없게 된다.
  // 세션 실패는 사람이 다시 로그인해서 푸는 일이라, 다시 세우는 시점도
  // 사람의 행동(로그인 버튼)에 맞춘다.
  retry: (retryCount, error) => null,
);
