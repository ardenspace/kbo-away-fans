import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('앱 루트 위젯이 렌더된다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KboAwayFansApp()));

    expect(find.byType(KboAwayFansApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('포그라운드 복귀(resumed) 시 콘텐츠 provider 가 다시 로드된다',
      (tester) async {
    const issue = ContentIssue(ContentIssueKind.network, 'test fixture');
    var teamLoads = 0;
    final container = ProviderContainer(
      overrides: [
        teamsProvider.overrideWith((ref) async {
          teamLoads++;
          return const ContentUnavailable<TeamsDocument>(issue);
        }),
        // 나머지 3종도 override — invalidateContent 가 실 IO 를 타지 않게.
        stadiumsProvider.overrideWith(
          (ref) async => const ContentUnavailable<StadiumsDocument>(issue),
        ),
        placesProvider.overrideWith(
          (ref) async => const ContentUnavailable<PlacesDocument>(issue),
        ),
        scheduleProvider.overrideWith(
          (ref) async => const ContentUnavailable<ScheduleDocument>(issue),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KboAwayFansApp(),
      ),
    );

    // 화면 구독과 같은 조건을 만들기 위한 활성 리스너 —
    // 리스너가 있어야 invalidate 가 즉시 재실행으로 이어진다.
    final sub = container.listen(teamsProvider, (previous, next) {});
    addTearDown(sub.close);
    await container.read(teamsProvider.future);
    expect(teamLoads, 1);

    // 백그라운드 → 포그라운드 전이를 바인딩에 직접 통지.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await container.read(teamsProvider.future);

    expect(teamLoads, 2);
  });

  testWidgets('앱은 스플래시로 시작하고, 연출이 끝나면 루트 게이트로 넘어간다',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    const issue = ContentIssue(ContentIssueKind.network, 'test fixture');

    await tester.pumpWidget(
      ProviderScope(
        // 콘텐츠 4종을 override — 실 IO 는 위젯 테스트의 fake async 안에서
        // 끝나지 않아 pumpAndSettle 이 멈춘다.
        overrides: [
          teamsProvider.overrideWith(
            (ref) async => const ContentUnavailable<TeamsDocument>(issue),
          ),
          stadiumsProvider.overrideWith(
            (ref) async => const ContentUnavailable<StadiumsDocument>(issue),
          ),
          placesProvider.overrideWith(
            (ref) async => const ContentUnavailable<PlacesDocument>(issue),
          ),
          scheduleProvider.overrideWith(
            (ref) async => const ContentUnavailable<ScheduleDocument>(issue),
          ),
        ],
        child: const KboAwayFansApp(),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(RootGate), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(RootGate), findsOneWidget);
  });
}
