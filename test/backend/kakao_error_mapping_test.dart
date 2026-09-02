/// 카카오 SDK 쪽 **판단 두 가지**를 잰다 — 취소 판별과 카카오톡 폴백.
///
/// 이 둘은 `KakaoSdkAuthGateway` 안에 있지만 SDK 를 타지 않는다: 예외 하나를
/// 받아 도메인 오류를 고르는 순수 함수와, "어느 로그인을 어떤 순서로 부르는가"
/// 라는 규칙이다. 그런데 그 앞의 `_ensureSdkReady()` 가 앱 키 없음으로 먼저
/// 던져서, 게이트웨이 밖에서는 어떤 시험도 이 두 자리에 닿지 못했다 —
/// `.wellbegun/decisions.md` 의 [S] 결정 두 줄("취소는 세 모양으로 온다",
/// "취소가 아닌 실패면 계정 로그인으로 갈아타되 취소면 안 갈아탄다")이 재는 것
/// 없이 서 있었다. 그래서 두 판단을 `kakaoCustomTokenFromCallable` 과 같은
/// 처리로 꺼내 여기서 잰다.
///
/// 드러나는 자리는 **카카오톡이 깔렸지만 로그인돼 있지 않은 기기**다. 폴백이
/// 사라지면 그 사람에게 카카오 로그인은 아예 없는 것이 되는데, 저장소 안에서는
/// 아무 신호도 나지 않는다.
library;

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:kbo_away_fans/backend/auth_firebase.dart' show kSignInCanceledCode;
import 'package:kbo_away_fans/backend/auth_kakao.dart';
import 'package:kbo_away_fans/backend/errors.dart';

