/// Step 3.4 boundary tests — 마이페이지 탭.
///
/// 재는 갈래:
///  1) 이메일이 있는 계정 — 닉네임·이메일 두 정보가 보인다.
///  2) 이메일이 없는 계정(카카오) — 그 자리가 빈칸이 아니라 제공자 표시로
///     대신한다.
///  3) 닉네임을 바꾸면 화면과 서버 문서 양쪽에 반영된다.
///  4) 닉네임이 계약 길이(UTF-16 코드 단위 1~20)를 벗어나면 저장하지 않고
///     안내한다.
///  5) 로그아웃 버튼이 `AuthService.signOut` 을 실제로 부른다.
///
/// 로그아웃 뒤 로그인 화면으로 돌아오고 다시 로그인하면 홈까지 들어가는
/// 전이는 `profile_logout_transition_test.dart` 가 `RootGate` 를 통째로
/// 세워 잰다 — 이 파일은 `ProfileTabScreen` 하나만 세운다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/features/profile/profile_tab_screen.dart';

import '../../backend/fake_backend.dart';

const _uid = 'google-uid';

void main() {
  late FakeUserDataStore store;
  late FakeAuthService auth;

  setUp(() {
    store = FakeUserDataStore();
  });

  tearDown(() async {
    await auth.dispose();
    await store.dispose();
  });

  Future<void> seedProfile({
    String nickname = '테스트닉네임',
    String teamId = 'lg',
  }) async {
    await store.createProfile(
      _uid,
      NewUserProfile(nickname: nickname, favoriteTeamId: teamId),
    );
  }

  Widget screen(AuthUser signedIn) {
    auth = FakeAuthService(signedIn: signedIn);
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: ProfileTabScreen()),
    );
  }

  testWidgets('이메일이 있는 계정은 닉네임·이메일을 보여준다', (tester) async {
    await seedProfile(nickname: '테스트닉네임', teamId: 'lg');

    await tester.pumpWidget(
      screen(
        const AuthUser(uid: _uid, displayName: '보리', email: 'fan@example.com'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-nickname-text')), findsOneWidget);
    expect(find.text('테스트닉네임'), findsOneWidget);
    expect(find.text('fan@example.com'), findsOneWidget);
    expect(find.text(ProfileTabScreen.noEmailProviderLabel), findsNothing);
  });

  testWidgets('이메일이 없는 계정(카카오)은 그 자리가 빈칸이 아니라 제공자 표시로 대신한다', (tester) async {
    await seedProfile();

    await tester.pumpWidget(
      screen(const AuthUser(uid: _uid, displayName: null, email: null)),
    );
    await tester.pumpAndSettle();

    expect(find.text(ProfileTabScreen.noEmailProviderLabel), findsOneWidget);
    // 진짜 빈 문자열 Text 가 그 자리를 대신 채우고 있는 것이 아니다.
    expect(find.text(''), findsNothing);
  });

  testWidgets('닉네임을 바꾸면 화면과 서버 문서 양쪽에 반영된다', (tester) async {
    await seedProfile(nickname: '옛날닉네임');

    await tester.pumpWidget(
      screen(const AuthUser(uid: _uid, email: 'fan@example.com')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-nickname-edit')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('profile-nickname-field')),
      '새닉네임',
    );
    await tester.tap(find.byKey(const ValueKey('profile-nickname-save')));
    await tester.pumpAndSettle();

    // 서버 문서 — "화면만 바뀌고 안 나갔다"를 잡는 자리.
    expect(store.documents[_uid]?[UserFields.nickname], '새닉네임');
    // 화면 — 편집 모드가 닫히고 새 값이 보인다.
    expect(find.byKey(const ValueKey('profile-nickname-field')), findsNothing);
    expect(find.text('새닉네임'), findsOneWidget);
    expect(find.text('옛날닉네임'), findsNothing);
  });

  testWidgets('닉네임이 계약 길이를 벗어나면 저장하지 않고 안내한다', (tester) async {
    await seedProfile(nickname: '옛날닉네임');

    await tester.pumpWidget(
      screen(const AuthUser(uid: _uid, email: 'fan@example.com')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-nickname-edit')));
    await tester.pumpAndSettle();

    // 21자 — kNicknameMaxLength(20)를 하나 넘는다.
    await tester.enterText(
      find.byKey(const ValueKey('profile-nickname-field')),
      '가' * 21,
    );
    await tester.tap(find.byKey(const ValueKey('profile-nickname-save')));
    await tester.pumpAndSettle();

    expect(find.text(ProfileTabScreen.nicknameLengthError), findsOneWidget);
    // 편집 모드가 그대로 열려 있다 — 저장되지 않았다.
    expect(
      find.byKey(const ValueKey('profile-nickname-field')),
      findsOneWidget,
    );
    expect(store.documents[_uid]?[UserFields.nickname], '옛날닉네임');
  });

  testWidgets('로그아웃 버튼을 누르면 AuthService.signOut 이 실제로 불린다', (tester) async {
    await seedProfile();

    await tester.pumpWidget(
      screen(const AuthUser(uid: _uid, email: 'fan@example.com')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-sign-out')));
    // `pumpAndSettle` 을 쓰지 않는다 — 이 시험은 `RootGate` 없이
    // `ProfileTabScreen` 하나만 세우므로, 성공한 뒤에도 화면을 걷어갈 게이트가
    // 없어 로딩 스피너(끝나지 않는 애니메이션)가 그대로 남는다.
    await tester.pump();
    await tester.pump();

    expect(auth.signOutCalls, 1);
    expect(auth.currentUser, isNull);
  });
}
