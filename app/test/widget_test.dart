import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // 라우터가 Supabase.instance(세션 게이팅)에 의존하므로 더미 자격증명으로 초기화.
  // 네트워크는 타지 않고 로컬 세션(없음)만 본다 → currentSession == null.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('미인증 부팅은 auth 게이트로 로그인 화면을 렌더한다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KboAwayApp()));
    await tester.pumpAndSettle();

    // 세션 없음 → redirect 가 /login 으로. 로그인 화면 마커 확인.
    expect(find.text('카카오로 시작'), findsOneWidget);
    expect(find.text('계정 만들기'), findsOneWidget);
  });
}
