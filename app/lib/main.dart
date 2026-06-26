import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
