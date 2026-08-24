/// ScratchCard 위젯 테스트 (step 3.2) — 긁기 제스처 시뮬레이션으로
/// 진행 임계 도달 시 공개, 부분 긁기는 미공개, 재긁기 시 커버 복귀와
/// 내용 교체를 검증한다. 연출 수치는 motion 토큰만 사용
/// (raw 수치는 check-hardcoded-values.sh 훅이 검사).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/scratch_card.dart';

/// 카드 위·아래 두 줄을 가로로 끝까지 긁는다 (커버리지 임계를 확실히 넘김).
Future<void> scratchAcross(WidgetTester tester, Finder finder) async {
  final rect = tester.getRect(finder);
  for (final fraction in [0.25, 0.75]) {
    final start = Offset(rect.left + 1, rect.top + rect.height * fraction);
    final gesture = await tester.startGesture(start);
    var traveled = 0.0;
    while (traveled < rect.width - 2) {
      await gesture.moveBy(const Offset(20, 0));
      traveled += 20;
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('긁기 진행에 따라 드러난다 — 부분 긁기는 미공개, 임계를 넘으면 공개',
      (tester) async {
    var revealCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ScratchCard(
              hiddenLabel: '광안리 방탈출',
              hiddenSublabel: '방탈출',
              onRevealed: () => revealCount++,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('오늘 뭐하지? 긁어 보기'), findsOneWidget);
    expect(find.text('광안리 방탈출'), findsNothing);

    // 짧게 한 번 긁는 것으로는 공개되지 않는다.
    final rect = tester.getRect(find.byType(ScratchCard));
    final gesture = await tester.startGesture(rect.center);
    await tester.pump();
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(revealCount, 0);
    expect(find.text('광안리 방탈출'), findsNothing);

    // 카드 전체를 긁으면 공개되고 onRevealed 가 1회 불린다.
    await scratchAcross(tester, find.byType(ScratchCard));
    expect(revealCount, 1);
    expect(find.text('광안리 방탈출'), findsOneWidget);
    expect(find.text('방탈출'), findsOneWidget);
  });

  testWidgets('다시 긁기 — 커버가 돌아오고 onRescratch 가 바꾼 내용이 새로 드러난다',
      (tester) async {
    var revealCount = 0;
    var label = '광안리 방탈출';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: ScratchCard(
                hiddenLabel: label,
                onRevealed: () => revealCount++,
                onRescratch: () => setState(() => label = '서면 카페'),
              ),
            ),
          ),
        ),
      ),
    );

    await scratchAcross(tester, find.byType(ScratchCard));
    expect(find.text('광안리 방탈출'), findsOneWidget);
    expect(find.text('다시 긁기'), findsOneWidget);

    // 다시 긁기: 커버가 복귀해 내용이 숨고, 소유자가 내용을 갈아끼운다.
    await tester.tap(find.text('다시 긁기'));
    await tester.pumpAndSettle();
    expect(find.text('광안리 방탈출'), findsNothing);
    expect(find.text('서면 카페'), findsNothing);

    // 같은 카드를 다시 긁으면 새 내용이 드러난다.
    await scratchAcross(tester, find.byType(ScratchCard));
    expect(revealCount, 2);
    expect(find.text('서면 카페'), findsOneWidget);
  });
}