void main() {
  group('취소 판별 — 카카오는 이 사실을 세 모양으로 말한다', () {
    test('카카오톡 화면을 닫으면 KakaoClientException(cancelled) 이다', () {
      expect(
        kakaoSignInWasCanceled(
          KakaoClientException(ClientErrorCause.cancelled, '사용자 취소'),
        ),
        isTrue,
      );
    });

    test('동의 화면에서 거절하면 KakaoAuthException(accessDenied) 이다', () {
      expect(
        kakaoSignInWasCanceled(
          KakaoAuthException(AuthErrorCause.accessDenied, 'access_denied'),
        ),
        isTrue,
      );
    });

    test('네이티브 채널은 PlatformException CANCELED 로 말한다', () {
      expect(
        kakaoSignInWasCanceled(PlatformException(code: 'CANCELED')),
        isTrue,
      );
    });

    test('취소가 아닌 실패는 취소로 읽지 않는다', () {
      expect(
        kakaoSignInWasCanceled(
          KakaoClientException(ClientErrorCause.illegalState, '앱 상태'),
        ),
        isFalse,
      );
      expect(
        kakaoSignInWasCanceled(
          KakaoAuthException(AuthErrorCause.misconfigured, 'misconfigured'),
        ),
        isFalse,
      );
      expect(
        kakaoSignInWasCanceled(PlatformException(code: 'NOT_SUPPORT_ERROR')),
        isFalse,
      );
    });
  });

  group('카카오 예외 → 도메인 오류', () {
    test('취소는 권한 갈래로 간다 — 화면 문구가 사용자가 한 일을 말한다', () {
      final error = backendErrorFromKakao(
        KakaoClientException(ClientErrorCause.cancelled, '사용자 취소'),
      );

      expect(error, isA<BackendPermissionError>());
      expect(error.code, kSignInCanceledCode);
    });

    test('동의 거절도 같은 자리로 온다', () {
      final error = backendErrorFromKakao(
        KakaoAuthException(AuthErrorCause.accessDenied, 'access_denied'),
      );

      expect(error, isA<BackendPermissionError>());
      expect(error.code, kSignInCanceledCode);
    });

    test('나머지 클라이언트 오류는 kakao-client- 접두로 알 수 없음이다', () {
      final error = backendErrorFromKakao(
        KakaoClientException(ClientErrorCause.notSupported, '미지원'),
      );

      expect(error, isA<BackendUnknownError>());
      expect(
        error.code,
        'kakao-client-notSupported',
        reason: '화면은 갈래를 더 나눌 수 없고, 진단에 필요한 것은 도메인이 아니라 이 코드다',
      );
    });

    test('나머지 인증 오류는 kakao-auth- 접두다', () {
      final error = backendErrorFromKakao(
        KakaoAuthException(AuthErrorCause.misconfigured, '플랫폼 설정'),
      );

      expect(error, isA<BackendUnknownError>());
      expect(error.code, 'kakao-auth-misconfigured');
    });

    test('둘 다 아닌 SDK 예외는 kakao-unknown 이다', () {
      final error = backendErrorFromKakao(KakaoException('알 수 없음'));

      expect(error, isA<BackendUnknownError>());
      expect(error.code, 'kakao-unknown');
    });
  });

  group('플랫폼 채널 예외 → 도메인 오류', () {
    test('CANCELED 는 권한 갈래다', () {
      final error = backendErrorFromPlatform(PlatformException(code: 'CANCELED'));

      expect(error, isA<BackendPermissionError>());
      expect(error.code, kSignInCanceledCode);
    });

    test('나머지는 kakao-platform- 접두로 알 수 없음이다', () {
      final error = backendErrorFromPlatform(
        PlatformException(code: 'NOT_SUPPORT_ERROR'),
      );

      expect(error, isA<BackendUnknownError>());
      expect(error.code, 'kakao-platform-NOT_SUPPORT_ERROR');
    });
  });

  group('카카오톡 폴백 — 어느 로그인을 어떤 순서로 부르는가', () {
    late List<String> calls;

    setUp(() => calls = <String>[]);

    Future<String> run({
      required bool talkInstalled,
      Object? talkFailure,
    }) => kakaoLoginWithTalkFallback<String>(
      isTalkInstalled: () async {
        calls.add('installed?');
        return talkInstalled;
      },
      withTalk: () async {
        calls.add('talk');
        if (talkFailure != null) throw talkFailure;
        return 'talk-token';
      },
      withAccount: () async {
        calls.add('account');
        return 'account-token';
      },
    );

    test('카카오톡이 없으면 계정 로그인으로 곧장 간다', () async {
      expect(await run(talkInstalled: false), 'account-token');
      expect(calls, ['installed?', 'account']);
    });

    test('카카오톡이 있으면 앱으로 로그인한다 (계정 창을 띄우지 않는다)', () async {
      expect(await run(talkInstalled: true), 'talk-token');
      expect(calls, ['installed?', 'talk']);
    });

    test('카카오톡 로그인이 취소가 아닌 이유로 실패하면 계정 로그인으로 갈아탄다', () async {
      // 카카오톡은 깔렸지만 로그인돼 있지 않은 기기 — 폴백이 사라지면 그 사람
      // 에게 카카오 로그인은 아예 없는 것이 된다.
      expect(
        await run(
          talkInstalled: true,
          talkFailure: KakaoClientException(
            ClientErrorCause.tokenNotFound,
            '카카오톡에 로그인돼 있지 않다',
          ),
        ),
        'account-token',
      );
      expect(calls, ['installed?', 'talk', 'account']);
    });

    test('취소면 갈아타지 않는다 — 스스로 닫은 사람에게 창을 다시 띄우지 않는다', () async {
      final canceled = KakaoClientException(
        ClientErrorCause.cancelled,
        '사용자 취소',
      );

      await expectLater(
        run(talkInstalled: true, talkFailure: canceled),
        throwsA(same(canceled)),
      );
      expect(
        calls,
        ['installed?', 'talk'],
        reason: '취소한 사람에게 계정 로그인 창을 곧바로 다시 띄우면 선택을 무시하는 모양이 된다',
      );
    });

    test('플랫폼 채널이 말하는 취소도 갈아타지 않는다', () async {
      final canceled = PlatformException(code: 'CANCELED');

      await expectLater(
        run(talkInstalled: true, talkFailure: canceled),
        throwsA(same(canceled)),
      );
      expect(calls, ['installed?', 'talk']);
    });
  });
}
