/// 카카오 게이트웨이의 **액세스 토큰을 얻는 걸음** 전체와, callable 응답 읽기.
///
/// SDK 와 닿는 세 자리(앱 키·`KakaoSdk.init`·로그인 호출)는
/// `KakaoSdkAuthGateway.withSeams` 로 갈아 끼운다. 그래서 여기서 재는 조건은
/// **이 파일이 만든 것**이지 저장소의 형편이 아니다 — 앞 라운드까지 "앱 키가
/// 없는 실행"은 상수가 우연히 비어 있다는 사실에 얹혀 있어서, 사람이 카카오
/// 콘솔에서 키를 받아 채우는 순간 이 시험이 실기기 채널을 타고 깨졌다.
/// 재는 성질("설정이 없는 실행은 조용히 성공하지 않는다")은 키를 채운 뒤에도
/// 참이어야 하므로, 조건도 시험이 세운다.
///
/// callable 호출(`exchange`)만은 여기서 돌지 않는다 — 네트워크다. 그 자리를
/// 가짜로 갈아 끼운 경로는 `kakao_sign_in_test.dart` 가 잰다.
library;

import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:kbo_away_fans/backend/auth_kakao.dart';
import 'package:kbo_away_fans/backend/errors.dart';

/// 부르면 시험이 실패하는 자리 — "여기까지 오지 않는다"를 재는 대역이다.
Future<void> _neverInit(String nativeAppKey) async =>
    fail('앱 키가 없으면 SDK 를 건드리기 전에 막아야 한다');

Future<String> _neverLogin() async => fail('초기화가 실패했으면 로그인까지 가지 않는다');

void main() {
  group('앱 키가 없는 실행', () {
    test('조용히 넘어가지 않고 kakao-key-missing 으로 드러나게 실패한다', () async {
      final gateway = KakaoSdkAuthGateway.withSeams(
        appKey: '',
        sdkInit: _neverInit,
        sdkLogin: _neverLogin,
      );

      Object? thrown;
      try {
        await gateway.obtainAccessToken();
      } catch (error) {
        thrown = error;
      }

      expect(thrown, isA<BackendUnknownError>());
      expect((thrown! as BackendError).code, kKakaoKeyMissingCode);
    });

    test('앱이 쓰는 생성자는 저장소의 상수를 그대로 꽂는다 (소스 대조)', () {
      // 주입점이 생기면서 갈라질 수 있는 것이 이것이다: 시험은 자기 키로 돌고
      // 앱은 상수로 도는데, 그 상수가 기본 생성자에 꽂히지 않으면 아무도
      // 모른다. 실행으로 잴 수 없는 것은 키가 찬 실행에서 그 자리가 곧바로
      // 플랫폼 채널을 타기 때문이고, 그래서 소스를 읽는다
      // (`app_check_activation_test.dart` 의 "릴리스 갈래가 소스에 서 있다"와
      // 같은 처리 — 실행이 닿지 못하는 배선은 소스로 못을 박는다).
      final source = File('lib/backend/auth_kakao.dart').readAsStringSync();

      expect(
        source.contains('appKey: kKakaoNativeAppKey'),
        isTrue,
        reason:
            '기본 생성자가 저장소의 앱 키를 꽂지 않으면, 시험은 전부 초록불인데 '
            '앱만 키 없이 SDK 를 부른다',
      );
    });
  });

  group('SDK 초기화의 실패는 카카오 어휘를 잃지 않는다', () {
    test('KakaoSdk.init 이 던진 카카오 예외가 kakao-client-* 로 옮겨진다', () async {
      final gateway = KakaoSdkAuthGateway.withSeams(
        appKey: 'app-key',
        sdkInit: (_) async =>
            throw KakaoClientException(ClientErrorCause.illegalState, '앱 상태'),
        sdkLogin: _neverLogin,
      );

      await expectLater(
        gateway.obtainAccessToken(),
        throwsA(
          isA<BackendUnknownError>().having(
            (e) => e.code,
            'code',
            'kakao-client-illegalState',
          ),
        ),
        reason:
            '옮기지 않으면 guardBackend 가 unknown 으로 뭉개서, 함수 로그와 버그 '
            '리포트에서 "SDK 초기화가 실패했다"가 "알 수 없음"으로 보인다',
      );
    });

    test('초기화의 플랫폼 채널 예외는 kakao-platform-* 로 옮겨진다', () async {
      final gateway = KakaoSdkAuthGateway.withSeams(
        appKey: 'app-key',
        sdkInit: (_) async => throw PlatformException(code: 'channel-error'),
        sdkLogin: _neverLogin,
      );

      await expectLater(
        gateway.obtainAccessToken(),
        throwsA(
          isA<BackendUnknownError>().having(
            (e) => e.code,
            'code',
            'kakao-platform-channel-error',
          ),
        ),
      );
    });

    test('실패한 초기화는 기억하지 않는다 — 다음 시도가 다시 부른다', () async {
      var calls = 0;
      final gateway = KakaoSdkAuthGateway.withSeams(
        appKey: 'app-key',
        sdkInit: (_) async {
          calls++;
          if (calls == 1) {
            throw KakaoClientException(ClientErrorCause.illegalState, '앱 상태');
          }
        },
        sdkLogin: () async => 'access-token',
      );

      await expectLater(
        gateway.obtainAccessToken(),
        throwsA(isA<BackendError>()),
      );
      expect(await gateway.obtainAccessToken(), 'access-token');
      expect(calls, 2, reason: '기억하면 첫 실패가 앱을 켜 있는 동안 카카오 로그인을 영구히 막는다');
    });

    test('성공한 초기화는 한 번만 부른다', () async {
      var calls = 0;
      final gateway = KakaoSdkAuthGateway.withSeams(
        appKey: 'app-key',
        sdkInit: (_) async => calls++,
        sdkLogin: () async => 'access-token',
      );

      await gateway.obtainAccessToken();
      await gateway.obtainAccessToken();

      expect(calls, 1);
    });
  });

  group('로그인이 돌려준 액세스 토큰', () {
    test('빈 토큰은 성공으로 치지 않는다 (있을 수 없는 모양)', () async {
      final gateway = KakaoSdkAuthGateway.withSeams(
        appKey: 'app-key',
        sdkInit: (_) async {},
        sdkLogin: () async => '',
      );

      await expectLater(
        gateway.obtainAccessToken(),
        throwsA(
          isA<BackendUnknownError>().having(
            (e) => e.code,
            'code',
            kKakaoAccessTokenMissingCode,
          ),
        ),
        reason:
            '빈 토큰을 그대로 들고 가면 교환이 invalid-argument 로 죽고, 무엇이 '
            '비었는지는 함수 쪽 로그에서만 읽힌다',
      );
    });

    test('로그인의 카카오 예외도 도메인 오류로 옮겨진다 (취소는 권한 갈래)', () async {
      final gateway = KakaoSdkAuthGateway.withSeams(
        appKey: 'app-key',
        sdkInit: (_) async {},
        sdkLogin: () async =>
            throw KakaoClientException(ClientErrorCause.cancelled, '사용자 취소'),
      );

      await expectLater(
        gateway.obtainAccessToken(),
        throwsA(
          isA<BackendPermissionError>().having(
            (e) => e.code,
            'code',
            'canceled',
          ),
        ),
      );
    });

    test('제대로 돌아온 토큰은 그대로 나간다', () async {
      final gateway = KakaoSdkAuthGateway.withSeams(
        appKey: 'app-key',
        sdkInit: (_) async {},
        sdkLogin: () async => 'access-token',
      );

      expect(await gateway.obtainAccessToken(), 'access-token');
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
