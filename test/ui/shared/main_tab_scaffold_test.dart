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

  group('뒤로 가기 우선순위 — 보고 있는 탭의 스택부터 소비한다', () {
    testWidgets('탭 안에 민 화면이 있으면 시스템 뒤로가기가 그것부터 닫는다', (tester) async {
      await tester.pumpWidget(MaterialApp(home: MainTabScaffold(tabs: tabs())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('홈 뿌리'));
      await tester.pumpAndSettle();
      expect(find.text('홈 상세'), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        handled,
        isTrue,
        reason: '탭 스택에 닫을 route 가 있었으니 시스템 뒤로가기가 그것을 소비해야 한다',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('홈 상세'), findsNothing);
      expect(
        find.text('홈 뿌리'),
        findsOneWidget,
        reason: '탭이 바뀌지 않고 그 탭의 뿌리로만 한 겹 되돌아온다',
      );
    });

    testWidgets('탭 스택이 뿌리 하나뿐이면 시스템 뒤로가기가 소비하지 않고, 화면도 그대로다', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: MainTabScaffold(tabs: tabs())));
      await tester.pumpAndSettle();

      // 민 화면이 하나도 없는 뿌리 상태 — 소비할 route 가 없다.
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        handled,
        isFalse,
        reason: '탭 스택이 비어 있으니(뿌리 하나뿐) 소비할 route 가 없어 시스템에 넘겨야 한다'
            ' (앱 종료 등 그 다음 처리는 이 컴포넌트의 책임이 아니다)',
      );
      expect(tester.takeException(), isNull, reason: '빈 스택에 뒤로가기가 와도 안전해야 한다');
      expect(find.text('홈 뿌리'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // 다시 눌러도(연타) 여전히 안전하다 — 소비할 게 계속 없다.
      final handledAgain = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handledAgain, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '두 탭 모두에 화면을 밀어 올린 채 보고 있는 탭만 뒤로가기로 닫힌다 — '
      '꺼진 탭의 스택은 그대로다',
      (tester) async {
        // `enabled` 는 이 route 의 PopScope.canPop 만 정할 뿐, pop 콜백 자체는
        // IndexedStack 이 살려 둔 핸들러 전부에 전달된다(Flutter 프레임워크
        // 사실 — `enabled` 와 무관). 그래서 "보고 있는 탭만 스택을 소비한다"는
        // 성질은 **양쪽 탭 모두에 소비할 route 가 있어야만** 드러난다 — 한쪽이
        // 뿌리 하나뿐이면(소비할 게 없으면) 시스템이 아예 pop 을 시도하지 않아
        // 가드 유무와 무관하게 같은 결과가 나온다(실측: 위 "보이지 않는 탭"
        // 시험은 그래서 이 가드를 재지 못한다).
        await tester.pumpWidget(
          MaterialApp(home: MainTabScaffold(tabs: tabs())),
        );
        await tester.pumpAndSettle();

        // 홈에 한 겹 밀어 올린다.
        await tester.tap(find.text('홈 뿌리'));
        await tester.pumpAndSettle();
        expect(find.text('홈 상세'), findsOneWidget);

        // 배지로 옮겨 배지에도 한 겹 밀어 올린다 — 지금 보고 있는 탭은 배지.
        await tester.tap(find.text('배지'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('배지 뿌리'));
        await tester.pumpAndSettle();
        expect(find.text('배지 상세'), findsOneWidget);

        // 시스템 뒤로가기 한 번 — 두 탭 다 소비할 route 가 있다.
        final handled = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(handled, isTrue);
        expect(tester.takeException(), isNull);
        expect(
          find.text('배지 상세'),
          findsNothing,
          reason: '보고 있는 배지 탭은 뒤로가기로 한 겹 닫혀야 한다',
        );
        expect(find.text('배지 뿌리'), findsOneWidget);

        // 홈으로 돌아가 본다 — 가드가 없으면 이 자리에서 '홈 상세'가 사라져
        // 있다(꺼져 있던 탭까지 함께 pop 됐다는 뜻).
        await tester.tap(find.text('홈'));
        await tester.pumpAndSettle();
        expect(
          find.text('홈 상세'),
          findsOneWidget,
          reason: '보고 있지 않던 홈 탭의 스택은 뒤로가기 한 번에 영향받지 않아야 한다',
        );
      },
    );

    testWidgets('보이지 않는 탭의 스택은 뒤로가기에 반응하지 않는다', (tester) async {
      await tester.pumpWidget(MaterialApp(home: MainTabScaffold(tabs: tabs())));
      await tester.pumpAndSettle();

      // 홈에서 한 겹 들어간 채로 배지 탭으로 옮긴다 — 지금 보고 있는 탭은 배지.
      await tester.tap(find.text('홈 뿌리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('배지'));
      await tester.pumpAndSettle();
      expect(find.text('배지 뿌리'), findsOneWidget);

      // 배지는 뿌리 하나뿐이라 소비할 게 없다 — 꺼진 홈의 스택이 대신
      // 소비되면 안 된다(보이지 않는 곳에서 화면이 사라지는 것을 막는 가드).
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isFalse);
      expect(find.text('배지 뿌리'), findsOneWidget);

      // 홈으로 돌아오면 아까 민 화면이 그대로다 — 꺼져 있던 동안 아무도
      // 대신 pop 하지 않았다는 증거.
      await tester.tap(find.text('홈'));
      await tester.pumpAndSettle();
      expect(find.text('홈 상세'), findsOneWidget);
    });
  });
}
