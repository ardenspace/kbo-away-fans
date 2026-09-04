/// `main` 이 **플랫폼 채널의 침묵에 갇히지 않는가** — 그리고 갇히지 않은 실행이
/// 어떤 상태로 뜨는가.
///
/// `runApp` 앞의 초기화 넷 중 셋(분석·App Check·인증)은 같은
/// `Firebase.initializeApp()` 을 기다린다. 각자의 try/catch 는 **오류**를 삼키지만
/// **지연**은 삼키지 못하므로, 그 채널이 답하지 않는 실행에서는 세 await 가 모두
/// 끝나지 않는다. 그동안 사람이 보는 것은 스플래시 하나뿐이고 빠져나갈 길은 앱을
/// 다시 켜는 것뿐이다 — `kakao_app_check_stall_probe_test.dart` 가 로그인 버튼에서
/// 재는 것과 같은 모양이고, 여기서 붙잡히는 것은 스플래시다.
///
/// App Check 쪽에는 이미 `kAppCheckActivationTimeout` 이 서 있었지만 그 상한만으로는
/// 아무것도 사지 못했다: 잘린 자리 바로 다음 줄의 `FirebaseAuthService`
/// 초기화(그리고 그 앞의 분석 초기화)가 같은 채널을 상한 없이 기다렸기 때문이다.
/// 그래서 상한은 부팅 전체에 하나로 서 있고(`kBootInitTimeout`), 이 파일이 그것을
/// **동작으로** 잰다.
///
/// 재는 것이 둘이다.
///  1. 부팅이 끝나 앱이 실제로 뜨는가 (상한이 없으면 `runApp` 에 닿지 못한다).
///  2. **그렇게 뜬 실행에서 사람이 무엇을 보는가.** Firebase 가 서지 않았으므로
///     인증도 사용자 문서도 `firebase-unconfigured` 로 실패한다 — 그 실행은
///     설정 파일이 없는 클론과 같은 갈래로 흘러가야 한다: 로그인 화면 + 안내.
///     말없이 로그인 화면만 세우면 사람에게는 까닭 없이 로그아웃된 것으로 보인다.
library;

import 'dart:async';

import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/features/auth/sign_in_screen.dart';
import 'package:kbo_away_fans/features/splash/splash_screen.dart';
import 'package:kbo_away_fans/main.dart' as entrypoint;
import 'package:shared_preferences/shared_preferences.dart';

/// **영영 끝나지 않는** Firebase 초기화 — 플랫폼 채널이 답하지 않는 실행의 대역.
/// (실기기에서 이 모양이 되는 것은 네이티브 초기화가 Play 서비스·네트워크 응답을
/// 기다리며 멈춘 경우다. 오류가 아니라 침묵이라 try/catch 가 닿지 않는다.)
class _StalledCore extends FirebasePlatform {
  int initializeCalls = 0;

  @override
  List<FirebaseAppPlatform> get apps => <FirebaseAppPlatform>[];

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) {
    initializeCalls++;
    return Completer<FirebaseAppPlatform>().future;
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) =>
      throw StateError('이 실행에서는 앱이 서지 않는다');
}

void main() {
  late _StalledCore core;

  setUp(() {
    core = _StalledCore();
    FirebasePlatform.instance = core;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('플랫폼 채널이 답하지 않아도 부팅이 상한에서 끝나고 앱이 뜬다', (tester) async {
    // `main` 을 기다리지 않고 띄운다 — 상한이 타이머로 걸려 있어서, 기다리면
    // 그 타이머를 밀어 줄 사람이 없다.
    unawaited(entrypoint.main());
    await tester.pump();

    expect(
      core.initializeCalls,
      greaterThan(0),
      reason: '이 케이스의 전제다 — 부팅이 실제로 멎은 초기화를 기다리고 있어야 한다',
    );
    expect(
      find.byType(KboAwayFansApp),
      findsNothing,
      reason: '아직 상한 안이라 부팅 중이 맞다',
    );

    await tester.pump(entrypoint.kBootInitTimeout);
    await tester.pump();

    expect(
      find.byType(KboAwayFansApp),
      findsOneWidget,
      reason: '상한이 없으면 여기 닿지 못한다 — 스플래시조차 뜨지 않고, 사람이 보는 '
          '것은 OS 의 런치 화면뿐이며 나갈 길은 앱을 다시 켜는 것밖에 없다',
    );
    expect(find.byType(SplashScreen), findsOneWidget);
  });

  testWidgets('그렇게 뜬 실행은 설정 없는 클론과 같은 갈래로 간다 (로그인 화면 + 안내)', (
    tester,
  ) async {
    unawaited(entrypoint.main());
    await tester.pump();
    await tester.pump(entrypoint.kBootInitTimeout);

    // 스플래시 연출을 끝까지 재생한다 — 그 뒤에 루트 게이트가 선다.
    await tester.pump();
    await tester.pump(SplashScreen.totalDuration);
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing, reason: '스플래시가 걷혀야 한다');
    expect(
      find.byType(SignInScreen),
      findsOneWidget,
      reason: 'Firebase 가 서지 않았으므로 인증은 firebase-unconfigured 로 실패한다 — '
          '그 실행에서 갈 수 있는 화면은 로그인 화면뿐이다',
    );
    expect(
      find.byType(SignInNotice),
      findsOneWidget,
      reason: '안내 없이 로그인 화면만 세우면 사람에게는 까닭 없이 로그아웃된 것으로 '
          '보인다 — 1.6 이 "조용한 no-op 을 쓰지 않는다"로 정한 그 자리다',
    );
  });
}
