/// 계약 2항의 뒷문장을 **한 경로로** 잰다: 함수 호출이 실패하면 로그인 화면이
/// 이유를 안내하고 앱이 죽지 않는다.
///
/// 지금 그 문장은 두 조각으로 나뉘어 검증돼 있다.
///
///  - `test/backend/kakao_sign_in_test.dart` — callable 실패가 도메인 오류가
///    되는 자리까지.
///  - `test/features/auth/sign_in_gate_test.dart` — 손으로 쓴 `FakeAuthService`
///    가 던진 `Exception` 이 화면의 안내가 되는 자리부터.
///
/// 둘 사이의 이음매 — **실 `FirebaseAuthService` 가 카카오 갈래에서 던진 것이
/// 그 화면의 그 문구가 되는가** — 는 어느 쪽도 지나지 않는다. 그 자리에서
/// 갈라질 수 있는 것이 있다: 실 구현의 실패는 `guardBackend` 를 지나 도메인이
/// 이미 정해져 나오는데, 화면의 `_messageOf` 는 도메인 **셋**만 알고 코드는
/// 모른다. 도메인이 하나라도 어긋나면 사람이 읽는 문구가 사실과 달라지고
/// (예: 재시도로 풀리는 실패에 "다시 시도해도 같다"는 뜻의 문구), 그 어긋남은
/// 두 조각 어디에도 나타나지 않는다.
///
/// 그래서 여기서는 플랫폼 대역만 갈아 끼우고 **실 구현을 게이트에 꽂아** 카카오
/// 버튼을 실제로 누른다.
library;

import 'dart:async';

import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/auth_firebase.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/auth/sign_in_screen.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/team_select/selected_team.dart';
import 'package:kbo_away_fans/ui/shared/social_sign_in_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';

const ContentIssue _issue = ContentIssue(ContentIssueKind.network, 'fixture');

class _FakeApp extends FirebaseAppPlatform {
  _FakeApp()
    : super(
        defaultFirebaseAppName,
        const FirebaseOptions(
          apiKey: 'fake',
          appId: 'fake',
          messagingSenderId: 'fake',
          projectId: 'fake',
        ),
      );
}

class _FakeCore extends FirebasePlatform {
  final FirebaseAppPlatform _app = _FakeApp();

  @override
  List<FirebaseAppPlatform> get apps => <FirebaseAppPlatform>[_app];

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async => _app;

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) => _app;
}

/// 카카오 경로가 교환 직전에 켜는 App Check — 이 파일은 그 자리를 재지 않으므로
/// 조용히 성공하는 대역으로 둔다(실 채널을 타면 위젯 테스트가 멈춘다).
class _NoopAppCheck extends FirebaseAppCheckPlatform {
  _NoopAppCheck() : super();

  @override
  FirebaseAppCheckPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAppCheckPlatform setInitialValues() => this;

  @override
  Future<void> activate({
    WebProvider? webProvider,
    // ignore: deprecated_member_use
    AndroidProvider? androidProvider,
    // ignore: deprecated_member_use
    AppleProvider? appleProvider,
    AndroidAppCheckProvider? providerAndroid,
    AppleAppCheckProvider? providerApple,
    WindowsAppCheckProvider? providerWindows,
  }) async {}
}

/// 로그아웃 상태로 서 있는 최소 플랫폼 — 이 파일이 재는 것은 실패 갈래뿐이다.
class _SignedOutAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutAuthPlatform() : super();

  final StreamController<UserPlatform?> native =
      StreamController<UserPlatform?>.broadcast();

  @override
  UserPlatform? get currentUser => null;

  @override
  set currentUser(UserPlatform? user) {}

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  Stream<UserPlatform?> authStateChanges() async* {
    yield null;
    yield* native.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final kakao = FakeKakaoAuthGateway();

  setUpAll(() async {
    FirebasePlatform.instance = _FakeCore();
    FirebaseAppCheckPlatform.instance = _NoopAppCheck();
    FirebaseAuthPlatform.instance = _SignedOutAuthPlatform();
    await FirebaseAuthService.ensureInitialized(kakaoGateway: kakao);
  });

  Widget gate() => ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(FirebaseAuthService.instance),
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

  Future<void> tapKakao(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{kSelectedTeamPrefsKey: 'lg'},
    );
    await tester.pumpWidget(gate());
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(SocialSignInButton.labelOf(AuthProviderId.kakao)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('함수가 닿지 않으면 다시 시도하라고 안내하고 화면은 살아 있다', (tester) async {
    kakao
      ..loginFailure = null
      ..exchangeFailure = FirebaseException(
        plugin: 'cloud_functions',
        code: 'unavailable',
      );

    await tapKakao(tester);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(
      find.text('연결이 불안정해요. 잠시 뒤 다시 시도해 주세요.'),
      findsOneWidget,
      reason:
          '함수에 닿지 못한 것은 다시 시도하면 풀리는 갈래다 — 여기서 다른 문구가 뜨면 '
          '사람이 읽는 안내가 사실과 다르다',
    );
    // 버튼이 다시 눌리는 상태로 남아야 한다 — 실패가 막다른 골목이면 앱을
    // 다시 켜는 것 말고 나갈 길이 없어진다.
    expect(
      tester
          .widget<SocialSignInButton>(
            find.widgetWithText(
              SocialSignInButton,
              SocialSignInButton.labelOf(AuthProviderId.kakao),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('App Check·카카오 토큰이 거절되면(unauthenticated) 로그인 미완료로 안내한다', (
    tester,
  ) async {
    // 배포된 함수가 App Check 토큰 없는 호출을 거절하는 코드가 바로 이것이다
    // (`functions/index.js` 의 `enforceAppCheck: true`). 디버그 토큰을 등록하지
    // 않은 기기에서 사람이 실제로 보게 되는 문구가 여기서 정해진다.
    kakao.exchangeFailure = FirebaseException(
      plugin: 'cloud_functions',
      code: 'unauthenticated',
    );

    await tapKakao(tester);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(
      find.text('로그인이 완료되지 않았어요. 다시 시도해 주세요.'),
      findsOneWidget,
    );
  });

  testWidgets('카카오 화면을 스스로 닫아도 앱은 그대로 서 있다', (tester) async {
    kakao
      ..exchangeFailure = null
      ..loginFailure = const BackendPermissionError(code: kSignInCanceledCode);

    await tapKakao(tester);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(SignInNotice), findsOneWidget);
  });
}
