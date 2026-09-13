import 'package:flutter/material.dart';

/// 하단 탭 하나 — 이름·아이콘과 그 탭의 뿌리 화면.
@immutable
class MainTab {
  const MainTab({
    required this.label,
    required this.icon,
    required this.builder,
    this.selectedIcon,
  });

  /// 탭 이름 (하단에 적힌다).
  final String label;

  /// 탭 아이콘.
  final IconData icon;

  /// 골라진 탭의 아이콘. 없으면 [icon] 을 그대로 쓴다.
  final IconData? selectedIcon;

  /// 그 탭 Navigator 의 첫 화면.
  final WidgetBuilder builder;
}

/// 하단 5탭 골격 — 탭별 Navigator 스택을 유지한다.
///
/// [IndexedStack] 이라 탭을 옮겨도 다른 탭의 트리가 살아 있고, 탭마다 자기
/// [Navigator] 를 들고 있어 "배지 탭에서 칸 상세까지 들어갔다가 홈에 다녀와도
/// 그 자리 그대로"가 성립한다. 탭 하나에 하나의 Navigator 를 두는 대신
/// 최상위 Navigator 를 공유하면 화면을 밀어 올릴 때 하단 탭이 함께 덮여,
/// 탭이 앱의 뼈대가 아니라 첫 화면의 장식이 된다.
///
/// 시스템 뒤로가기는 [NavigatorPopHandler] 가 **보고 있는 탭의** 스택부터
/// 되돌린다 (`enabled` 로 활성 탭만 켜 둔다 — 꺼진 탭의 스택이 대신 pop 되면
/// 보이지 않는 곳에서 화면이 사라진다).
///
/// 표면과 하단 항목 스타일은 앱 루트 ThemeData에서 받는다. 탭별 Navigator
/// 위에 별도 Theme를 캡처하지 않아, 비활성 탭과 이미 열린 route도 같은
/// 전역 테마 전환을 물려받는다.
class MainTabScaffold extends StatefulWidget {
  const MainTabScaffold({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
  }) : assert(tabs.length > 0, '탭이 하나는 있어야 한다'),
       assert(
         initialIndex >= 0 && initialIndex < tabs.length,
         '시작 탭이 목록 안에 있어야 한다',
       );

  /// 왼쪽부터의 탭 목록.
  final List<MainTab> tabs;

  /// 처음 보이는 탭.
  final int initialIndex;

  @override
  State<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<MainTabScaffold> {
  late int _index = widget.initialIndex.clamp(0, widget.tabs.length - 1);

  /// 탭마다 하나씩 — 탭을 다시 눌러 뿌리로 되돌리거나 뒤로가기를 넘길 때 쓴다.
  late final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    widget.tabs.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  void _select(int index) {
    // 보고 있는 탭을 다시 누르면 그 탭을 뿌리로 되돌린다 (탭 자체가 "처음으로").
    if (index == _index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _index = index);
  }

  Widget _tabNavigator(int index) {
    return TickerMode(
      // [IndexedStack] 이 다섯 탭을 전부 동시에 지어 두는 만큼, 보고 있지
      // 않은 탭의 화면이 스피너 같은 끝없는 애니메이션을 하나라도 띄우면 그
      // 애니메이션은 아무도 보지 않는 동안에도 매 프레임 다시 그려 달라고
      // 계속 요청한다 — 탭을 한 번도 열어 보지 않아도 프레임이 영원히
      // 끝나지 않는다(`WidgetTester.pumpAndSettle` 이 그 자리에서 그대로
      // 멈춘다는 사실로 처음 드러났다 — `main_tab_scaffold_regression_test.dart`
      // 참조). [TickerMode] 는 위젯의 상태는 그대로 살려 둔 채 그 안의
      // `Ticker`(애니메이션이 프레임을 요청하는 실제 통로)만 죽여, 보이는
      // 탭으로 돌아왔을 때 애니메이션이 멈춘 그 값에서 다시 움직이게 한다.
      enabled: index == _index,
      child: NavigatorPopHandler(
        enabled: index == _index,
        // `enabled` 는 이 route 의 PopScope.canPop 만 정한다 — pop 콜백 자체는
        // IndexedStack 이 살려 둔 5개 핸들러 전부에 전달된다(Flutter
        // navigator_pop_handler.dart, "onPop will still be called" 는 enabled
        // 와 무관). 이 가드가 없으면 뒤로가기 한 번에 꺼진 탭까지 함께 pop 된다.
        onPopWithResult: (_) {
          if (index != _index) return;
          _navigatorKeys[index].currentState?.pop();
        },
        child: Navigator(
          key: _navigatorKeys[index],
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: widget.tabs[index].builder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < widget.tabs.length; i++) _tabNavigator(i),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _select,
        // 다섯 탭이 전부 이름을 달고 서야 무엇이 있는지 한눈에 읽힌다.
        type: BottomNavigationBarType.fixed,
        items: [
          for (final tab in widget.tabs)
            BottomNavigationBarItem(
              icon: Icon(tab.icon),
              activeIcon: Icon(tab.selectedIcon ?? tab.icon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
