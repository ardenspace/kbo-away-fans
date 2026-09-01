/// Step 2.2 boundary tests — 실 구현이 붙은 뒤의 인증 계층 계약.
///
/// 두 가지를 명령으로 잰다.
///
///  1) **설정 파일이 없는 실행**에서 인증이 어떻게 드러나는가. 분석 래퍼처럼
///     조용히 no-op 하지 않고 도메인 오류로 드러나야 한다 — 계정 없이 쓰는
///     경로가 없는 앱에서 "조용한 no-op 인증"은 곧 설정 실수를 숨기는 것이다.
///     동시에 SDK 예외가 그대로 새지도 않아야 한다.
///  2) **세션을 아직 모르는 구간**이 로그아웃으로 확정되지 않는가. 실 Firebase
///     Auth 는 앱이 뜬 직후 잠깐 그 상태인데, 그 null 을 값으로 흘리면 로그인해
///     둔 사람의 콜드 스타트에서 로그인 화면이 번쩍인다.
///
/// 실 Firebase 연결 자체(구글 계정 선택, 애플 시트)는 여기서 잴 수 없다 —
/// 그것은 실기기에서 사람이 보는 acceptance 다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/auth_firebase.dart';
import 'package:kbo_away_fans/backend/errors.dart';

import 'fake_backend.dart';

const AuthUser _user = AuthUser(uid: 'uid-1', displayName: '원정러');

/// provider 안에서 던진 오류는 riverpod 이 한 겹 싸서 내보낸다 — 그 봉투를
/// 벗겨 원래 오류를 본다 (화면은 `BackendError.from` 한 경로로 같은 일을 한다).
Object _unwrap(Object error) =>
    error is ProviderException ? error.exception : error;

void main() {
  group('설정 파일이 없는 실행', () {
    test('인증 서비스는 도메인 오류로 드러난다 — SDK 예외가 새지 않는다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      Object? thrown;
      try {
        container.read(authServiceProvider);
      } catch (error) {
        thrown = _unwrap(error);
      }

      expect(thrown, isA<BackendUnknownError>());
      expect((thrown! as BackendError).code, kFirebaseUnconfiguredCode);
    });

    test('로그인 상태는 오류가 된다 — 조용한 로그아웃이 아니다', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      Object? thrown;
      try {
        await container.read(authStateProvider.future);
      } catch (error) {
        thrown = _unwrap(error);
      }

      expect(thrown, isA<BackendError>());
    });
  });

  group('세션을 아직 모르는 구간', () {
    test('복원 전에는 값이 없다 — 확정된 로그아웃으로 흐르지 않는다', () async {
      final auth = UnknownSessionAuthService();
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        authStateProvider,
        (previous, next) {},
      );
      await pumpEventQueue();

      expect(subscription.read().isLoading, isTrue);
      expect(
        subscription.read().hasValue,
        isFalse,
        reason: '복원 전의 null 을 값으로 흘리면 게이트가 로그인 화면을 띄운다 (콜드 스타트 번쩍임)',
      );
    });

    test('복원되면 그 값이 첫 값이다', () async {
      final auth = UnknownSessionAuthService();
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        authStateProvider,
        (previous, next) {},
      );
      auth.restore(_user);
      await pumpEventQueue();

      expect(subscription.read().value, _user);
    });

    test('복원 결과가 로그아웃이면 그때 null 이 첫 값이 된다', () async {
      final auth = UnknownSessionAuthService();
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        authStateProvider,
        (previous, next) {},
      );
      auth.restore(null);
      await pumpEventQueue();

      expect(subscription.read().hasValue, isTrue);
      expect(subscription.read().value, isNull);
    });
  });

  group('signIn 이 성공을 돌려주면 세션도 서 있다', () {
    // 로그인 화면이 잠금을 푸는 판정(`authStateProvider` 를 다시 세워 첫 값을
    // 읽는다)이 여기에 기댄다. 성공을 돌려주고도 세션이 서지 않으면 게이트가
    // 화면을 걷어가지 않고, 잠금을 푸는 자리가 게이트뿐이라 앱을 다시 켜는 것
    // 말고 나갈 길이 없어진다.
    test('모르는 상태에서 시작해도 성공 직후 currentUser 가 채워진다', () async {
      final auth = UnknownSessionAuthService();
      addTearDown(auth.dispose);
      expect(auth.currentUser, isNull);

      final user = await auth.signIn(AuthProviderId.google);

      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser, user);
    });

    test('성공 직후 다시 세운 로그인 상태의 첫 값이 그 사용자다', () async {
      final auth = UnknownSessionAuthService();
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        authStateProvider,
        (previous, next) {},
      );
      await pumpEventQueue();
      expect(subscription.read().isLoading, isTrue);

      await auth.signIn(AuthProviderId.apple);
      container.invalidate(authStateProvider);

      expect(await container.read(authStateProvider.future), isNotNull);
    });
  });
}
