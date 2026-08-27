/// 스플래시 연출 위젯 테스트 — 로고 착지와 실밥 진입의 계약을 고정한다.
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
  Widget host({VoidCallback? onComplete}) =>
      MaterialApp(home: SplashScreen(onComplete: onComplete ?? () {}));

  double screenWidthOf(WidgetTester tester) =>
      tester.view.physicalSize.width / tester.view.devicePixelRatio;

  Rect seamRect(WidgetTester tester, Key key) =>
      tester.getRect(find.byKey(key));

  double logoWidth(WidgetTester tester) =>
      tester.getRect(find.byKey(SplashScreen.logoKey)).width;

  double logoOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find.ancestor(
          of: find.byKey(SplashScreen.logoKey),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;

  bool logoIsBlurred(WidgetTester tester) => find
      .ancestor(
        of: find.byKey(SplashScreen.logoKey),
        matching: find.byType(ImageFiltered),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets('실밥 두 가닥과 로고가 모두 렌더된다', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byKey(SplashScreen.seamTopKey), findsOneWidget);
    expect(find.byKey(SplashScreen.seamBottomKey), findsOneWidget);
    expect(find.byKey(SplashScreen.logoKey), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('착지 전까지 실밥은 화면 밖에 있어 보이지 않는다', (tester) async {
    await tester.pumpWidget(host());
    final screenWidth = screenWidthOf(tester);

    // 시작 직후와 착지 직전, 두 시점 모두 화면 안에 걸치지 않아야 한다.
    // 착지 "정확히 그 순간" 이 아니라 직전을 보는 이유는, 그 순간의 프레임은
    // 이미 진입이 시작된 뒤라 부동소수점 수준으로 조금 들어와 있기 때문이다.
    for (final elapsed in [
      Duration.zero,
      SplashScreen.impactAt - const Duration(milliseconds: 1),
    ]) {
      if (elapsed > Duration.zero) await tester.pump(elapsed);

      expect(
        seamRect(tester, SplashScreen.seamTopKey).right,
        lessThanOrEqualTo(0.5),
        reason: '위 실밥은 화면 왼쪽 밖에 대기한다 @ $elapsed',
      );
      expect(
        seamRect(tester, SplashScreen.seamBottomKey).left,
        greaterThanOrEqualTo(screenWidth - 0.5),
        reason: '아래 실밥은 화면 오른쪽 밖에 대기한다 @ $elapsed',
      );
    }

    await tester.pumpAndSettle();
  });

  testWidgets('위 실밥은 왼쪽에서, 아래 실밥은 오른쪽에서 들어온다', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(SplashScreen.impactAt);

    final topStart = seamRect(tester, SplashScreen.seamTopKey).left;
    final bottomStart = seamRect(tester, SplashScreen.seamBottomKey).left;

    await tester.pumpAndSettle();

    expect(
      seamRect(tester, SplashScreen.seamTopKey).left,
      greaterThan(topStart),
      reason: '위 실밥은 오른쪽으로 밀려 들어와야 한다',
    );
    expect(
      seamRect(tester, SplashScreen.seamBottomKey).left,
      lessThan(bottomStart),
      reason: '아래 실밥은 왼쪽으로 밀려 들어와야 한다',
    );
  });

  testWidgets('실밥은 seamSlantSlope 가 정한 각도로 들어온다', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(SplashScreen.impactAt);

    final topStart = seamRect(tester, SplashScreen.seamTopKey);
    final bottomStart = seamRect(tester, SplashScreen.seamBottomKey);

    await tester.pumpAndSettle();

    final topRest = seamRect(tester, SplashScreen.seamTopKey);
    final bottomRest = seamRect(tester, SplashScreen.seamBottomKey);

    // 세로 이동량은 가로 이동량에 기울기를 곱한 값이어야 한다.
    // 기울기가 0 이면 세로로는 전혀 움직이지 않는다는 뜻이 된다.
    final travel = (topRest.left - topStart.left).abs();
    final expectedShift = -SplashTokens.seamSlantSlope * travel;

    expect(
      topStart.top - topRest.top,
      closeTo(expectedShift, 1),
      reason: '위 실밥의 진입 각도가 토큰과 어긋난다',
    );
    expect(
      bottomRest.bottom - bottomStart.bottom,
      closeTo(expectedShift, 1),
      reason: '아래 실밥의 진입 각도가 토큰과 어긋난다 (위와 대칭이어야 한다)',
    );
  });

  testWidgets('들어오기를 마치면 두 실밥이 화면 폭을 덮는다', (tester) async {
    await tester.pumpWidget(host());
    final screenWidth = screenWidthOf(tester);

    await tester.pumpAndSettle();

    for (final key in [SplashScreen.seamTopKey, SplashScreen.seamBottomKey]) {
      final rect = seamRect(tester, key);
      expect(rect.left, lessThanOrEqualTo(0.5), reason: '$key 왼쪽 끝');
      expect(
        rect.right,
        greaterThanOrEqualTo(screenWidth - 0.5),
        reason: '$key 오른쪽 끝',
      );
    }
  });

  testWidgets('로고는 코앞에 크게 떠 있다가 제 크기로 꽂힌다', (tester) async {
    await tester.pumpWidget(host());
    final restWidth = screenWidthOf(tester) * SplashTokens.logoWidthFactor;

    expect(
      logoWidth(tester),
      greaterThan(restWidth * 2),
      reason: '보는 사람 코앞에서 출발하므로 처음에는 제 크기보다 훨씬 크다',
    );

    await tester.pumpAndSettle();

    expect(
      logoWidth(tester),
      closeTo(restWidth, 1),
      reason: '착지하면 로고 폭은 화면 폭 대비 토큰 비율과 같아야 한다',
    );
  });

  testWidgets('로고는 날아드는 동안 흐렸다가 착지하면 또렷해진다', (tester) async {
    await tester.pumpWidget(host());

    expect(
      logoIsBlurred(tester),
      isTrue,
      reason: '아직 멀리 있는 동안에는 흐림이 걸려 있다',
    );

    await tester.pump(SplashScreen.impactAt);

    expect(
      logoIsBlurred(tester),
      isFalse,
      reason: '착지하면 흐림이 0 이라 필터 자체를 걷어낸다',
    );

    await tester.pumpAndSettle();
  });

  testWidgets('로고는 지연이 지난 뒤에야 보이기 시작한다', (tester) async {
    await tester.pumpWidget(host());

    expect(logoOpacity(tester), 0, reason: '시작할 때는 완전히 투명하다');

    await tester.pump(SplashTokens.logoDelay);
    expect(
      logoOpacity(tester),
      closeTo(0, 0.01),
      reason: '지연이 끝나는 시점까지도 사실상 투명하다',
    );

    await tester.pump(SplashTokens.logoSlam);
    expect(logoOpacity(tester), 1, reason: '착지 시점에는 완전히 또렷하다');

    await tester.pumpAndSettle();
  });

  testWidgets('착지 순간부터 화면이 흔들렸다가 제자리로 돌아온다', (tester) async {
    await tester.pumpWidget(host());
    final restCenter = tester.getRect(find.byKey(SplashScreen.logoKey)).center;

    // 착지 직전까지는 흔들리지 않는다 (로고는 화면 중앙에 그대로 있다).
    // 충돌 순간 변위가 0 이 아니면 화면이 툭 튀므로 두 축 모두 확인한다.
    await tester.pump(SplashScreen.impactAt);
    final atImpact = tester.getRect(find.byKey(SplashScreen.logoKey)).center;
    expect(
      atImpact.dx,
      closeTo(restCenter.dx, 0.5),
      reason: '충격 순간 가로로 튀면 안 된다',
    );
    expect(
      atImpact.dy,
      closeTo(restCenter.dy, 0.5),
      reason: '충격 순간 세로로 튀면 안 된다',
    );

    // 흔들림 구간을 훑어 가장 크게 벗어난 정도를 잰다.
    const step = Duration(milliseconds: 20);
    var peak = 0.0;
    for (
      var elapsed = Duration.zero;
      elapsed < SplashTokens.shake;
      elapsed += step
    ) {
      await tester.pump(step);
      final dy =
          (tester.getRect(find.byKey(SplashScreen.logoKey)).center.dy -
                  restCenter.dy)
              .abs();
      if (dy > peak) peak = dy;
    }

    expect(peak, greaterThan(1), reason: '착지 후에는 화면이 눈에 띄게 흔들려야 한다');

    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(SplashScreen.logoKey)).center.dy,
      closeTo(restCenter.dy, 0.01),
      reason: '흔들림이 잦아들면 정확히 제자리로 돌아온다',
    );
  });

  testWidgets('연출이 끝나면 onComplete 가 정확히 한 번 호출된다', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(onComplete: () => calls++));

    expect(calls, 0, reason: '연출 중에는 호출되지 않는다');

    await tester.pumpAndSettle();

    expect(calls, 1);
  });
}
