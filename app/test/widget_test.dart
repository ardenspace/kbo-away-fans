import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/main.dart';

void main() {
  testWidgets('앱이 부팅되고 홈 화면이 렌더된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KboAwayApp()));
    await tester.pumpAndSettle();

    expect(find.text('KBO 원정팬'), findsWidgets);
    expect(find.text('원정 일정 보기'), findsOneWidget);
    expect(find.text('내 스탬프'), findsOneWidget);
  });
}
