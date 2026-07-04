import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/map/naver_map_config.dart';
import 'router/router.dart';
import 'shared/theme/team_theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  assert(
    supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty,
    'SUPABASE_URL / SUPABASE_ANON_KEY 가 비어 있습니다. '
    'flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... 로 실행하세요.',
  );

  // NCP_MAP_CLIENT_ID 는 SUPABASE_* 와 같은 주입 컨벤션을 따르되, 미주입이어도
  // crash 시키지 않는다 — 지도 화면만 안내 텍스트로 degrade 하고 나머지(스탬프
  // 등)는 정상 동작한다 (R12). 개발 중 누락을 알 수 있도록 debug 경고만 남긴다.
  assert(() {
    if (shouldDegradeMap(ncpMapClientId)) {
      debugPrint(
        'NCP_MAP_CLIENT_ID 미주입 — 지도 화면은 안내 텍스트로 degrade 됩니다. '
        'flutter run --dart-define=NCP_MAP_CLIENT_ID=... 로 실키를 주입하세요.',
      );
    }
    return true;
  }());

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );
  runApp(const ProviderScope(child: KboAwayApp()));
}

class KboAwayApp extends ConsumerWidget {
  const KboAwayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final theme = ref.watch(teamThemeProvider);
    return MaterialApp.router(
      title: 'KBO 원정팬',
      theme: theme,
      routerConfig: router,
    );
  }
}
