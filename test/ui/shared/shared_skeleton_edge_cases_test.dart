/// 공유 컴포넌트 골격의 가장자리 사례 — 컴포넌트별 테스트 파일이 다루지 않는
/// 자리들만 모은다.
///
/// 재는 것: 판의 칸↔팀 테마 1:1 대응(10칸 전부), 칸 id 되돌리기가 모든 칸에서
/// 옳은지, 등급 임계의 **사이 값**(2·9·큰 수), 등급 링이 실제 캔버스에 그려질 때의
/// 기하(겹 순서·칸 안쪽에 머무는지·작은 칸에서 터지지 않는지), 시스템 뒤로가기가
/// 보고 있는 탭만 되돌리는지, 실패 뒤 다음 탭이 다시 되는지.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/ui/shared/content_fallback.dart';
import 'package:kbo_away_fans/ui/shared/like_button.dart';
import 'package:kbo_away_fans/ui/shared/main_tab_scaffold.dart';
import 'package:kbo_away_fans/ui/shared/stamp_badge.dart';
import 'package:kbo_away_fans/ui/shared/stamp_board.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

List<StampBadge> badges(WidgetTester tester) => tester
    .widgetList<StampBadge>(find.byType(StampBadge, skipOffstage: false))
    .toList();

BadgeTierRingPainter? ringPainter(WidgetTester tester) {
  final painters = tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(StampBadge),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((paint) => paint.foregroundPainter)
      .whereType<BadgeTierRingPainter>();
  return painters.isEmpty ? null : painters.first;
}

/// `drawCircle` 호출만 받아 적는 캔버스 — painter 가 실제로 무엇을 그렸는지 잰다.
class _CircleRecorder implements Canvas {
  final List<({double radius, double width, Color color})> circles = [];

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    circles.add((radius: radius, width: paint.strokeWidth, color: paint.color));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('StampBoard — 칸 로스터', () {
    testWidgets('열 칸이 팀 테마 10개와 1:1 로 짝지어진다 (칸 id 의 홈팀 색)', (tester) async {
      await tester.pumpWidget(host(const StampBoard()));

      final rendered = badges(tester);
      expect(rendered, hasLength(kBoardCellIds.length));

      final expected = [
        for (final cellId in kBoardCellIds)
          TeamThemes.byId[boardCellTeamId(cellId)]!,
      ];
      expect(
        rendered.map((badge) => badge.theme).toList(),
        orderedEquals(expected),
      );
      // 10칸이 서로 다른 테마이고, 팀 테마 로스터를 남김없이 덮는다.
      expect(
        rendered.map((badge) => badge.theme).toSet(),
        TeamThemes.byId.values.toSet(),
      );
    });

    testWidgets('열 칸 전부가 자기 id 를 돌려준다 (한 칸만이 아니라)', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        host(
          StampBoard(
            labels: {for (final id in kBoardCellIds) id: id},
            onCellTap: tapped.add,
          ),
        ),
      );

      for (final cellId in kBoardCellIds) {
        await tester.tap(find.text(cellId));
        await tester.pump();
      }
      expect(tapped, orderedEquals(kBoardCellIds.toList()));
    });

