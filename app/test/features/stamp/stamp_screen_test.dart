/// task 1.6 — 스탬프북 화면 위젯 테스트 (R6·R7).
///
/// 데이터 계층 fake 주입만으로 성립한다 — 실 Supabase 없음. 구장/스탬프는
/// fake repository 를 provider override 로, 발급 진행 상태는 컨트롤러 override 로 준다.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/stamp/stamp_controller.dart';
import 'package:kbo_away_fans/features/stamp/stamp_models.dart';
import 'package:kbo_away_fans/features/stamp/stamp_repository.dart';
import 'package:kbo_away_fans/features/stamp/stadium_repository.dart';
import 'package:kbo_away_fans/features/stamp/stamp_screen.dart';
import 'package:kbo_away_fans/features/stamp/stampbook_widgets.dart';
import 'package:kbo_away_fans/shared/theme/team_colors.dart';

import 'fakes.dart';

// ── 10팀 구장 fixture ────────────────────────────────────────────────────────
const _abbrs = [
  'OB', 'LG', 'KW', 'SK', 'LT', 'SS', 'HH', 'HT', 'NC', 'KT', //
];

List<StampStadium> _tenStadiums() => [
      for (var i = 0; i < _abbrs.length; i++)
        StampStadium(
          id: 'stadium-$i',
          name: 'stadium-$i',
          lat: 37.0 + i,
          lng: 127.0 + i,
          stampRadiusM: 500,
          teamId: 'team-$i',
          teamAbbr: _abbrs[i],
        ),
    ];

Stamp _stampOn(String stadiumId) => Stamp(
      id: 'stamp-$stadiumId',
      userId: 'user-1',
      stadiumId: stadiumId,
      lat: 37,
      lng: 127,
      stampedAt: DateTime(2026, 7, 4),
    );

/// myStamps 가 영원히 완료되지 않는 fake — 로딩 인디케이터 검증용.
class HangingStampRepository implements StampRepository {
  @override
  Future<List<Stamp>> myStamps() => Completer<List<Stamp>>().future;

  @override
  Future<Stamp> insertStamp({
    required String stadiumId,
    required double lat,
    required double lng,
  }) =>
      Completer<Stamp>().future;
}

/// 항상 발급 진행 중(StampIssuing) 을 내는 컨트롤러 — 버튼 비활성 검증용.
class _IssuingController extends StampController {
  @override
  StampIssueState build() => const StampIssuing();
}

Widget _app({
  required StadiumRepository stadiumRepo,
  required StampRepository stampRepo,
  bool issuing = false,
}) {
  return ProviderScope(
    overrides: [
      stadiumRepositoryProvider.overrideWithValue(stadiumRepo),
      stampRepositoryProvider.overrideWithValue(stampRepo),
      if (issuing)
        stampControllerProvider.overrideWith(_IssuingController.new),
    ],
    child: const MaterialApp(home: StampScreen()),
  );
}

void main() {
  testWidgets('스탬프 M개·구장 10개 → 10칸 그리드 + 수집률 "M/10" (R6·R7)',
      (tester) async {
    final stadiums = _tenStadiums();
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: stadiums),
      stampRepo: FakeStampRepository(initial: [
        _stampOn('stadium-0'),
        _stampOn('stadium-1'),
        _stampOn('stadium-2'),
      ]),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(StampCellTile), findsNWidgets(10));
    expect(find.text('3/10'), findsOneWidget);
  });

  testWidgets('방문 칸 도장 = 팀 컬러, 미방문 = 회색 아웃라인 (R7)', (tester) async {
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _tenStadiums()),
      stampRepo: FakeStampRepository(initial: [_stampOn('stadium-0')]),
    ));
    await tester.pumpAndSettle();

    final cells = tester.widgetList<StampCellTile>(find.byType(StampCellTile));
    final visited = cells.firstWhere((c) => c.teamAbbr == 'OB');
    final unvisited = cells.firstWhere((c) => c.teamAbbr == 'LG');

    expect(visited.visited, isTrue);
    expect(visited.stampColor, kTeamColors['OB']!.primary);
    expect(unvisited.visited, isFalse);
    expect(unvisited.stampColor, StampCellTile.unvisitedColor);
  });

  testWidgets('원격 조회 중 로딩 인디케이터 (R6)', (tester) async {
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _tenStadiums()),
      stampRepo: HangingStampRepository(),
    ));
    await tester.pump(); // settle 하지 않는다 — 로딩 고정.

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(StampCellTile), findsNothing);
  });

  testWidgets('조회 실패 → 오류+재시도 위젯, "0/10" 빈 그리드 아님 (R6)',
      (tester) async {
    final stampFake = FakeStampRepository()
      ..listError = const StampNetworkException();
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _tenStadiums()),
      stampRepo: stampFake,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(StampbookError), findsOneWidget);
    expect(find.text('0/10'), findsNothing);
    expect(find.byType(StampCellTile), findsNothing);

    // 재시도 버튼: 에러 해제 후 탭하면 그리드가 렌더된다.
    stampFake.listError = null;
    await tester.tap(find.byType(StampbookRetryButton));
    await tester.pumpAndSettle();
    expect(find.byType(StampCellTile), findsNWidgets(10));
  });

  testWidgets('"도장 찍기" 버튼 — 발급 진행 중 비활성(onPressed==null) (R14)',
      (tester) async {
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _tenStadiums()),
      stampRepo: FakeStampRepository(),
      issuing: true,
    ));
    await tester.pump(); // 스탬프북 로드 완료. settle 하지 않는다 — 발급 스피너가 계속 돈다.

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '도장 찍기'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('"도장 찍기" 버튼 — 유휴 상태에서는 활성', (tester) async {
    await tester.pumpWidget(_app(
      stadiumRepo: FakeStadiumRepository(stadiums: _tenStadiums()),
      stampRepo: FakeStampRepository(),
    ));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '도장 찍기'),
    );
    expect(button.onPressed, isNotNull);
  });
}
