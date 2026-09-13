import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';

void main() {
  testWidgets('PlaceCard가 예외 없이 렌더된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlaceCard(
            name: '사직 돼지국밥',
            categoryLabel: '맛집',
            shoutoutSource: '@busan_foodie',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('사직 돼지국밥'), findsOneWidget);
    expect(find.text('@busan_foodie'), findsOneWidget);
  });

  for (final width in <double>[143, 167]) {
    testWidgets('$width 너비에서도 카테고리와 샤라웃 출처가 넘치지 않는다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              child: SizedBox(
                width: width,
                child: const PlaceCard(
                  name: '사직 돼지국밥',
                  categoryLabel: '맛집',
                  shoutoutSource: '@busan_foodie',
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('맛집'), findsOneWidget);
      expect(find.text('@busan_foodie'), findsOneWidget);
    });
  }

  testWidgets('390 화면의 홈 미리보기에서도 긴 샤라웃 출처가 넘치지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390 - SpaceTokens.xxl,
            height: SpaceTokens.xxl * 4,
            child: Padding(
              padding: EdgeInsets.only(
                right: SpaceTokens.md,
                bottom: SpaceTokens.md,
              ),
              child: PlaceCard(
                name: '부농정육식당',
                categoryLabel: '맛집',
                shoutoutSource: "LG·두산 선수들 단골 — 에스콰이어 '선수 Pick' 소개",
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
