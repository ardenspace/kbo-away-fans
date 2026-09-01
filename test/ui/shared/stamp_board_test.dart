/// StampBoard 위젯 테스트 — 판은 빈 칸까지 10칸을 전부 그리고,
/// 사용자 문서의 칸별 요약(`board` map) 하나만 읽어 각 칸의 모습을 정한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/ui/shared/stamp_badge.dart';
import 'package:kbo_away_fans/ui/shared/stamp_board.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

List<StampBadge> badges(WidgetTester tester) =>
    tester.widgetList<StampBadge>(find.byType(StampBadge, skipOffstage: false)).toList();

void main() {
  testWidgets('빈 판도 10칸을 전부 렌더한다', (tester) async {
    await tester.pumpWidget(host(const StampBoard()));

    expect(tester.takeException(), isNull);
    expect(badges(tester), hasLength(BadgeTokens.cellCount));
    expect(badges(tester), hasLength(kBoardCellIds.length));
    expect(badges(tester).every((badge) => badge.stamps == 0), isTrue);
  });

  testWidgets('칸 요약이 있는 칸만 도장 개수가 실린다 (키 없는 칸은 빈 칸)', (tester) async {
    await tester.pumpWidget(
      host(
        StampBoard(
          board: {
            'jamsil_lg': BoardCell.forCount(count: 4),
            'gwangju_kia': BoardCell.forCount(count: 12),
          },
        ),
      ),
    );

    final all = badges(tester);
    expect(all, hasLength(BadgeTokens.cellCount));
    final stamped = all.where((badge) => badge.stamps > 0).map((b) => b.stamps).toList();
    expect(stamped, unorderedEquals(<int>[4, 12]));
  });

  testWidgets('잠실은 LG·두산 두 칸이라 같은 구장이 두 번 그려진다', (tester) async {
    await tester.pumpWidget(
      host(const StampBoard(labels: {'jamsil_lg': 'LG', 'jamsil_doosan': '두산'})),
    );

    expect(find.text('LG'), findsOneWidget);
    expect(find.text('두산'), findsOneWidget);
  });

  testWidgets('칸을 누르면 그 칸의 id 를 돌려준다', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      host(
        StampBoard(
          labels: const {'sajik_lotte': '롯데'},
          onCellTap: tapped.add,
        ),
      ),
    );

    await tester.tap(find.text('롯데'));
    await tester.pump();
    expect(tapped, <String>['sajik_lotte']);
  });
}
