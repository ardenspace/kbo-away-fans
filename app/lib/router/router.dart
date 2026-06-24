import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/stadium/stadium_screen.dart';
import '../features/stamp/stamp_screen.dart';
import 'home_screen.dart';

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/',         builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/schedule', builder: (_, _) => const ScheduleScreen()),
      GoRoute(
        path: '/stadium/:id',
        builder: (_, state) =>
            StadiumScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/stamp',    builder: (_, _) => const StampScreen()),
    ],
  ),
);
