/// 오류 봉투 — 백엔드 호출의 모든 실패가 통과하는 한 자리.
///
/// - Firebase SDK 예외([FirebaseException])는 이 파일 밖으로 나가지 않는다.
///   화면과 상태 계층은 아래 세 도메인 오류만 본다.
/// - 도메인이 셋인 것은 **화면이 다르게 반응할 수 있는 갈래가 셋**이기 때문이다:
///   네트워크(다시 시도하면 된다), 권한(로그인·소유권 문제라 다시 시도해도
///   같다), 알 수 없음(그 밖의 전부). 코드마다 갈래를 늘리면 화면이 처리할 수
///   없는 구분이 생기고, 하나로 합치면 "다시 시도" 안내를 걸 자리가 없어진다.
/// - 원래 코드([BackendError.code])와 원인([BackendError.cause])은 버리지
///   않고 들고 간다 — 도메인은 화면의 어휘이고, 코드는 진단의 어휘다.
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// 네트워크로 읽는 Firebase 오류 코드 (Firestore·Auth 공통).
///
/// Firestore 의 `unavailable`·`deadline-exceeded` 는 서버에 닿지 못했다는
/// 뜻이고, Auth 의 `network-request-failed` 도 같은 사정이다.
const Set<String> kNetworkErrorCodes = {
  'unavailable',
  'deadline-exceeded',
  'network-request-failed',
};

/// 권한으로 읽는 Firebase 오류 코드.
///
/// 규칙이 거부했거나(`permission-denied`) 세션이 없거나 죽은 경우다 —
/// 셋 다 "다시 시도"가 아니라 "로그인 상태를 되살려야 한다"로 이어진다.
const Set<String> kPermissionErrorCodes = {
  'permission-denied',
  'unauthenticated',
  'user-disabled',
  'user-token-expired',
  'invalid-user-token',
};

/// 백엔드 실패의 도메인 표현 — 하위 타입은 아래 셋뿐이다(sealed).
sealed class BackendError implements Exception {
  const BackendError({required this.code, this.cause});

  /// 진단용 원래 코드 — Firebase 코드이거나, Firebase 밖 실패면 그 표시.
  final String code;

  /// 원래 예외. 로그·버그 리포트에서 쓰고 화면 분기에는 쓰지 않는다.
  final Object? cause;

  /// 어떤 실패든 도메인 오류로 옮기는 **유일한 변환 경로**.
  ///
  /// 이미 도메인 오류면 그대로 돌려준다 — 계층을 지날 때마다 포장이
  /// 겹치면 원래 도메인이 `unknown` 아래로 숨는다.
  static BackendError from(Object error) {
    if (error is BackendError) return error;
    if (error is FirebaseException) {
      if (kNetworkErrorCodes.contains(error.code)) {
        return BackendNetworkError(code: error.code, cause: error);
      }
      if (kPermissionErrorCodes.contains(error.code)) {
        return BackendPermissionError(code: error.code, cause: error);
      }
      return BackendUnknownError(code: error.code, cause: error);
    }
    // SDK 를 거치지 않는 호출(예: 커스텀 토큰 교환의 HTTP)이 시간 안에
    // 끝나지 못한 경우도 네트워크 갈래다.
    if (error is TimeoutException) {
      return BackendNetworkError(code: 'timeout', cause: error);
    }
    return BackendUnknownError(code: 'unknown', cause: error);
  }

  @override
  String toString() => '$runtimeType($code)';
}

/// 서버에 닿지 못했다 — 같은 요청을 다시 시도할 수 있다.
final class BackendNetworkError extends BackendError {
  const BackendNetworkError({required super.code, super.cause});
}

/// 규칙이 거부했거나 세션이 없다 — 다시 시도해도 같고, 로그인 상태를
/// 되살리는 쪽으로 이어져야 한다.
final class BackendPermissionError extends BackendError {
  const BackendPermissionError({required super.code, super.cause});
}

/// 위 둘로 읽히지 않는 나머지 전부.
final class BackendUnknownError extends BackendError {
  const BackendUnknownError({required super.code, super.cause});
}

/// 백엔드 호출을 감싸 실패를 도메인 오류로 바꾼다.
///
/// 백엔드 구현은 SDK 를 부르는 자리마다 이 함수를 거친다 — 변환이 호출마다
/// 흩어지면 어느 한 자리가 빠졌을 때 SDK 예외가 그대로 화면까지 샌다
/// (분석 래퍼가 검증을 `AnalyticsClient.log` 한 경로로 모은 것과 같은 이유).
Future<T> guardBackend<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (error) {
    throw BackendError.from(error);
  }
}
