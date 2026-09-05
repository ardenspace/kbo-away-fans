import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/shared/content_fallback.dart';
import '../../ui/shared/main_tab_scaffold.dart';
import '../badges/badges_tab_screen.dart';
import '../badges/stadium_visit.dart';
import '../likes/likes_tab_screen.dart';
import '../places/recommend_tab_screen.dart';
import '../profile/profile_tab_screen.dart';
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
/// - **마이페이지** 탭(3.4)은 [ProfileTabScreen] — `userProfileProvider` 를
///   직접 구독한다(그 위젯 문서 참조. 위 [_HomeTab] 과 같은 얼어붙음을 피하는
///   이유다).
/// - **배지** 탭(4.3)은 [BadgesTabScreen] — [userProfileProvider] 를 직접
///   구독한다(위 두 탭과 같은 이유다). [IndexedStack] 이 다섯 탭을 전부 살려
///   두므로 이 탭도 앱이 뜨는 순간 구독을 붙이는데, 그 provider 는 마이페이지
///   탭이 이미 보고 있던 **같은** 자리라 읽기가 늘지 않는다 — 판이 도장 문서를
///   읽지 않는 것이 4.3 의 성질이고, 자리 표시가 provider 를 하나도 구독하지
///   않던 까닭(아직 없는 화면이 비용을 늘 켜 두지 않게)도 그 성질로 이어진다.
///
/// 골격 전체를 [StadiumVisitTrigger] 가 감싼다(4.1) — 구장 방문 판정은
/// 배지 탭이 아니라 **앱을 여는 것 자체**에 걸린다. 그 까닭은 그 위젯의
/// 문서에 적었다. 판이 서버에서 읽는 것이 사용자 문서 하나라는 4.3 의 성질과
/// 어긋나지 않는다 — 이 판정은 서버를 읽지 않고, 그날 경기가 없거나 위치
/// 권한이 없으면 OS 에 좌표도 묻지 않는다.
class MainTabsRoot extends StatelessWidget {
  const MainTabsRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return StadiumVisitTrigger(child: _tabs());
  }

  Widget _tabs() {
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
          builder: (_) => const BadgesTabScreen(),
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
          builder: (_) => const ProfileTabScreen(),
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
