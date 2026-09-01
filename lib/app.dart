import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend/auth.dart';
import 'content/content_providers.dart';
import 'design/tokens.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/home/home_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/team_select/selected_team.dart';
import 'features/team_select/team_select_screen.dart';
import 'ui/shared/content_fallback.dart';

/// 앱 루트 위젯 — 기본 토큰으로 ThemeData 를 깔고 루트 게이트를 띄운다.
///
/// 앱 생명주기를 구독해 백그라운드 → 포그라운드 복귀(resumed)마다
/// [invalidateContent] 로 콘텐츠 4종을 다시 로드한다 — 우천 취소가
/// 콜드 스타트뿐 아니라 세션 중에도 반영되는 경로("앱은 폴링" 결정).
/// resumed 는 실제 상태 전이에서만 발생하므로 과도한 재조회가 없다.
class KboAwayFansApp extends ConsumerStatefulWidget {
  const KboAwayFansApp({super.key});

  @override
  ConsumerState<KboAwayFansApp> createState() => _KboAwayFansAppState();
}

class _KboAwayFansAppState extends ConsumerState<KboAwayFansApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      invalidateContent(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBO 원정러',
      theme: ThemeData(
        scaffoldBackgroundColor: ColorTokens.background,
        fontFamily: TypeTokens.fontFamily,
      ),
      home: const SplashGate(),
    );
  }
}

/// 스플래시 연출을 먼저 재생하고, 끝나면 [RootGate] 로 페이드 전환한다.
///
/// 연출이 도는 동안 응원 팀 조회와 콘텐츠 로드가 뒤에서 함께 진행되므로
/// 실제 대기 시간이 늘지는 않는다. 스플래시는 콜드 스타트에서만 뜬다
/// (포그라운드 복귀는 위젯 트리가 유지되므로 다시 재생되지 않는다).
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: SplashTokens.handoff,
      child: _splashDone
          ? const RootGate()
          : SplashScreen(
              onComplete: () {
                if (mounted) setState(() => _splashDone = true);
              },
            ),
    );
  }
}

/// 첫 화면 분기 — 로그인하지 않았으면 로그인, 했으면 팀 유무로 온보딩/홈.
///
/// acceptance 계약:
/// - 로그인하지 않은 실행은 여기서 멈춘다. 계정 없이 앱을 쓰는 경로가 없다
///   ([XL] 소셜 로그인 필수 결정) — 팀이 기기에 저장돼 있어도 마찬가지다.
/// - 로그인한 실행의 분기는 사이클 1 그대로다: 온보딩은 팀 저장이 없을 때만
///   뜨고, 저장소 읽기 오류는 미선택과 같이 온보딩으로 보낸다(잘못된 값으로
///   홈 진입 방지).
/// - 로그아웃하면 [authStateProvider] 가 null 을 흘려 이 자리가 다시 로그인
///   화면이 된다.
///
/// 세션을 확인하지 못한 경우(스트림 오류, 또는 `AuthService` 주입 없음)도
/// 로그인 화면이되 안내를 함께 띄운다 — 로그인한 것으로 볼 수는 없고,
/// 말없이 되돌리면 까닭 없이 로그아웃된 것으로 보이기 때문이다.
///
/// 게이트는 자기 route 안의 화면만 갈아 끼운다. 그래서 로그인한 뒤 루트
/// Navigator 에 밀어 올린 화면(팀 바꾸기·장소 화면 등)은 인증 상태가 바뀌어도
/// 저 혼자 위에 남는다 — 로그아웃한 사람이 로그인 뒤의 화면을 계속 조작하게
/// 되는 자리다. 그래서 이 게이트는 화면을 가르는 일에 더해, "로그인됨"에서
/// 벗어나는 순간 자기 위에 쌓인 route 를 함께 내린다. 미는 쪽마다 뒷정리를
/// 심지 않는 것은, 그러면 화면이 하나 늘 때마다 같은 빈틈이 다시 열리기
/// 때문이다.
class RootGate extends ConsumerStatefulWidget {
  const RootGate({super.key});

