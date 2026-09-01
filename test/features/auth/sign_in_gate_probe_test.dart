/// Step 2.1 적대적 탐침 — 계약이 적지 않은 자리를 친다.
///
/// 1) 게이트가 화면을 바꾼 *뒤* 남는 상태: 루트 Navigator 에 밀어 올린 화면이
///    로그아웃·세션 오류 뒤에도 위에 남아 계정 없이 쓰이는지.
/// 2) 같은 프레임의 중복 입력: "진행 중이면 셋 다 잠근다"는 결정이 build
///    재실행에만 기대고 있는지.
/// 3) 주입을 빼면 정말 드러나는지 (기존 테스트의 인증 주입이 전제 명시인지).
///
/// `pumpAndSettle` 대신 정해진 횟수의 `pump` 를 쓴다 — 화면 스택이 뒤엉킨
/// 상태에서 settle 이 끝나지 않아 뒤 케이스까지 바인딩 오류로 무너진다.
/// 또 판정은 위젯 트리를 걷어낸 **뒤** 한다 — 라우트가 살아 있는 채로 실패를
/// 던지면 러너가 정리 단계에서 멈춘다.
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

/// 정해진 횟수만 돌리는 settle 대용 — 영원히 안 끝나는 프레임에 걸리지 않는다.
Future<void> _turn(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// 세션이 끊긴 순간 사용자가 실제로 보는 것.
typedef _Seen = ({int signInVisible, int signInAnywhere, int pushedVisible});

_Seen _look() => (
  signInVisible: find.byType(SignInScreen).hitTestable().evaluate().length,
  signInAnywhere: find
      .byType(SignInScreen, skipOffstage: false)
      .evaluate()
      .length,
  pushedVisible: find.byType(TeamSelectScreen).hitTestable().evaluate().length,
);

void main() {
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

  /// 홈까지 간 다음, 홈 앱바의 "응원 팀 바꾸기"로 루트 Navigator 에 화면 하나를
  /// 밀어 올린다 — 사용자가 앱에서 실제로 할 수 있는 조작 그대로다.
  Future<void> pushOneScreen(WidgetTester tester) async {
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await _turn(tester);
    expect(
      find.byType(TeamSelectScreen).hitTestable(),
      findsOneWidget,
      reason: '탐침 전제: 밀어 올린 화면이 실제로 위에 서 있어야 한다',
    );
  }

  group('탐침 A — 게이트가 화면을 바꾼 뒤에 남는 상태', () {
    testWidgets('로그아웃하면 밀어 올린 화면도 함께 내려간다', (tester) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      final auth = fakeAuth(signedIn: _user);
      await tester.pumpWidget(gate(auth));
      await _turn(tester);
      await pushOneScreen(tester);

      await auth.signOut();
      await _turn(tester);
      final seen = _look();

      // 판정 전에 트리를 걷어낸다 (위 doc 참조).
      await tester.pumpWidget(const SizedBox.shrink());
      await _turn(tester, 3);

      expect(
        seen.pushedVisible,
        0,
        reason: '로그아웃했는데 로그인 뒤 화면이 위에 남아 조작 가능하다 ($seen)',
      );
      expect(
        seen.signInVisible,
        1,
        reason: '로그아웃 뒤 사용자가 실제로 보는 화면이 로그인 화면이어야 한다 ($seen)',
      );
    });

    testWidgets('세션이 끊기면 밀어 올린 화면도 함께 내려간다', (tester) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      final auth = fakeAuth(signedIn: _user);
      await tester.pumpWidget(gate(auth));
      await _turn(tester);
      await pushOneScreen(tester);

      auth.emitError(StateError('세션 스트림이 끊겼다'));
      await _turn(tester);
      final seen = _look();
      final noticeVisible = find
          .byType(SignInNotice)
          .hitTestable()
          .evaluate()
          .length;

      await tester.pumpWidget(const SizedBox.shrink());
      await _turn(tester, 3);

      expect(seen.pushedVisible, 0, reason: '세션이 끊겼는데 앞 화면이 그대로다 ($seen)');
      expect(noticeVisible, 1, reason: '세션이 끊겼다는 안내가 실제로 보여야 한다 ($seen)');
    });
  });

  group('탐침 B — 같은 프레임의 중복 입력', () {
    testWidgets('같은 프레임에 두 제공자를 누르면 한 번만 로그인한다', (tester) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      final auth = fakeAuth();
      await tester.pumpWidget(gate(auth));
      await _turn(tester);

      // 프레임 사이 rebuild 없이 두 번 — 실기기에서 두 손가락 동시 탭에 해당.
      await tester.tap(
        find.text(SocialSignInButton.labelOf(AuthProviderId.google)),
      );
      await tester.tap(
        find.text(SocialSignInButton.labelOf(AuthProviderId.apple)),
      );
      await _turn(tester);
      final calls = [...auth.signInCalls];

      await tester.pumpWidget(const SizedBox.shrink());
      await _turn(tester, 3);

      expect(
        calls,
        [AuthProviderId.google],
        reason: '진행 중이면 셋 다 잠근다는 결정대로면 두 번째 탭은 무시돼야 한다',
      );
    });
  });

  group('탐침 D — 세션 스트림이 오류로 끝나 버린 경우', () {
    testWidgets('스트림이 닫힌 뒤 다시 로그인하면 앱으로 들어간다', (tester) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      final auth = _SessionDropsAuth(_user);
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
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
        ),
      );
      await _turn(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      // 실 SDK 의 스트림은 실패하면서 함께 끝나는 경우가 흔하다
      // (Firestore 스냅샷 스트림의 권한 상실이 그렇다).
      auth.dropSession();
      await _turn(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(SignInNotice), findsOneWidget);

      // 안내가 시킨 대로 "다시 로그인" 한다.
      await tester.tap(
        find.text(SocialSignInButton.labelOf(AuthProviderId.google)),
      );
      await _turn(tester);
      final home = find.byType(HomeScreen).evaluate().length;
      final stillSignIn = find.byType(SignInScreen).evaluate().length;

      await tester.pumpWidget(const SizedBox.shrink());
      await _turn(tester, 3);

      expect(auth.signInCalls, 1, reason: '로그인 자체는 성공해야 한다');
      expect(
        home,
        1,
        reason: '다시 로그인했는데 로그인 화면에 갇혀 있다 '
            '(signIn 성공 = ${auth.signInCalls}, 로그인 화면 = $stillSignIn)',
      );
    });
  });

  group('탐침 C — 전제 주입이 실제로 하중을 받는가', () {
    testWidgets('인증 주입을 빼면 앱 전체 경로가 로그인 화면에서 멈춘다', (tester) async {
      SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lg'});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
          child: const KboAwayFansApp(),
        ),
      );
      // 스플래시 연출을 지나 게이트까지 간다.
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(SignInNotice), findsOneWidget);
    });
  });
}

/// 세션 스트림이 **오류와 함께 끝나는** 인증 서비스 — 실 SDK 에서 흔한 모양.
///
/// `FakeAuthService` 는 broadcast 컨트롤러를 열어 둔 채 오류만 흘리므로
/// "오류 뒤에도 같은 구독으로 값이 더 온다"를 전제한다. 그 전제를 뺀 자리가
/// 어떻게 되는지 재려고 둔 대역이다.
class _SessionDropsAuth implements AuthService {
  _SessionDropsAuth(this._current);

  AuthUser? _current;
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  /// signIn 호출 횟수.
  int signInCalls = 0;

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  /// 세션이 끊기며 스트림도 함께 끝난다.
  void dropSession() {
    _current = null;
    _controller.addError(StateError('세션 스트림이 끊겼다'));
    _controller.close();
  }

  @override
  Future<AuthUser> signIn(AuthProviderId provider) async {
    signInCalls++;
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
