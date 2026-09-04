import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../ui/shared/content_fallback.dart';
import '../../ui/shared/main_tab_scaffold.dart';
import '../likes/likes_tab_screen.dart';
import '../places/recommend_tab_screen.dart';
import '../team_select/selected_team.dart';
import 'home_screen.dart';

/// 로그인 이후 앱의 최상위 골격 (step 3.1) — 하단 5탭을 [MainTabScaffold] 위에
/// 세운다. [lib/features/onboarding/location_consent.dart] 의
/// `OnboardingLocationGate` 가 홈을 보여주던 그 자리를 대신한다.
///
/// - **홈** 탭은 기존 [HomeScreen] 그대로다 (acceptance 계약 — 새로 짜지 않는다).
///   뿌리 위젯이 [_HomeTab] 인 까닭은 그 위젯 문서에 적었다(팀 변경 갱신이
///   얼어붙는 회귀를 그 자리에서 막는다).
/// - **추천** 탭은 사이클 1 의 장소 화면([RecommendTabScreen] →
///   `StadiumPlacesScreen`)을 그대로 잇는다.
/// - **좋아요** 탭(3.3)은 [LikesTabScreen] — 그 위젯 문서에 적힌 대로
///   [likedPlaceIdsProvider]·`placesProvider` 를 직접 구독한다. [IndexedStack]
///   이 다섯 탭을 전부 동시에 살려 두므로, 이 탭이 채워진 뒤로는
///   `likedPlaceIdsProvider` 의 세션당 1회 읽기가 "추천 목록을 열어 본
///   사람"이 아니라 "로그인해 이 화면에 닿은 모든 사람"에서 일어난다 — 다만
///   3.2 가 이미 이 provider 를 세션당 정확히 1회로 캐시해 두었으므로 늘어나는
///   것은 그 1회가 일어나는 **시점**이지 **횟수**가 아니다.
/// - **배지**(4.3)·**마이페이지**(3.4)는 아직 화면이 없다. 그 자리 표시
///   ([_ComingSoonTab])가 provider 를 하나도 구독하지 않는 것은 의도다 —
///   아직 없는 화면이 서버를 읽는 자리를 만들면 그 비용이 탭을 열어 보지
///   않아도 항상 켜져 있게 된다.
class MainTabsRoot extends StatelessWidget {
  const MainTabsRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MainTabScaffold(
      tabs: [
        MainTab(
          label: '홈',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          builder: (_) => const _HomeTab(),
        ),
        MainTab(
          label: '배지',
          icon: Icons.workspace_premium_outlined,
          selectedIcon: Icons.workspace_premium_rounded,
          builder: (_) => const _ComingSoonTab(label: '배지'),
        ),
        MainTab(
          label: '추천',
          icon: Icons.explore_outlined,
          selectedIcon: Icons.explore_rounded,
          builder: (_) => const RecommendTabScreen(),
        ),
        MainTab(
          label: '좋아요',
          icon: Icons.favorite_border_rounded,
          selectedIcon: Icons.favorite_rounded,
          builder: (_) => const LikesTabScreen(),
        ),
        MainTab(
          label: '마이페이지',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          builder: (_) => const _ComingSoonTab(label: '마이페이지'),
        ),
      ],
    );
  }
}

/// 홈 탭 뿌리 — [selectedTeamIdProvider] 를 직접 구독해 현재 팀 id 를 얻는다.
///
/// **왜 [MainTabsRoot] 가 팀 id 를 생성자 인자로 내려주지 않는가.** 탭의
/// 뿌리 위젯은 [MainTabScaffold] 안 탭별 [Navigator] 가 한 번 만든 route
/// 위에 얹힌다. 그 route 의 builder 클로저는 **처음 route 가 만들어질 때
/// 딱 한 번** 불리고(Flutter 의 Navigator 는 이미 있는 route 를
/// `onGenerateRoute` 로 다시 만들지 않는다), 그 뒤로는 route 가 들고 있는
/// **그 시점의** 클로저만 반복해서 다시 그린다. 그래서 팀 id 를 바깥에서
/// 생성자 인자로 흘려주면(예: `MainTabsRoot(teamId: ...)` → 클로저가 그 값을
/// 캡처) 그 인자는 route 가 만들어진 순간의 값에 얼어붙어, 이후 팀이
/// 바뀌어도(설정의 "응원 팀 바꾸기") 홈이 갱신되지 않는다 — 실제로 겪은
/// 회귀다. 이 위젯이 [selectedTeamIdProvider] 를 직접 구독하는 것은 그
/// 얼어붙는 경로를 아예 지나지 않기 위해서다: Riverpod 구독은 이 위젯
/// 자신의 element 를 직접 다시 그리므로, 바깥의 route/클로저 재생성 여부와
/// 무관하게 최신 값을 받는다.
class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamId = switch (ref.watch(selectedTeamIdProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    // 이 탭에 닿는 이상 게이트가 이미 팀이 있음을 보장했다. 그래도 재구독
    // 순간처럼 한 프레임 비어 있을 수 있는 자리는 조용히 대기 화면으로
    // 넘긴다 — 사람을 붙잡지 않는다.
    if (teamId == null) {
      return const Scaffold(body: ContentFallback(loading: true));
    }
    return HomeScreen(teamId: teamId);
  }
}

/// 아직 화면이 없는 탭의 자리 표시 — provider 를 구독하지 않는다(비용 없음).
class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Text('$label 탭은 곧 만나요', style: TextTokens.bodyMuted),
      ),
    );
  }
}
