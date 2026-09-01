/// Step 2.1 적대적 탐침 (검증자) — 이미 트리에 있는 탐침이 치지 않은 자리.
///
/// 여기 있는 케이스는 `sign_in_gate_probe_test.dart` 와 겹치지 않는다:
/// 1) 앱 전체 경로(스플래시 → 게이트)에서 계정 없이 쓰는 경로가 없는가.
/// 2) route 로 뜨는 것들(바텀시트) 이 되감기에 함께 내려가는가.
/// 3) 되감기가 **반대 방향으로 과하게** 작동하지 않는가 — 전이가 아닌
///    단순 refresh 에 반응해 로그인한 사람의 화면 스택을 되감지는 않는가.
/// 4) 잠기고 풀리는 상태 — 끝나지 않는 로그인, 성공했는데 세션이 안 서는 경우.
///
/// `pumpAndSettle` 대신 정해진 횟수의 `pump` 를 쓴다.
library;

import 'dart:async';

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

const AuthUser _user = AuthUser(uid: 'uid-1', displayName: '원정러');
const ContentIssue _issue = ContentIssue(ContentIssueKind.network, 'fixture');

Future<void> _turn(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _scoped(AuthService? auth, Widget child) => ProviderScope(
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
  child: child,
);

void main() {
  Widget gate(AuthService? auth) =>
      _scoped(auth, const MaterialApp(home: RootGate()));

  Widget wholeApp(AuthService? auth) =>
      _scoped(auth, const KboAwayFansApp());

  FakeAuthService fakeAuth({AuthUser? signedIn}) {
    final auth = FakeAuthService(signedIn: signedIn);
    addTearDown(auth.dispose);
    return auth;
  }

  /// 홈 앱바의 "응원 팀 바꾸기"로 루트 Navigator 에 화면 하나를 올린다.
  Future<void> pushOneScreen(WidgetTester tester) async {
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await _turn(tester);
    expect(find.byType(TeamSelectScreen).hitTestable(), findsOneWidget);
  }

  group('탐침 1 — 앱 전체 경로에서 계정 없이 쓰는 경로', () {
    testWidgets('주입은 있으나 로그아웃 상태면 스플래시를 지나도 로그인 화면에서 멈춘다', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      await tester.pumpWidget(wholeApp(fakeAuth()));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(TeamSelectScreen), findsNothing);
      // 평범한 첫 진입이라 실패 안내는 없다 (주입 없는 실행과 구분된다).
      expect(find.byType(SignInNotice), findsNothing);
    });
  });

  group('탐침 2 — route 로 뜨는 것들이 되감기에 함께 내려가는가', () {
    testWidgets('바텀시트가 떠 있을 때 로그아웃하면 시트도 내려간다', (tester) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      final auth = fakeAuth(signedIn: _user);
      await tester.pumpWidget(gate(auth));
      await _turn(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      // 앱이 실제로 쓰는 방식 그대로 (PlaceDetailSheet 와 같은 호출).
      final homeContext = tester.element(find.byType(HomeScreen));
      unawaited(
        showModalBottomSheet<void>(
          context: homeContext,
          builder: (_) => const SizedBox(
            height: 200,
            child: Center(child: Text('시트 내용')),
          ),
        ),
      );
      await _turn(tester);
      expect(find.text('시트 내용').hitTestable(), findsOneWidget);

      await auth.signOut();
      await _turn(tester);
      final sheetLeft = find.text('시트 내용').evaluate().length;
      final signInVisible = find
          .byType(SignInScreen)
          .hitTestable()
          .evaluate()
          .length;

      await tester.pumpWidget(const SizedBox.shrink());
      await _turn(tester, 3);

      expect(sheetLeft, 0, reason: '로그아웃했는데 바텀시트가 위에 남아 조작 가능하다');
      expect(signInVisible, 1, reason: '로그아웃 뒤 보이는 화면이 로그인 화면이어야 한다');
    });
  });

  group('탐침 2b — 되감기가 앱 전체 실행에서도 서는가', () {
    testWidgets('스플래시를 지난 실제 앱에서도 로그아웃이 밀어 올린 화면을 내린다', (tester) async {
      // 트리에 이미 있는 탐침은 `MaterialApp(home: RootGate())` 만 띄운다.
      // 실제 앱은 게이트가 SplashGate 의 AnimatedSwitcher 안에 들어 있어
      // route 구조가 다르므로 같은 보호가 서는지 따로 잰다.
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      final auth = fakeAuth(signedIn: _user);
      await tester.pumpWidget(wholeApp(auth));
      await tester.pumpAndSettle();
      await pushOneScreen(tester);

      await auth.signOut();
      await _turn(tester);
      final pushedLeft = find
          .byType(TeamSelectScreen)
          .hitTestable()
          .evaluate()
          .length;
      final signInVisible = find
          .byType(SignInScreen)
          .hitTestable()
          .evaluate()
          .length;

      await tester.pumpWidget(const SizedBox.shrink());
      await _turn(tester, 3);

      expect(pushedLeft, 0, reason: '앱 전체 실행에서는 되감기가 서지 않는다');
      expect(signInVisible, 1);
    });
  });

  group('탐침 2c — 되감긴 뒤 다시 로그인하면 제자리로 돌아오는가', () {
    testWidgets('화면을 밀어 올린 채 세션이 끊기고 다시 로그인하면 홈 하나만 남는다', (tester) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      final auth = fakeAuth(signedIn: _user);
      await tester.pumpWidget(gate(auth));
      await _turn(tester);
      await pushOneScreen(tester);

      auth.emitError(StateError('세션 스트림이 끊겼다'));
      await _turn(tester);
      await tester.tap(
        find.text(SocialSignInButton.labelOf(AuthProviderId.google)),
      );
      await _turn(tester);

      final home = find.byType(HomeScreen).hitTestable().evaluate().length;
      final orphan = find
          .byType(TeamSelectScreen, skipOffstage: false)
          .evaluate()
          .length;
      final signIn = find
          .byType(SignInScreen, skipOffstage: false)
          .evaluate()
          .length;

      await tester.pumpWidget(const SizedBox.shrink());
      await _turn(tester, 3);

      expect(home, 1, reason: '다시 로그인했는데 홈이 보이지 않는다');
      expect(orphan, 0, reason: '되감긴 화면이 스택에 남아 있다');
      expect(signIn, 0, reason: '로그인 화면이 트리에 남아 있다');
    });
  });

  group('탐침 3 — 되감기가 반대 방향으로 과한가', () {
    testWidgets('로그인한 채 authStateProvider 를 다시 세우면 밀어 올린 화면이 살아남는가', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      final auth = fakeAuth(signedIn: _user);
      await tester.pumpWidget(gate(auth));
      await _turn(tester);
      await pushOneScreen(tester);

      // 로그인 화면이 성공 뒤에 하는 그 호출을, 이번엔 로그인한 상태에서.
      // (2.2 가 토큰 갱신·재인증 자리에서 같은 호출을 쓸 자리다.)
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.invalidate(authStateProvider);
      await _turn(tester);

      final pushedLeft = find
          .byType(TeamSelectScreen)
          .hitTestable()
          .evaluate()
          .length;
      final signInVisible = find
          .byType(SignInScreen)
          .hitTestable()
          .evaluate()
          .length;

      await tester.pumpWidget(const SizedBox.shrink());
      await _turn(tester, 3);

      expect(
        signInVisible,
        0,
        reason: '로그아웃한 적이 없는데 로그인 화면이 떴다 — 단순 refresh 를 세션 상실로 읽었다',
      );
      expect(
        pushedLeft,
        1,
        reason: '로그인한 사람의 정상적인 화면 스택이 refresh 한 번에 되감겼다',
      );
    });

    testWidgets('세션이 잠깐 끊겼다 같은 프레임에 같은 계정으로 돌아오면 화면 스택이 남는가', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      final auth = _FlickerAuth(_user);
      addTearDown(auth.dispose);
      await tester.pumpWidget(gate(auth));
      await _turn(tester);
      await pushOneScreen(tester);

      // null 이 한 번 흐르고 곧바로 **같은 계정**이 돌아온다 (토큰 갱신 중의
      // 순간적인 null — 프레임 하나 안에서 끝나 사용자는 눈치채지 못한다).
      auth.flicker();
      await _turn(tester);

      final pushedLeft = find
          .byType(TeamSelectScreen)
          .hitTestable()
          .evaluate()
          .length;
      // 홈은 `skipOffstage: false` 로 센다. 밀어 올린 화면이 살아남으면 그
      // 아래의 홈은 오버레이에서 offstage 가 되므로(불투명 route 아래는 아예
      // 그려지지 않는다) 기본 finder 로는 0 이고, 그러면 "화면 스택이 남았다"
      // (pushedLeft == 1)와 "홈이 보인다"가 동시에 참일 수 없다. 재는 대상은
      // 홈이 화면에 떠 있는가가 아니라 게이트가 여전히 로그인한 사람의
      // 갈래에 있는가라서, 로그인 화면이 되돌아오지 않았다는 것으로 함께
      // 못 박는다 (앞 케이스가 `signInVisible` 로 재는 것과 같은 방식).
      final home = find
          .byType(HomeScreen, skipOffstage: false)
          .evaluate()
          .length;
      final signInBack = find
          .byType(SignInScreen, skipOffstage: false)
          .evaluate()
          .length;

      await tester.pumpWidget(const SizedBox.shrink());
      await _turn(tester, 3);

      expect(
        signInBack,
        0,
        reason: '세션이 돌아왔는데 로그인 화면에 남았다',
      );
      expect(
        home,
        greaterThan(0),
        reason: '세션이 돌아왔는데 홈이 트리에서 사라졌다',
      );
      expect(
        pushedLeft,
        1,
        reason: '세션이 돌아왔는데 화면 스택이 되감겼다 (pushed=$pushedLeft)',
      );
    });
  });

  group('탐침 4 — 잠기고 풀리는 상태', () {
    testWidgets('끝나지 않는 로그인은 진행 중 표시도 없고 푸는 방법도 없다', (tester) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      final auth = _HangingAuth();
      addTearDown(auth.dispose);
      await tester.pumpWidget(gate(auth));
      await _turn(tester);

      await tester.tap(
        find.text(SocialSignInButton.labelOf(AuthProviderId.google)),
      );
      await _turn(tester);

      // 사용자가 지금 보는 것: 버튼 셋이 회색이고, 그 밖에 아무 신호도 없다.
      final spinners = find
          .byType(CircularProgressIndicator)
          .evaluate()
          .length;
      final notices = find.byType(SignInNotice).evaluate().length;
      final enabled = tester
          .widgetList<SocialSignInButton>(find.byType(SocialSignInButton))
          .where((button) => button.onPressed != null)
          .length;

      // 한참 지나도 그대로인가 (실기기에서 제공자 시트를 열어 둔 채 방치).
      await _turn(tester, 200);
      final enabledLater = tester
          .widgetList<SocialSignInButton>(find.byType(SocialSignInButton))
          .where((button) => button.onPressed != null)
          .length;

      await tester.pumpWidget(const SizedBox.shrink());
      await _turn(tester, 3);

      expect(enabled, 0, reason: '진행 중에는 셋 다 잠긴다는 결정');
      expect(enabledLater, 0);
      expect(
        spinners + notices,
        greaterThan(0),
        reason: '로그인이 진행 중이라는 신호가 화면에 하나도 없다 '
            '(스피너 $spinners, 안내 $notices) — 버튼 셋이 회색인 것이 전부다',
      );
    });

    testWidgets('signIn 은 성공했는데 세션이 서지 않으면 다시 시도할 방법이 없다', (tester) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      final auth = _SignInWithoutSession();
      addTearDown(auth.dispose);
      await tester.pumpWidget(gate(auth));
      await _turn(tester);

      await tester.tap(
        find.text(SocialSignInButton.labelOf(AuthProviderId.google)),
      );
      await _turn(tester);

      final enabled = tester
          .widgetList<SocialSignInButton>(find.byType(SocialSignInButton))
          .where((button) => button.onPressed != null)
          .length;
      final stillSignIn = find.byType(SignInScreen).evaluate().length;

      await tester.pumpWidget(const SizedBox.shrink());
      await _turn(tester, 3);

      expect(stillSignIn, 1, reason: '탐침 전제: 게이트가 로그인 화면을 걷어가지 않았다');
      expect(
        enabled,
        greaterThan(0),
        reason: '게이트가 화면을 걷어가지 않았는데 버튼 셋이 영구히 잠겼다 — '
            '앱을 다시 켜는 것 말고 나갈 길이 없다',
      );
    });
  });
}

