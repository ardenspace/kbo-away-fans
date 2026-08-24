import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design/tokens.dart';
import 'features/home/home_screen.dart';
import 'features/team_select/selected_team.dart';
import 'features/team_select/team_select_screen.dart';

/// 앱 루트 위젯 — 기본 토큰으로 ThemeData 를 깔고 루트 게이트를 띄운다.
class KboAwayFansApp extends StatelessWidget {
  const KboAwayFansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KBO 원정 도장깨기',
      theme: ThemeData(
        scaffoldBackgroundColor: ColorTokens.background,
        fontFamily: TypeTokens.fontFamily,
      ),
      home: const RootGate(),
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
