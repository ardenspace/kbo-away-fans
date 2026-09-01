/// MainTabScaffold 위젯 테스트 — 하단 탭 골격의 계약:
/// 탭을 옮겨도 각 탭의 화면 스택이 살아 있고(IndexedStack + 탭별 Navigator),
/// 같은 탭을 다시 누르면 그 탭이 뿌리로 돌아온다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/main_tab_scaffold.dart';

/// 탭 안에서 한 겹 더 들어갈 수 있는 뿌리 화면.
class _TabRoot extends StatelessWidget {
  const _TabRoot(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(body: Center(child: Text('$name 상세'))),
            ),
          ),
          child: Text('$name 뿌리'),
        ),
      ),
    );
  }
}

List<MainTab> tabs() => [
  MainTab(label: '홈', icon: Icons.home_rounded, builder: (_) => const _TabRoot('홈')),
  MainTab(label: '배지', icon: Icons.workspace_premium_rounded, builder: (_) => const _TabRoot('배지')),
  MainTab(label: '내정보', icon: Icons.person_rounded, builder: (_) => const _TabRoot('내정보')),
];

void main() {
  testWidgets('탭 개수만큼 하단 항목을 렌더하고 첫 탭을 보여준다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MainTabScaffold(tabs: tabs())));

    expect(tester.takeException(), isNull);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('홈 뿌리'), findsOneWidget);
    for (final label in ['홈', '배지', '내정보']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('탭마다 Navigator 가 따로 있고 탭을 옮겨도 스택이 남는다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MainTabScaffold(tabs: tabs())));
    // 보이지 않는 탭도 트리에 살아 있다 (IndexedStack) — skipOffstage 를 끈다.
    expect(
      find.byType(Navigator, skipOffstage: false),
      findsNWidgets(tabs().length + 1), // 탭 3 + 앱 루트
    );

    // 홈 탭에서 한 겹 들어간다.
    await tester.tap(find.text('홈 뿌리'));
    await tester.pumpAndSettle();
    expect(find.text('홈 상세'), findsOneWidget);

    // 배지 탭으로 옮겼다가 돌아오면 홈은 들어간 자리 그대로다.
    await tester.tap(find.text('배지'));
    await tester.pumpAndSettle();
    expect(find.text('배지 뿌리'), findsOneWidget);

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(find.text('홈 상세'), findsOneWidget);
  });

  testWidgets('보고 있는 탭을 다시 누르면 그 탭이 뿌리로 돌아온다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MainTabScaffold(tabs: tabs())));

    await tester.tap(find.text('홈 뿌리'));
    await tester.pumpAndSettle();
    expect(find.text('홈 상세'), findsOneWidget);

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(find.text('홈 상세'), findsNothing);
    expect(find.text('홈 뿌리'), findsOneWidget);
  });

  testWidgets('initialIndex 로 다른 탭에서 시작할 수 있다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MainTabScaffold(tabs: tabs(), initialIndex: 2)),
    );

    expect(find.text('내정보 뿌리'), findsOneWidget);
  });
}
