/// Task 2.6 — 홈 "원정 지도" 버튼 → /map 라우트(MapView) 위젯 테스트 (R9).
///
/// 실 Supabase/네이티브 미접촉: favoriteTeam 은 fake notifier override 로 "팀 없음"
/// 고정, 지도 데이터·위치는 fake repository/override 로 주입한다. 라우트는 테스트용
/// GoRouter 로 홈 + /map 만 배선해 버튼 탭 → 경로 변경 → MapView 렌더(예외 없음)를
/// 검증한다. (기존 홈 버튼 회귀 없음도 함께 확인.)
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kbo_away_fans/features/map/map_screen.dart';
import 'package:kbo_away_fans/features/stamp/location_provider.dart';
import 'package:kbo_away_fans/features/stamp/stamp_repository.dart';
import 'package:kbo_away_fans/features/stamp/stadium_repository.dart';
import 'package:kbo_away_fans/features/team/favorite_team_provider.dart';
import 'package:kbo_away_fans/features/team/team.dart';
import 'package:kbo_away_fans/router/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/stamp/fakes.dart';

/// favoriteTeam 을 실 Supabase 없이 "팀 없음" 으로 고정하는 fake notifier.
class _NoTeam extends FavoriteTeam {
  @override
  Future<Team?> build() async => null;
}

GoRouter _testRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        GoRoute(path: '/map', builder: (_, _) => const MapView()),
      ],
    );

Widget _app(GoRouter router) => ProviderScope(
      overrides: [
        favoriteTeamProvider.overrideWith(_NoTeam.new),
        stadiumRepositoryProvider.overrideWithValue(FakeStadiumRepository()),
        stampRepositoryProvider.overrideWithValue(FakeStampRepository()),
        currentLocationProvider.overrideWith(
          (ref) async => const LocationServiceDisabled(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );

void main() {
  testWidgets('홈에 "원정 지도" 버튼이 있고 기존 홈 버튼도 유지된다 (R9)', (tester) async {
    await tester.pumpWidget(_app(_testRouter()));
    await tester.pumpAndSettle();

    expect(find.text('원정 지도'), findsOneWidget);
    // 기존 홈 버튼 회귀 없음.
    expect(find.text('내 스탬프'), findsOneWidget);
    expect(find.text('원정 일정 보기'), findsOneWidget);
  });

  testWidgets('"원정 지도" 탭 → /map 으로 이동해 MapView 를 렌더한다 (예외 없음) (R9)',
      (tester) async {
    final router = _testRouter();
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.byType(MapView), findsNothing); // 아직 홈 화면.

    await tester.tap(find.text('원정 지도'));
    await tester.pumpAndSettle();

    // 라우트가 /map 으로 바뀌어 MapView 가 렌더된다.
    expect(router.routerDelegate.currentConfiguration.uri.path, '/map');
    expect(find.byType(MapView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
