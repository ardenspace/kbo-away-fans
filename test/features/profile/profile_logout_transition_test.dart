/// Step 3.4 boundary test — 마이페이지의 로그아웃 진입점이 실제로 게이트를
/// 지나 로그인 화면으로 되돌리고, 다시 로그인하면 홈까지 들어가는 전이.
///
/// 계약 2항의 두 재로그인 확인 중 **시험으로 잴 수 있는 하나**를 여기서
/// 잰다: "로그아웃 후 다시 로그인하면 홈까지 들어간다"(`SignInScreen`
/// 의 `sessionMissingMessage` 에 걸리지 않고 끝까지 간다). 구글 계정 선택
/// 화면이 다시 뜨는지는 `GoogleSignIn.instance.signOut()` 이 실제로 도는
/// 실기기 자리라 이 시험 밖이다 — `lib/backend/auth_firebase.dart` 의
/// `FirebaseAuthService.signOut` 이 그 호출을 이미 하고 있다는 사실만
/// 소스로 확인했다(사람 몫 체크리스트로 옮긴다).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/auth/sign_in_screen.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/features/profile/profile_tab_screen.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/ui/shared/social_sign_in_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';
import '../../location/fake_location_permission_gateway.dart';

const ContentIssue _issue = ContentIssue(ContentIssueKind.network, 'fixture');
final AuthUser _signedInUser = AuthUser(
  uid: fakeUidOf(AuthProviderId.google),
  displayName: '원정러',
  email: 'fan@example.com',
);

void main() {
  late FakeUserDataStore store;

  setUp(() {
    store = FakeUserDataStore();
  });

  tearDown(() async {
    await store.dispose();
  });

  Widget gate(AuthService auth) {
    return ProviderScope(
      overrides: [
        // 홈 상단 위치 자리(5.2)가 판정이 없는 실행에서 권한을 한 번 묻는다 —
        // 대역이 없으면 실 플랫폼 채널이 물려 위젯 트리 해제 뒤까지 타이머가
        // 남는다(`lib/features/home/current_location.dart` docstring 참조).
        locationPermissionGatewayProvider.overrideWithValue(
          FakeLocationPermissionGateway(),
        ),
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
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

  testWidgets('마이페이지에서 로그아웃하면 로그인 화면으로 돌아오고, 다시 로그인하면 홈까지 들어간다', (
    tester,
  ) async {
    // 캐시는 계정에 매여 있다 — `selectedTeamIdProvider` 가 그 캐시를 읽으려면
    // 목(mock) 값이 있어야 한다(다른 gate 시험들과 같은 준비).
    SharedPreferences.setMockInitialValues({});
    // 이 계정은 이미 온보딩을 마쳤다 — 문서가 서버에 미리 있다.
    await store.createProfile(
      _signedInUser.uid,
      const NewUserProfile(nickname: '원정러', favoriteTeamId: 'lg'),
    );
    final auth = FakeAuthService(signedIn: _signedInUser);
    addTearDown(auth.dispose);

    await tester.pumpWidget(gate(auth));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(MainTabsRoot), findsOneWidget);

    // 마이페이지 탭으로 이동한다.
    await tester.tap(find.text('마이페이지'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileTabScreen), findsOneWidget);

    // 로그아웃 버튼을 누른다.
    await tester.tap(find.byKey(const ValueKey('profile-sign-out')));
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(MainTabsRoot), findsNothing);
    expect(find.byType(HomeScreen), findsNothing);

    // 다시 같은 제공자로 로그인한다 — 세션이 세워지지 못한 실행이라면
    // `SignInScreen.sessionMissingMessage` 가 뜨고 로그인 화면에 머무른다.
    await tester.tap(
      find.text(SocialSignInButton.labelOf(AuthProviderId.google)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(SignInScreen.sessionMissingMessage),
      findsNothing,
      reason: '세션을 세우지 못했다면 이 안내가 뜬 채 로그인 화면에 머무른다',
    );
    expect(find.byType(SignInScreen), findsNothing);
    expect(
      find.byType(HomeScreen),
      findsOneWidget,
      reason: '재로그인은 홈까지 들어가야 한다',
    );
  });
}
