/// 카카오 게이트웨이의 **SDK 를 타지 않는 조각들** — 설정이 없는 실행의 실패,
/// 그리고 callable 응답 읽기.
///
/// `KakaoSdkAuthGateway` 의 나머지(카카오 SDK 로그인·callable 호출)는 플랫폼
/// 채널과 네트워크라 여기서 돌지 않는다. 그 자리를 가짜로 갈아 끼운 경로는
/// `kakao_sign_in_test.dart` 가 잰다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth_kakao.dart';
import 'package:kbo_away_fans/backend/errors.dart';

void main() {
  group('앱 키가 없는 실행', () {
    test('조용히 넘어가지 않고 kakao-key-missing 으로 드러나게 실패한다', () async {
      // 저장소의 기본값은 빈 문자열이다 — 카카오 앱을 아직 등록하지 않은 클론.
      expect(
        kKakaoNativeAppKey,
        isEmpty,
        reason:
            '이 시험의 전제다. 키를 채웠다면 이 파일이 아니라 실기기에서 확인해야 한다 '
            '— 그때는 이 케이스를 지우지 말고 전제를 다시 세울 것',
      );

      Object? thrown;
      try {
        await KakaoSdkAuthGateway().obtainAccessToken();
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isA<BackendUnknownError>());
      expect((thrown! as BackendError).code, kKakaoKeyMissingCode);
    });
  });

  group('callable 응답 읽기', () {
    test('규약대로면 값 객체가 나온다', () {
      final token = kakaoCustomTokenFromCallable(<String, Object?>{
        'customToken': 'ct',
        'uid': 'kakao:42',
        'nickname': '원정러',
      });

      expect(
        token,
        const KakaoCustomToken(
          customToken: 'ct',
          uid: 'kakao:42',
          nickname: '원정러',
        ),
      );
    });

    test('닉네임이 null 이면 그대로 null 이다 (동의하지 않은 사람)', () {
      final token = kakaoCustomTokenFromCallable(<String, Object?>{
        'customToken': 'ct',
        'uid': 'kakao:42',
        'nickname': null,
      });

      expect(token.nickname, isNull);
    });

    test('빈 닉네임은 null 로 접는다 — 사용자 문서의 길이 계약이 1자 이상이다', () {
      final token = kakaoCustomTokenFromCallable(<String, Object?>{
        'customToken': 'ct',
        'uid': 'kakao:42',
        'nickname': '',
      });

      expect(token.nickname, isNull);
    });

    test('커스텀 토큰이 비었으면 malformed 로 막는다 (빈 토큰으로 SDK 를 부르지 않는다)', () {
      expect(
        () => kakaoCustomTokenFromCallable(<String, Object?>{
          'customToken': '',
          'uid': 'kakao:42',
        }),
        throwsA(
          isA<BackendUnknownError>().having(
            (e) => e.code,
            'code',
            kKakaoCustomTokenMalformedCode,
          ),
        ),
      );
    });

    test('uid 가 없어도 malformed 다 — 규약이 셋을 함께 약속한다', () {
      expect(
        () => kakaoCustomTokenFromCallable(<String, Object?>{
          'customToken': 'ct',
        }),
        throwsA(
          isA<BackendUnknownError>().having(
            (e) => e.code,
            'code',
            kKakaoCustomTokenMalformedCode,
          ),
        ),
      );
    });

    test('map 이 아닌 응답도 malformed 다', () {
      expect(
        () => kakaoCustomTokenFromCallable('customToken'),
        throwsA(isA<BackendUnknownError>()),
      );
      expect(
        () => kakaoCustomTokenFromCallable(null),
        throwsA(isA<BackendUnknownError>()),
      );
    });
  });

  test('호출 좌표가 손대지 않은 값 그대로다', () {
    // 이 케이스는 **리터럴 못**이다: 두 파일을 대조하지 않고, 상수가 조용히
    // 바뀌지 않았다는 것만 말한다. `functions/index.js` 와의 실제 대조는
    // `backend_wiring_sync_test.dart` 가 한다 — 값을 옮길 때는 그 파일이 잡는다.
    expect(kKakaoFunctionRegion, 'asia-northeast3');
    expect(kKakaoCustomTokenCallable, 'kakaoCustomToken');
  });
}