    testWidgets('요약에 로스터 밖 키가 섞여 있어도 판은 10칸 그대로다', (tester) async {
      await tester.pumpWidget(
        host(
          StampBoard(
            board: {
              'gocheok_lg': BoardCell.forCount(count: 5), // 없는 짝
              'jamsil_doosan': BoardCell.forCount(count: 3),
            },
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final rendered = badges(tester);
      expect(rendered, hasLength(BadgeTokens.cellCount));
      expect(rendered.where((b) => b.stamps > 0).map((b) => b.stamps), [3]);
    });
  });

  group('StampBadge — 등급 임계의 사이 값', () {
    testWidgets('임계 사이 값도 토큰의 등급을 그대로 따른다 (2·9·아주 큰 수)', (tester) async {
      for (final entry in <int, BadgeTier>{
        1: BadgeTier.first,
        2: BadgeTier.first,
        3: BadgeTier.regular,
        9: BadgeTier.regular,
        10: BadgeTier.master,
        999: BadgeTier.master,
      }.entries) {
        await tester.pumpWidget(
          host(StampBadge(theme: TeamThemes.lotte, stamps: entry.key)),
        );
        expect(
          BadgeTierTokens.tierFor(entry.key),
          entry.value,
          reason: '토큰 자체의 임계 (1/3/10)',
        );
        expect(
          ringPainter(tester)!.layers,
          same(BadgeTierTokens.byTier[entry.value]!.rings),
          reason: '도장 ${entry.key}개',
        );
      }
    });

    test('도장 개수가 음수면 만들어지지 않는다', () {
      expect(
        () => StampBadge(theme: TeamThemes.lg, stamps: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('BadgeTierRingPainter — 실제로 그린 것', () {
    test('세 등급 모두 겹을 빠짐없이, 바깥에서 안쪽 순서로, 칸 안에 그린다', () {
      const size = Size(BadgeTokens.cellSize, BadgeTokens.cellSize);
      for (final style in BadgeTierTokens.byTier.values) {
        final canvas = _CircleRecorder();
        BadgeTierRingPainter(
          layers: style.rings,
          inset: BadgeTokens.tierRingInset,
        ).paint(canvas, size);

        expect(
          canvas.circles,
          hasLength(style.rings.length),
          reason: '${style.label}: 겹을 하나도 빠뜨리지 않는다',
        );
        // 색·굵기를 지어내지 않고 토큰 값 그대로 쓴다.
        expect(
          canvas.circles.map((c) => c.width).toList(),
          orderedEquals(style.rings.map((l) => l.width).toList()),
        );
        expect(
          canvas.circles.map((c) => c.color.toARGB32()).toList(),
          orderedEquals(style.rings.map((l) => l.color.toARGB32()).toList()),
        );

        // 바깥→안쪽: 반지름이 줄고, 겹끼리 틈 없이 맞닿는다.
        final outerEdge = canvas.circles.first.radius + canvas.circles.first.width / 2;
        expect(
          outerEdge,
          closeTo(size.width / 2 - BadgeTokens.tierRingInset, 1e-9),
          reason: '${style.label}: 링 바깥 끝이 inset 만큼만 안으로 들어온다',
        );
        expect(
          outerEdge,
          lessThanOrEqualTo(size.width / 2),
          reason: '${style.label}: 링이 칸 밖으로 나가지 않는다',
        );
        for (var i = 1; i < canvas.circles.length; i++) {
          final prev = canvas.circles[i - 1];
          final now = canvas.circles[i];
          expect(
            now.radius + now.width / 2,
            closeTo(prev.radius - prev.width / 2, 1e-9),
            reason: '${style.label}: 겹 $i 이 앞 겹과 틈 없이 맞닿는다',
          );
          expect(now.radius, lessThan(prev.radius));
        }
        // 가장 안쪽 겹까지 몸통 안에 남는다 (팀 색 한가운데가 살아 있다).
        expect(canvas.circles.last.radius - canvas.circles.last.width / 2, greaterThan(0));
      }
    });

    test('링이 다 들어가지 못하는 작은 칸에서도 터지지 않고 남는 겹만 그린다', () {
      final canvas = _CircleRecorder();
      BadgeTierRingPainter(
        layers: BadgeTierTokens.master.rings,
        inset: BadgeTokens.tierRingInset,
      ).paint(canvas, const Size(8, 8));

      expect(canvas.circles.length, lessThan(BadgeTierTokens.master.rings.length));
      expect(canvas.circles.every((c) => c.radius > 0), isTrue);
    });

    testWidgets('아주 작은 칸도 예외 없이 렌더된다', (tester) async {
      await tester.pumpWidget(
        host(const StampBadge(theme: TeamThemes.kt, stamps: 10, size: 8)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('MainTabScaffold — 시스템 뒤로가기', () {
    List<MainTab> tabs() => [
      MainTab(label: '홈', icon: Icons.home_rounded, builder: (_) => const _Root('홈')),
      MainTab(label: '배지', icon: Icons.star_rounded, builder: (_) => const _Root('배지')),
    ];

    testWidgets('보고 있는 탭의 스택만 되돌린다 (꺼진 탭은 그대로)', (tester) async {
      await tester.pumpWidget(MaterialApp(home: MainTabScaffold(tabs: tabs())));

      // 두 탭 모두 한 겹씩 들어간다.
      await tester.tap(find.text('홈 뿌리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('배지'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('배지 뿌리'));
      await tester.pumpAndSettle();
      expect(find.text('배지 상세'), findsOneWidget);

      // 시스템 뒤로가기 — 보고 있는 배지 탭이 되돌아가야 한다.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('배지 상세'), findsNothing);
      expect(find.text('배지 뿌리'), findsOneWidget);

      // 홈 탭의 스택은 손대지 않았다.
      await tester.tap(find.text('홈'));
      await tester.pumpAndSettle();
      expect(find.text('홈 상세'), findsOneWidget);
    });

    testWidgets('뿌리에서의 뒤로가기는 탭 스택을 건드리지 않는다', (tester) async {
      await tester.pumpWidget(MaterialApp(home: MainTabScaffold(tabs: tabs())));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('홈 뿌리'), findsOneWidget);
    });
  });

  group('LikeButton — 실패 뒤', () {
    testWidgets('실패로 되돌린 뒤에도 다음 탭이 다시 나간다 (대기 표시가 풀린다)', (tester) async {
      final sent = <bool>[];
      var shouldFail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LikeButton(
              liked: false,
              onChanged: (liked) async {
                sent.add(liked);
                if (shouldFail) throw StateError('첫 시도 실패');
              },
              onFailed: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(LikeButton));
      await tester.pumpAndSettle();
      expect(find.byIcon(LikeButton.unlikedIcon), findsOneWidget);

      shouldFail = false;
      await tester.tap(find.byType(LikeButton));
      await tester.pumpAndSettle();
      expect(sent, <bool>[true, true]);
      expect(find.byIcon(LikeButton.likedIcon), findsOneWidget);
    });

    testWidgets('응답 전에 화면에서 사라져도 예외가 나지 않는다', (tester) async {
      var failures = 0;
      Future<void> write(bool liked) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw StateError('늦게 실패');
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LikeButton(
              liked: false,
              onChanged: write,
              onFailed: (_) => failures++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(LikeButton));
      await tester.pump();

      // 버튼을 트리에서 걷어낸 뒤 쓰기가 실패한다.
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(failures, 1, reason: '되돌릴 화면이 없어도 실패는 알린다');
    });
  });

  testWidgets('ContentFallback — 로딩 중이면 재시도 경로가 있어도 버튼을 두지 않는다', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(ContentFallback(loading: true, onRetry: () {})),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(ContentFallback.retryLabel), findsNothing);
  });
}

class _Root extends StatelessWidget {
  const _Root(this.name);

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
