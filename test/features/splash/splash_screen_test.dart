/// 스플래시 연출 위젯 테스트 — 실밥 분리와 로고 등장의 계약을 고정한다.
///
/// 거리·시간 값은 전부 [SplashTokens] 에서 오므로 테스트도 리터럴 대신
/// 토큰을 참조한다. 토큰을 조정해도 이 테스트는 그대로 통과해야 한다
/// (검증하는 것은 "얼마나" 가 아니라 "어느 방향으로, 어떤 순서로" 이다).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/splash/splash_screen.dart';

void main() {
  Widget host({VoidCallback? onComplete}) => MaterialApp(
        home: SplashScreen(onComplete: onComplete ?? () {}),
      );

  double topSeamEdge(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(SplashScreen.seamTopKey)).dy;

  double bottomSeamEdge(WidgetTester tester) =>
      tester.getBottomLeft(find.byKey(SplashScreen.seamBottomKey)).dy;

  testWidgets('실밥 두 가닥과 로고가 모두 렌더된다', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byKey(SplashScreen.seamTopKey), findsOneWidget);
    expect(find.byKey(SplashScreen.seamBottomKey), findsOneWidget);
    expect(find.byKey(SplashScreen.logoKey), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('벌어지기 직전 실밥이 안쪽으로 살짝 움츠린다', (tester) async {
    await tester.pumpWidget(host());
    final topStart = topSeamEdge(tester);
    final bottomStart = bottomSeamEdge(tester);

    await tester.pump(SplashTokens.seamAnticipation);

    // 반동 구간 끝 — 위 실밥은 내려오고 아래 실밥은 올라와 사이가 좁아진다.
    expect(topSeamEdge(tester), greaterThan(topStart));
    expect(bottomSeamEdge(tester), lessThan(bottomStart));

    await tester.pumpAndSettle();
  });

  testWidgets('실밥은 최종적으로 서로 반대 방향으로 벌어진다', (tester) async {
    await tester.pumpWidget(host());
    final topStart = topSeamEdge(tester);
    final bottomStart = bottomSeamEdge(tester);

    await tester.pumpAndSettle();

    expect(
      topSeamEdge(tester),
      lessThan(topStart),
      reason: '위 실밥은 위로 올라가 화면 위쪽으로 벌어져야 한다',
    );
    expect(
      bottomSeamEdge(tester),
      greaterThan(bottomStart),
      reason: '아래 실밥은 아래로 내려가 화면 아래쪽으로 벌어져야 한다',
    );
  });

  testWidgets('위 실밥은 왼쪽으로, 아래 실밥은 오른쪽으로 미끄러진다', (tester) async {
    await tester.pumpWidget(host());
    final topStart = tester.getTopLeft(find.byKey(SplashScreen.seamTopKey)).dx;
    final bottomStart =
        tester.getTopLeft(find.byKey(SplashScreen.seamBottomKey)).dx;

    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(SplashScreen.seamTopKey)).dx,
      lessThan(topStart),
      reason: '위 실밥은 왼쪽으로 가야 한다',
    );
    expect(
      tester.getTopLeft(find.byKey(SplashScreen.seamBottomKey)).dx,
      greaterThan(bottomStart),
      reason: '아래 실밥은 오른쪽으로 가야 한다',
    );
  });

  testWidgets('미끄러지는 동안에도 실밥이 화면 폭을 늘 덮는다', (tester) async {
    await tester.pumpWidget(host());
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;

    // 여유분(seamOverscan)이 이동 거리(seamDriftFactor)보다 작아지면
    // 가장자리에 배경이 드러난다. 두 토큰의 관계를 여기서 지킨다.
    const step = Duration(milliseconds: 50);
    for (var elapsed = Duration.zero;
        elapsed <= SplashScreen.totalDuration;
        elapsed += step) {
      for (final key in [SplashScreen.seamTopKey, SplashScreen.seamBottomKey]) {
        final finder = find.byKey(key);
        final xs = [
          tester.getTopLeft(finder).dx,
          tester.getTopRight(finder).dx,
          tester.getBottomLeft(finder).dx,
          tester.getBottomRight(finder).dx,
        ];
        expect(
          xs.reduce((a, b) => a < b ? a : b),
          lessThanOrEqualTo(0.5),
          reason: '$key @ $elapsed 왼쪽 끝이 화면을 덮지 못한다',
        );
        expect(
          xs.reduce((a, b) => a > b ? a : b),
          greaterThanOrEqualTo(screenWidth - 0.5),
          reason: '$key @ $elapsed 오른쪽 끝이 화면을 덮지 못한다',
        );
      }
      await tester.pump(step);
    }

    await tester.pumpAndSettle();
  });

  testWidgets('로고는 크기 0 에서 시작해 제 크기로 커진다', (tester) async {
    await tester.pumpWidget(host());

    expect(
      tester.getRect(find.byKey(SplashScreen.logoKey)).width,
      lessThan(1),
      reason: '등장 전에는 크기가 0 이라 화면에서 폭을 차지하지 않는다',
    );

    await tester.pumpAndSettle();

    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(
      tester.getRect(find.byKey(SplashScreen.logoKey)).width,
      closeTo(screenWidth * SplashTokens.logoWidthFactor, 1),
      reason: '연출이 끝나면 로고 폭은 화면 폭 대비 토큰 비율과 같아야 한다',
    );
  });

  testWidgets('로고 등장은 실밥이 벌어지기 시작한 뒤로 미뤄진다', (tester) async {
    await tester.pumpWidget(host());

    // 반동이 끝나 실밥이 벌어지기 시작한 시점 — 로고는 아직 나오지 않았다.
    await tester.pump(SplashTokens.seamAnticipation);
    expect(tester.getRect(find.byKey(SplashScreen.logoKey)).width, lessThan(1));

    await tester.pump(SplashTokens.logoDelay + SplashTokens.logoPop);
    expect(
      tester.getRect(find.byKey(SplashScreen.logoKey)).width,
      greaterThan(1),
      reason: '지연이 지나면 로고가 등장해 있어야 한다',
    );

    await tester.pumpAndSettle();
  });

  testWidgets('연출이 끝나면 onComplete 가 정확히 한 번 호출된다', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(onComplete: () => calls++));

    expect(calls, 0, reason: '연출 중에는 호출되지 않는다');

    await tester.pumpAndSettle();

    expect(calls, 1);
  });
}
