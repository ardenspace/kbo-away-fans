import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/go_router_refresh_stream.dart';
import '../core/supabase_client.dart';
import '../features/auth/login_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/stadium/stadium_screen.dart';
import '../features/stamp/stamp_screen.dart';
import '../features/team/team_select_screen.dart';
import 'home_screen.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  final refresh = GoRouterRefreshStream(client.auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn) return onLogin ? null : '/login';
      if (onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/schedule', builder: (_, _) => const ScheduleScreen()),
      GoRoute(path: '/team-select', builder: (_, _) => const TeamSelectScreen()),
      GoRoute(
        path: '/stadium/:id',
        builder: (_, state) => StadiumScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/stamp', builder: (_, _) => const StampScreen()),
    ],
  );
}
