/// Step 3.4 boundary tests — 마이페이지 탭.
///
/// 재는 갈래:
///  1) 이메일이 있는 계정 — 닉네임·이메일·프로필 색 세 정보가 보인다.
///  2) 이메일이 없는 계정(카카오) — 그 자리가 빈칸이 아니라 제공자 표시로
///     대신한다.
///  3) 닉네임을 바꾸면 화면과 서버 문서 양쪽에 반영된다.
///  4) 닉네임이 계약 길이(UTF-16 코드 단위 1~20)를 벗어나면 저장하지 않고
///     안내한다.
///  5) 프로필 색을 바꾸면 서버 문서에 반영되고, 이 화면이 그 값을 실제로
///     써서 앱바 색이 바뀐다(`profileThemeKey` 를 읽는 첫 화면).
///  6) 로그아웃 버튼이 `AuthService.signOut` 을 실제로 부른다.
///  7) 프로필 색을 바꾸는 쓰기는 **`profileThemeKey` 만** 내보낸다 —
///     `favoriteTeamId` 는 건드리지 않는다(둘을 분리해 둔 스키마 취지가
///     실제 쓰기에서도 지켜지는지 — 5)는 화면의 겉모습만 잰다).
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
import 'package:kbo_away_fans/design/team_themes.dart';
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
      NewUserProfile(
        nickname: nickname,
        favoriteTeamId: teamId,
        profileThemeKey: teamId,
      ),
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

  /// 체크 아이콘이 [teamId] 스와치 안에 실제로 그려졌는지 — "선택됨" 표시를
  /// 문구가 아니라 위젯 트리로 잰다.
  Finder checkedSwatch(String teamId) => find.descendant(
    of: find.byKey(ValueKey('profile-color-$teamId')),
    matching: find.byIcon(Icons.check_rounded),
  );

  testWidgets('이메일이 있는 계정은 닉네임·이메일·선택된 프로필 색을 보여준다', (tester) async {
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
    // 지금 프로필 색(lg)의 스와치에만 체크가 있다.
    expect(checkedSwatch('lg'), findsOneWidget);
    expect(checkedSwatch('doosan'), findsNothing);
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
    expect(find.byKey(const ValueKey('profile-nickname-field')), findsOneWidget);
    expect(store.documents[_uid]?[UserFields.nickname], '옛날닉네임');
  });

  testWidgets('프로필 색을 바꾸면 서버 문서에 반영되고 이 화면의 앱바 색이 그 팀 색으로 바뀐다', (
    tester,
  ) async {
    await seedProfile(teamId: 'lg');

    await tester.pumpWidget(
      screen(const AuthUser(uid: _uid, email: 'fan@example.com')),
    );
    await tester.pumpAndSettle();

    // 바꾸기 전 — lg 색이 앱바에 칠해져 있다.
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      TeamThemes.lg.primary,
    );

    await tester.tap(find.byKey(const ValueKey('profile-color-doosan')));
    await tester.pumpAndSettle();

    expect(store.documents[_uid]?[UserFields.profileThemeKey], 'doosan');
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      TeamThemes.doosan.primary,
      reason: 'profileThemeKey 가 실제로 화면에 쓰였다면 앱바 색이 바뀐다',
    );
    expect(checkedSwatch('doosan'), findsOneWidget);
    expect(checkedSwatch('lg'), findsNothing);
  });

  testWidgets(
    '프로필 색을 바꾸는 쓰기는 profileThemeKey 만 내보내고 favoriteTeamId 는 그대로다',
    (tester) async {
      // favoriteTeamId 와 profileThemeKey 를 다르게 심어 둔다 — 둘이 같은 값으로
      // 시작하면 "어차피 같은 값이니 한 번에 쓰자"는 변이가 문서 값을 보는
      // 단언까지 우연히 통과시킬 수 있다(이 사이클이 실제로 겪은 함정).
      await store.createProfile(
        _uid,
        const NewUserProfile(
          nickname: '테스트닉네임',
          favoriteTeamId: 'lg',
          profileThemeKey: 'kt',
        ),
      );

      await tester.pumpWidget(
        screen(const AuthUser(uid: _uid, email: 'fan@example.com')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('profile-color-doosan')));
      await tester.pumpAndSettle();

      expect(store.documents[_uid]?[UserFields.profileThemeKey], 'doosan');
      // 응원 팀은 색을 바꾸기 전 값(lg) 그대로다 — 색 스와치는 팀 선택이 아니다.
      expect(
        store.documents[_uid]?[UserFields.favoriteTeamId],
        'lg',
        reason: '프로필 색 변경이 응원 팀까지 함께 바꾸면 홈 화면·다음 원정 경기 계산이 '
            '사람이 누르지 않은 이유로 통째로 달라진다',
      );
    },
  );

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
