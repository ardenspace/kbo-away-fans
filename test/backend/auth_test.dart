/// Step 1.6 인증 경계 단위 테스트 — 세 제공자 로그인·로그아웃·세션 상태가
/// 한 타입 뒤에 있는지, 실패가 도메인 오류로 나오는지 검증한다.
/// (실제 Firebase 연결은 phase 2 — 여기서는 경계의 모양만 잰다.)
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/errors.dart';

import 'fake_backend.dart';

void main() {
  late FakeAuthService auth;

  setUp(() {
    auth = FakeAuthService();
  });

  tearDown(() async {
    await auth.dispose();
  });

  test('제공자는 구글·애플·카카오 셋뿐이다', () {
    expect(
      AuthProviderId.values.map((provider) => provider.name).toSet(),
      {'google', 'apple', 'kakao'},
    );
  });

  test('로그인하면 세션이 생기고 상태 스트림이 사용자를 흘린다', () async {
    final seen = <AuthUser?>[];
    final subscription = auth.authStateChanges().listen(seen.add);
    addTearDown(subscription.cancel);

    expect(auth.currentUser, isNull);

    final user = await auth.signIn(AuthProviderId.kakao);
    await Future<void>.delayed(Duration.zero);

    expect(user.uid, isNotEmpty);
    expect(auth.currentUser, user);
    expect(seen, [user]);
  });

  test('로그아웃하면 세션이 사라진다', () async {
    await auth.signIn(AuthProviderId.google);

    await auth.signOut();

    expect(auth.currentUser, isNull);
  });

  test('세 제공자 전부 같은 경로로 로그인한다', () async {
    for (final provider in AuthProviderId.values) {
      await auth.signIn(provider);
    }

    expect(auth.signInCalls, AuthProviderId.values);
  });

  test('로그인 실패는 도메인 오류로 나온다', () async {
    auth.failure = const BackendNetworkError(code: 'network-request-failed');

    await expectLater(
      auth.signIn(AuthProviderId.apple),
      throwsA(isA<BackendNetworkError>()),
    );
    expect(auth.currentUser, isNull);
  });

  test('사용자 값은 uid 와 표시 이름뿐 — 이메일을 들지 않는다', () {
    const user = AuthUser(uid: 'u1', displayName: '원정러');

    expect(user.uid, 'u1');
    expect(user.displayName, '원정러');
    expect(user, const AuthUser(uid: 'u1', displayName: '원정러'));
  });
}
