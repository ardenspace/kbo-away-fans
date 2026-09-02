/// 카카오 로그인 경로가 **App Check 활성화를 무한정 기다리지 않는가**.
///
/// `_signInWithKakao` 는 교환 직전에 `BackendAppCheck.ensureInitialized()` 를
/// 부른다(첫 시도가 실패한 실행에서 다시 켤 자리가 거기뿐이다). 그 재시도는
/// 옳지만, `app_check.dart` 의 try/catch 는 **오류**만 삼키고 **지연**은 삼키지
/// 못한다 — 플랫폼 채널이 답하지 않는 실행에서 그 await 는 끝나지 않는다.
///
/// 그동안 로그인 화면은 `_pending != null` 이라 세 버튼이 전부 잠기고 스피너만
/// 돈다. 안내도 뜨지 않고 빠져나갈 길은 앱을 다시 켜는 것뿐이라, 2.1 이 [M] 으로
/// 고쳤던 "성공했는데 세션이 안 서면 잠금을 푸는 자리가 없다"와 같은 모양이다.
///
/// 그래서 여기서는 `activate` 가 **영영 끝나지 않는** 대역을 끼우고, 그 실행에서
/// 로그인 화면이 되살아나는지를 잰다. 기다림에 상한이 없으면 이 파일은 통과할
/// 수 없다 — 아무리 시간을 밀어도 화면이 잠긴 채 남는다.
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

/// 상한이 있다면 그 안에는 들어야 하는 시간 — 이 파일은 상한의 **값**이 아니라
/// 상한이 **있다**는 사실을 잰다. 여기서 미는 시간을 넘기는 상한은 사람이 앱이
/// 죽었다고 판단하고도 남는 길이라, 그때는 이 케이스가 실패하는 것이 옳다.
const Duration _generousBound = Duration(seconds: 10);

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

/// **영영 끝나지 않는** 활성화 — 플랫폼 채널이 답하지 않는 실행의 대역이다.
/// (실기기에서 이 모양을 만드는 것은 App Check 초기화가 네트워크·Play 서비스
/// 응답을 기다리며 멈춘 경우다. 오류가 아니라 침묵이라 try/catch 가 닿지 않는다.)
class _StalledAppCheck extends FirebaseAppCheckPlatform {
  _StalledAppCheck() : super();

  static int activateCalls = 0;

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
  }) {
    activateCalls++;
    return Completer<void>().future;
  }
}

/// 로그아웃 상태로 서 있는 최소 인증 플랫폼 — 이 파일이 재는 것은 잠금뿐이다.
class _SignedOutAuthPlatform extends FirebaseAuthPlatform {
  _SignedOutAuthPlatform() : super();

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
    yield* const Stream<UserPlatform?>.empty();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final kakao = FakeKakaoAuthGateway();

  setUpAll(() async {
    FirebasePlatform.instance = _FakeCore();
    FirebaseAppCheckPlatform.instance = _StalledAppCheck();
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

  testWidgets('App Check 활성화가 끝나지 않아도 로그인 화면의 잠금이 풀린다', (tester) async {
    // 배포된 함수가 App Check 토큰 없는 호출을 거절하는 코드가 이것이다
    // (`functions/index.js` 의 `enforceAppCheck: true`). 상한을 넘긴 뒤 교환이
    // 실제로 나가든 그 앞에서 세우든, 사람이 보는 결과는 이 갈래로 모인다.
    kakao.exchangeFailure = FirebaseException(
      plugin: 'cloud_functions',
      code: 'unauthenticated',
    );

    SharedPreferences.setMockInitialValues(
      <String, Object>{kSelectedTeamPrefsKey: 'lg'},
    );
    await tester.pumpWidget(gate());
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(SocialSignInButton.labelOf(AuthProviderId.kakao)),
    );
    await tester.pump();

    expect(
      _StalledAppCheck.activateCalls,
      greaterThan(0),
      reason: '이 케이스의 전제다 — 카카오 경로가 활성화를 실제로 부르고 있어야 한다',
    );

    // 활성화는 여전히 끝나지 않는다. 그래도 화면은 되살아나야 한다.
    await tester.pump(_generousBound);
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(
      find.byType(SignInNotice),
      findsOneWidget,
      reason: '잠금만 풀고 아무 말도 하지 않으면 사람은 자기 탭이 삼켜졌다고 읽는다',
    );
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
      reason:
          '활성화가 끝나지 않는 실행에서 잠금이 풀리지 않으면, 빠져나갈 길은 앱을 '
          '다시 켜는 것뿐이다',
    );
  });
}
