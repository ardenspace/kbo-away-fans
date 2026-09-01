/// SocialSignInButton 위젯 테스트 — 제공자 셋이 한 모양으로 서고,
/// 무엇으로 로그인하는지는 문구와 아이콘이 가른다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/ui/shared/social_sign_in_button.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('세 제공자 모두 예외 없이 렌더되고 문구가 서로 다르다', (tester) async {
    final labels = <String>{};
    for (final provider in AuthProviderId.values) {
      await tester.pumpWidget(
        host(SocialSignInButton(provider: provider, onPressed: () {})),
      );
      expect(tester.takeException(), isNull);

      final label = SocialSignInButton.labelOf(provider);
      expect(find.text(label), findsOneWidget);
      expect(find.byIcon(SocialSignInButton.iconOf(provider)), findsOneWidget);
      labels.add(label);
    }

    expect(labels, hasLength(AuthProviderId.values.length));
  });

  testWidgets('누르면 콜백이 그 제공자로 불린다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        SocialSignInButton(
          provider: AuthProviderId.kakao,
          onPressed: () => taps++,
        ),
      ),
    );

    await tester.tap(find.byType(SocialSignInButton));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('onPressed 가 없으면 눌리지 않는다 (로그인 진행 중)', (tester) async {
    await tester.pumpWidget(
      host(const SocialSignInButton(provider: AuthProviderId.google)),
    );

    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('busy 면 아이콘 자리가 스피너가 된다 (문구는 그대로)', (tester) async {
    const provider = AuthProviderId.kakao;
    await tester.pumpWidget(
      host(const SocialSignInButton(provider: provider, busy: true)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byIcon(SocialSignInButton.iconOf(provider)),
      findsNothing,
      reason: '스피너가 아이콘 옆에 붙으면 버튼의 글자가 밀린다',
    );
    expect(find.text(SocialSignInButton.labelOf(provider)), findsOneWidget);
  });

  testWidgets('busy 가 아니면 스피너가 없다', (tester) async {
    await tester.pumpWidget(
      host(SocialSignInButton(provider: AuthProviderId.apple, onPressed: () {})),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