  @override
  ConsumerState<RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<RootGate> {
  /// 게이트가 올라앉은 route — 되감기가 멈춰야 하는 자리다.
  ///
  /// `isFirst` 로 대신하지 않는 것은 그 술어가 "첫 route"를 뜻할 뿐이어서,
  /// 게이트가 첫 route 밖으로 나가는 순간(예: 앱 위에 온보딩 흐름을 하나 더
  /// 밀어 올린 구조) 서술과 코드가 조용히 어긋나기 때문이다. inherited
  /// 조회라 [didChangeDependencies] 에서 잡는다.
  ModalRoute<Object?>? _gateRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gateRoute = ModalRoute.of(context);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      if (previous != null && _isSignedIn(previous) && !_isSignedIn(next)) {
        _dismissRoutesAboveGate();
      }
    });

    // 오류를 먼저 본다 — 세션 스트림이 값을 흘린 뒤에 실패하면 이전 값이
    // 상태에 남아 있어(AsyncValue 는 실패해도 마지막 값을 들고 있다) 값부터
    // 보면 끊긴 세션으로 홈에 머무르게 된다.
    return switch (ref.watch(authStateProvider)) {
      AsyncValue(hasError: true) => const SignInScreen(
        notice: '로그인 상태를 확인하지 못했어요. 다시 로그인해 주세요.',
      ),
      AsyncValue(hasValue: true, :final value) => value == null
          ? const SignInScreen()
          : const _SignedInGate(),
      _ => _gateLoading,
    };
  }

  /// 게이트 위에 쌓인 route 를 전부 내린다.
  ///
  /// 프레임이 끝난 뒤로 미루는 것은, 인증 상태가 build 도중에 바뀌는 경우에도
  /// Navigator 를 건드리는 시점이 프레임 밖이 되게 하려는 것이다. 미루는 이상
  /// 예약과 실행 사이가 벌어지므로, 실행하는 자리에서 인증 상태를 **다시 본다**
  /// — 세션이 한 프레임 안에서 null 로 깜빡였다가 같은 계정으로 돌아오는 모양
  /// (토큰 갱신 중의 순간적 null, 재인증, 계정 링크)에서 전이만 보고 예약한
  /// 되감기가 그대로 실행되면, 로그아웃한 적 없는 사람이 밀어 올린 화면을
  /// 잃는다. 전이 판정은 예약의 조건이고, 지금 로그아웃 상태인지는 실행의
  /// 조건이다.
  void _dismissRoutesAboveGate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isSignedIn(ref.read(authStateProvider))) return;
      final gateRoute = _gateRoute;
      Navigator.maybeOf(context, rootNavigator: true)?.popUntil(
        // `isFirst` 를 함께 두는 것은 멈출 자리를 못 찾은 popUntil 이 스택을
        // 통째로 비우지 않게 하는 바닥이다 (게이트가 루트 Navigator 밖의
        // 중첩 Navigator 안에 있으면 그 route 는 여기서 만날 수 없다).
        (route) => identical(route, gateRoute) || route.isFirst,
      );
    });
  }
}

/// 세션이 확인된 로그인 상태인가 — 오류는 값이 남아 있어도 로그인이 아니다.
bool _isSignedIn(AsyncValue<AuthUser?> state) =>
    !state.hasError && state.hasValue && state.value != null;

/// 로그인한 뒤의 분기 — 저장된 응원 팀이 없으면 온보딩, 있으면 홈.
class _SignedInGate extends ConsumerWidget {
  const _SignedInGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(selectedTeamIdProvider)) {
      AsyncData(:final value) => value == null
          ? const TeamSelectScreen()
          : HomeScreen(teamId: value),
      AsyncError() => const TeamSelectScreen(),
      _ => _gateLoading,
    };
  }
}

/// 게이트가 아직 갈래를 못 정한 동안의 화면 — 스피너는 [ContentFallback] 의
/// 로딩 모습 그대로다 (로스터에 있는 단일 구현을 다시 짜지 않는다).
const Widget _gateLoading = Scaffold(body: ContentFallback(loading: true));
