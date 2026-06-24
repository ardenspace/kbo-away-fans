import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/stadium/stadium_screen.dart';
import '../features/stamp/stamp_screen.dart';
import 'home_screen.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/schedule', builder: (_, _) => const ScheduleScreen()),
    GoRoute(
      path: '/stadium/:id',
      builder: (_, state) => StadiumScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(path: '/stamp', builder: (_, _) => const StampScreen()),
  ],
);
