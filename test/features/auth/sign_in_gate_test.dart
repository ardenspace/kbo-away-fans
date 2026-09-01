/// Step 2.1 boundary tests — 로그인 게이트의 세 분기와 로그아웃 복귀.
///
/// 인증 상태는 [FakeAuthService] 를 `authServiceProvider` override 로 주입해
/// 테스트가 직접 조종한다 (실 Firebase 연결은 2.2 의 몫). 콘텐츠 4종은 다른
/// 위젯 테스트와 같은 이유로 override 한다 — 실 IO 는 fake async 안에서
/// 끝나지 않아 pumpAndSettle 이 멈춘다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/auth/sign_in_screen.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/team_select/selected_team.dart';
import 'package:kbo_away_fans/features/team_select/team_select_screen.dart';
import 'package:kbo_away_fans/ui/shared/social_sign_in_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';

const AuthUser _signedInUser = AuthUser(uid: 'uid-1', displayName: '원정러');
const ContentIssue _issue = ContentIssue(ContentIssueKind.network, 'fixture');

void main() {
  /// 인증 상태를 주입한 게이트. [auth] 가 null 이면 주입 자체가 없는 실행이다.
  /// 콘텐츠 4종은 홈이 실 IO 를 타지 않게 함께 override 한다.
  Widget gate(FakeAuthService? auth) {
    return ProviderScope(
      overrides: [
        if (auth != null) authServiceProvider.overrideWithValue(auth),
        teamsProvider.overrideWith(
          (ref) async => const ContentUnavailable<TeamsDocument>(_issue),
        ),
        stadiumsProvider.overrideWith(
          (ref) async => const ContentUnavailable<StadiumsDocument>(_issue),
        ),
        placesProvider.overrideWith(
          (ref) async => const ContentUnavailable<PlacesDocument>(_issue),
        ),
        scheduleProvider.overrideWith(
          (ref) async => const ContentUnavailable<ScheduleDocument>(_issue),
        ),
      ],
      child: const MaterialApp(home: RootGate()),
    );
  }

  FakeAuthService fakeAuth({AuthUser? signedIn}) {
    final auth = FakeAuthService(signedIn: signedIn);
    addTearDown(auth.dispose);
    return auth;
  }

  testWidgets('로그인하지 않았으면 로그인 화면에서 멈춘다', (tester) async {
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
    await tester.pumpWidget(gate(fakeAuth()));
    await tester.pumpAndSettle();

    // 팀이 저장돼 있어도 계정이 없으면 홈으로 가지 않는다.
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(TeamSelectScreen), findsNothing);
    // 세 제공자 버튼이 모두 서 있다.
    expect(find.byType(SocialSignInButton), findsNWidgets(3));
    for (final provider in AuthProviderId.values) {
      expect(find.text(SocialSignInButton.labelOf(provider)), findsOneWidget);
    }
  });

  testWidgets('로그인했고 팀이 없으면 온보딩으로 간다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(gate(fakeAuth(signedIn: _signedInUser)));
    await tester.pumpAndSettle();

    expect(find.byType(TeamSelectScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('로그인했고 팀이 있으면 홈으로 간다', (tester) async {
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
    await tester.pumpWidget(gate(fakeAuth(signedIn: _signedInUser)));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('로그아웃하면 로그인 화면으로 돌아온다', (tester) async {
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
    final auth = fakeAuth(signedIn: _signedInUser);
    await tester.pumpWidget(gate(auth));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await auth.signOut();
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('제공자 버튼을 누르면 그 제공자로 로그인하고 게이트가 넘어간다', (tester) async {
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
    final auth = fakeAuth();
    await tester.pumpWidget(gate(auth));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(SocialSignInButton.labelOf(AuthProviderId.kakao)),
    );
    await tester.pumpAndSettle();

    expect(auth.signInCalls, [AuthProviderId.kakao]);
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('로그인이 실패하면 안내가 뜨고 로그인 화면에 머무른다', (tester) async {
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
    final auth = fakeAuth();
    auth.failure = Exception('제공자가 거절했다');
    await tester.pumpWidget(gate(auth));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(SocialSignInButton.labelOf(AuthProviderId.google)),
    );
    await tester.pumpAndSettle();

    expect(auth.signInCalls, [AuthProviderId.google]);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(SignInNotice), findsOneWidget);
  });

  testWidgets('인증 스트림이 오류로 끝나면 안내와 함께 로그인 화면으로 내린다', (tester) async {
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
    final auth = fakeAuth(signedIn: _signedInUser);
    await tester.pumpWidget(gate(auth));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    auth.emitError(StateError('세션 스트림이 끊겼다'));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(SignInNotice), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    // 그 자리에서 다시 로그인하면 들어간다 — 실패가 막다른 골목이 아니다.
    await tester.tap(
      find.text(SocialSignInButton.labelOf(AuthProviderId.google)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('세션 스트림이 오류와 함께 끝나도 다시 로그인하면 들어간다', (tester) async {
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
    final auth = fakeAuth(signedIn: _signedInUser);
    await tester.pumpWidget(gate(auth));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    // 위 케이스와 다른 점은 스트림이 오류를 내고 **끝난다**는 것뿐이다.
    // 그 한 가지로 세션 상태를 다시 세울 경로가 없으면 앱을 다시 켜는 것
    // 말고는 빠져나올 길이 없어진다.
    await auth.dropSession();
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(SignInNotice), findsOneWidget);

    await tester.tap(
      find.text(SocialSignInButton.labelOf(AuthProviderId.google)),
    );
    await tester.pumpAndSettle();

    expect(auth.signInCalls, [AuthProviderId.google]);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('진행 중인 로그인이 있으면 다른 제공자 탭은 무시된다', (tester) async {
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
    final auth = fakeAuth();
    await tester.pumpWidget(gate(auth));
    await tester.pumpAndSettle();

    // 프레임 사이 rebuild 없이 두 번 — 실기기의 두 손가락 동시 탭에 해당한다.
    await tester.tap(
      find.text(SocialSignInButton.labelOf(AuthProviderId.google)),
    );
    await tester.tap(
      find.text(SocialSignInButton.labelOf(AuthProviderId.apple)),
    );
    await tester.pumpAndSettle();

    expect(auth.signInCalls, [AuthProviderId.google]);
  });

  testWidgets('인증 서비스 주입이 없으면 로그인 화면 + 안내로 드러난다', (tester) async {
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
    await tester.pumpWidget(gate(null));
    await tester.pumpAndSettle();

    // 조용히 "로그아웃한 사람"이 되지 않는다 — 안내가 함께 뜬다.
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(SignInNotice), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
