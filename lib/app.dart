import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content/content_providers.dart';
import 'design/tokens.dart';
import 'features/home/home_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/team_select/selected_team.dart';
import 'features/team_select/team_select_screen.dart';

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
      title: 'KBO 원정 도장깨기',
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

/// 첫 화면 분기 — 저장된 응원 팀이 없으면 온보딩, 있으면 홈.
///
/// acceptance 계약: 온보딩은 첫 실행(= 저장 없음)에만 뜨고,
/// 선택 후 재실행은 온보딩 없이 홈으로 간다. 저장소 읽기 오류는
/// 미선택과 동일하게 온보딩으로 보낸다(잘못된 값으로 홈 진입 방지).
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(selectedTeamIdProvider)) {
      AsyncData(:final value) => value == null
          ? const TeamSelectScreen()
          : HomeScreen(teamId: value),
      AsyncError() => const TeamSelectScreen(),
      _ => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
    };
  }
}