/// 세션이 한 프레임 안에서 null 로 깜빡였다가 **같은 계정**으로 돌아오는 서비스.
class _FlickerAuth implements AuthService {
  _FlickerAuth(this._current);

  AuthUser? _current;
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => _current;

  /// 구독하는 순간 지금 아는 상태를 흘린다 — `AuthService.authStateChanges` 의
  /// 계약이다 (이 대역은 복원 대기 구간이 없다).
  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  /// null 한 번, 곧바로 같은 계정 한 번.
  void flicker() {
    _controller.add(null);
    _current = _current;
    _controller.add(_current);
  }

  @override
  Future<AuthUser> signIn(AuthProviderId provider) async {
    final user = AuthUser(uid: '${provider.name}-uid');
    _current = user;
    if (!_controller.isClosed) _controller.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    if (!_controller.isClosed) _controller.add(null);
  }

  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

/// signIn 이 끝나지 않는 서비스 — 제공자 시트를 열어 둔 채 방치한 실기기.
class _HangingAuth implements AuthService {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  final Completer<AuthUser> _never = Completer<AuthUser>();

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield null;
    yield* _controller.stream;
  }

  @override
  Future<AuthUser> signIn(AuthProviderId provider) => _never.future;

  @override
  Future<void> signOut() async {}

  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

/// signIn 은 성공을 돌려주지만 세션은 서지 않는 서비스 — 커스텀 토큰 교환이
/// 성공한 뒤 Firebase 세션 수립이 조용히 실패하는 자리(2.3)에 해당한다.
class _SignInWithoutSession implements AuthService {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield null;
    yield* _controller.stream;
  }

  @override
  Future<AuthUser> signIn(AuthProviderId provider) async =>
      AuthUser(uid: '${provider.name}-uid');

  @override
  Future<void> signOut() async {}

  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }
}
