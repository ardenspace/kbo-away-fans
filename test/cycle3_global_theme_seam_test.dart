import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/features/profile/theme_settings.dart';
import 'package:kbo_away_fans/features/team_select/selected_team.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/ui/shared/main_tab_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend/fake_backend.dart';
import 'location/fake_location_permission_gateway.dart';

// Each route must actually rebuild from its inherited Theme, including routes
// in inactive tabs. Reading only Theme.of from the test would miss a stale UI.
class _ThemeReadingRoute extends StatefulWidget {
  const _ThemeReadingRoute({super.key});

  @override
  State<_ThemeReadingRoute> createState() => _ThemeReadingRouteState();
}

class _ThemeReadingRouteState extends State<_ThemeReadingRoute> {
  late ThemeData theme;

  @override
  Widget build(BuildContext context) {
    theme = Theme.of(context);
    return Scaffold(body: Text('route', style: theme.textTheme.bodyMedium));
  }
}

void main() {
  testWidgets('앱 루트 테마가 다섯 탭과 유지된/새 route에 함께 전달된다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    const uid = 'global-theme-user';
    final auth = FakeAuthService(signedIn: const AuthUser(uid: uid));
    final store = FakeUserDataStore();
    await store.createProfile(
      uid,
      const NewUserProfile(
        nickname: '원정러',
        favoriteTeamId: 'lg',
        defaultThemeFamily: DefaultThemeFamily.b,
        brightnessPreference: BrightnessPreference.light,
      ),
    );
    Map<String, Object?> read(String name) =>
        jsonDecode(File('content-pipeline/data/$name.json').readAsStringSync())
            as Map<String, Object?>;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(
          () => DateTime.parse('2026-09-12T12:00:00+09:00'),
        ),
        locationPermissionGatewayProvider.overrideWithValue(
          FakeLocationPermissionGateway(
            initial: LocationPermissionStatus.denied,
          ),
        ),
        teamsProvider.overrideWith(
          (_) async => ContentFresh(TeamsDocument.fromJson(read('teams'))),
        ),
        stadiumsProvider.overrideWith(
          (_) async =>
              ContentFresh(StadiumsDocument.fromJson(read('stadiums'))),
        ),
        placesProvider.overrideWith(
          (_) async => ContentFresh(PlacesDocument.fromJson(read('places'))),
        ),
        scheduleProvider.overrideWith(
          (_) async => ContentFresh(
            ScheduleDocument(generatedAt: DateTime.utc(2026), games: const []),
          ),
        ),
      ],
    );
    addTearDown(auth.dispose);
    addTearDown(store.dispose);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KboAwayFansApp(),
      ),
    );
    await tester.pumpAndSettle();

    final tabFinder = find.byType(MainTabScaffold);
    final tabState = tester.state(tabFinder);
    final navigators = tester
        .stateList<NavigatorState>(
          find.descendant(
            of: tabFinder,
            matching: find.byType(Navigator, skipOffstage: false),
            skipOffstage: false,
          ),
        )
        .toList();
    expect(navigators, hasLength(5));
    final roots = navigators.map((navigator) => navigator.context).toList();
    final routes = <GlobalKey<_ThemeReadingRouteState>>[];

    Future<void> pushInEveryTab() async {
      for (final navigator in navigators) {
        final key = GlobalKey<_ThemeReadingRouteState>();
        routes.add(key);
        unawaited(
          navigator.push<void>(
            MaterialPageRoute(builder: (_) => _ThemeReadingRoute(key: key)),
          ),
        );
      }
      await tester.pumpAndSettle();
    }

    void expectSharedTheme({bool settled = true}) {
      final rootTheme = Theme.of(tester.element(tabFinder));
      final visual = rootTheme.extension<AppVisualTheme>()!;
      if (settled) {
        final expected = container.read(appVisualThemeProvider);
        expect(visual.primary, expected.primary);
        expect(visual.background, expected.background);
        expect(visual.brightness, expected.brightness);
      }
      expect(tester.state(tabFinder), same(tabState));
      for (final context in roots) {
        expect(context.mounted, isTrue);
        expect(Theme.of(context), rootTheme);
      }
      for (final key in routes) {
        expect(key.currentState, isNotNull);
        expect(key.currentState!.theme, rootTheme);
      }
      final bar = find.byType(BottomNavigationBar);
      final shell = tester.widget<Scaffold>(
        find.ancestor(of: bar, matching: find.byType(Scaffold)).first,
      );
      expect(
        shell.backgroundColor ?? rootTheme.scaffoldBackgroundColor,
        visual.background,
      );
      expect(
        find.descendant(
          of: bar,
          matching: find.byWidgetPredicate(
            (widget) => widget is Material && widget.color == visual.surface,
          ),
        ),
        findsOneWidget,
      );
      final icons = tester
          .elementList(find.descendant(of: bar, matching: find.byType(Icon)))
          .toList();
      final selectedNavigation =
          rootTheme.bottomNavigationBarTheme.selectedItemColor!;
      expect(IconTheme.of(icons.first).color, selectedNavigation);
      for (final icon in icons.skip(1)) {
        expect(IconTheme.of(icon).color, visual.textSecondary);
      }
      final labels = tester
          .elementList(find.descendant(of: bar, matching: find.byType(Text)))
          .toList();
      expect(DefaultTextStyle.of(labels.first).style.color, selectedNavigation);
      for (final label in labels.skip(1)) {
        expect(DefaultTextStyle.of(label).style.color, visual.textSecondary);
      }
      expect(tester.takeException(), isNull);
    }

    expectSharedTheme();
    await pushInEveryTab();
    expectSharedTheme();

    for (final team in <String?>['samsung', null]) {
      await container
          .read(selectedTeamIdProvider.notifier)
          .select(team, isChange: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expectSharedTheme(settled: false);
      await tester.pumpAndSettle();
      expectSharedTheme();
      await pushInEveryTab();
      expectSharedTheme();
    }

    await container
        .read(themeSettingsProvider.notifier)
        .setBrightnessMode(ThemeMode.dark);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expectSharedTheme(settled: false);
    await tester.pumpAndSettle();
    expectSharedTheme();
    await pushInEveryTab();
    expectSharedTheme();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
