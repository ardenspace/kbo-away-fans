/// LikeButton 위젯 테스트 — 낙관적 반영의 계약:
/// 누르는 즉시 모습이 바뀌고, 쓰기가 실패하면 눌리기 전 모습으로 되돌아온다.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/ui/shared/like_button.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

bool isLiked(WidgetTester tester) =>
    find.byIcon(LikeButton.likedIcon).evaluate().isNotEmpty;

void main() {
  testWidgets('꺼진 상태로 렌더하고 누르면 즉시 켜진 모습이 된다 (응답 전)', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      host(LikeButton(liked: false, onChanged: (_) => gate.future)),
    );

    expect(tester.takeException(), isNull);
    expect(isLiked(tester), isFalse);

    await tester.tap(find.byType(LikeButton));
    await tester.pump();
    expect(isLiked(tester), isTrue, reason: '응답을 기다리지 않고 먼저 반영한다');

    gate.complete();
    await tester.pump();
    expect(isLiked(tester), isTrue);
  });

  testWidgets('쓰기가 실패하면 눌리기 전 모습으로 되돌리고 실패를 알린다', (tester) async {
    final gate = Completer<void>();
    Object? reported;
    await tester.pumpWidget(
      host(
        LikeButton(
          liked: false,
          onChanged: (_) => gate.future,
          onFailed: (error) => reported = error,
        ),
      ),
    );

    await tester.tap(find.byType(LikeButton));
    await tester.pump();
    expect(isLiked(tester), isTrue);

    gate.completeError(StateError('네트워크 없음'));
    await tester.pumpAndSettle();
    expect(isLiked(tester), isFalse, reason: '실패했으므로 되돌린다');
    expect(reported, isA<StateError>());
    expect(tester.takeException(), isNull, reason: '실패는 콜백으로만 나간다');
  });

  testWidgets('응답을 기다리는 동안 두 번째 탭을 무시한다', (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      host(
        LikeButton(
          liked: false,
          onChanged: (_) {
            calls++;
            return gate.future;
          },
        ),
      ),
    );

    await tester.tap(find.byType(LikeButton));
    await tester.pump();
    await tester.tap(find.byType(LikeButton));
    await tester.pump();
    expect(calls, 1);

    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('켜진 상태의 색은 팔레트의 강조색에서 온다', (tester) async {
    await tester.pumpWidget(
      host(LikeButton(liked: true, onChanged: (_) async {})),
    );

    final icon = tester.widget<Icon>(find.byIcon(LikeButton.likedIcon));
    expect(icon.color, ColorTokens.danger);
  });

  testWidgets('바깥에서 상태가 바뀌면 따라간다', (tester) async {
    await tester.pumpWidget(
      host(LikeButton(liked: false, onChanged: (_) async {})),
    );
    expect(isLiked(tester), isFalse);

    await tester.pumpWidget(
      host(LikeButton(liked: true, onChanged: (_) async {})),
    );
    expect(isLiked(tester), isTrue);
  });
}
