/// `MainTabScaffold` 회귀 시험 — step 3.4 가 실제로 겪은 사고를 고정한다.
///
/// [IndexedStack] 이 다섯 탭을 전부 동시에 지어 두므로, 보고 있지 않은 탭의
/// 화면이 끝없는 애니메이션(예: `CircularProgressIndicator` 의 로딩 표시)을
/// 하나라도 띄우면 그 애니메이션은 아무도 보지 않는 동안에도 매 프레임
/// 다시 그려 달라고 계속 요청한다 — `WidgetTester.pumpAndSettle` 이 영원히
/// 끝나지 않는다.
///
/// 이 시험은 그 사고를 실제로 재현한다: 탭 하나가 (실제 마이페이지 탭이
/// `userProfileProvider` 로딩 중에 그러듯) 끝없는 스피너를 띄운 채 있고,
/// 사람은 그 탭을 한 번도 열어 보지 않는다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/main_tab_scaffold.dart';

/// 끝없이 도는 스피너 하나뿐인 탭 — 실제로는 로딩이 끝나지 않는 자리를
/// 흉내 낸다.
class _ForeverLoadingTab extends StatelessWidget {
  const _ForeverLoadingTab();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

void main() {
  testWidgets('보고 있지 않은 탭이 끝없이 애니메이션해도 pumpAndSettle 이 끝난다', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainTabScaffold(
          tabs: [
            MainTab(
              label: '홈',
              icon: Icons.home_rounded,
              builder: (_) => const Scaffold(body: Text('홈 화면 본문')),
            ),
            MainTab(
              label: '로딩',
              icon: Icons.hourglass_empty_rounded,
              builder: (_) => const _ForeverLoadingTab(),
            ),
          ],
        ),
      ),
    );

    // 시작 탭(홈)만 보고 '로딩' 탭은 한 번도 열지 않는다 — 그런데도
    // IndexedStack 이 그 탭을 이미 지어 두었으므로, 뮤트하지 않으면 그
    // 스피너의 티커가 계속 프레임을 요청해 아래 호출이 타임아웃한다.
    await tester.pumpAndSettle();

    expect(find.text('홈 화면 본문'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
