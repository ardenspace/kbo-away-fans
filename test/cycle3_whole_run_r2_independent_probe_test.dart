import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/features/profile/theme_settings.dart';
import 'package:kbo_away_fans/features/splash/splash_screen.dart';
import 'package:kbo_away_fans/features/team_select/selected_team.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend/fake_backend.dart';

const bd = ThemeSettings(
  family: AppThemeFamily.b,
  brightnessMode: ThemeMode.dark,
);

class ControlledCache extends ThemeSettingsStore {
  Completer<void>? writeGate;
  Completer<ThemeSettings?>? readGate;
  bool failWrite = false;
  @override
  Future<ThemeSettings?> read(String uid) async =>
      readGate == null ? null : await readGate!.future;
  @override
  Future<void> write(String uid, ThemeSettings settings) async {
    if (writeGate != null) await writeGate!.future;
    if (failWrite) throw StateError('disk write failed');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'late A cache completion must not apply A settings to current B',
    () async {
      final auth = UnknownSessionAuthService()
        ..restore(const AuthUser(uid: 'a'));
      final cache = ControlledCache();
      final c = ProviderContainer(
        overrides: [
          teamsProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          stadiumsProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          placesProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          scheduleProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          authServiceProvider.overrideWithValue(auth),
          userProfileProvider.overrideWithValue(
            const AsyncLoading<UserProfile?>(),
          ),
          themeSettingsStoreProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(auth.dispose);
      c.listen(themeSettingsProvider, (_, _) {});
      await pumpEventQueue();
      cache.writeGate = Completer<void>();
      final pending = c
          .read(cachedThemeSettingsProvider.notifier)
          .write('a', bd);
      auth.restore(const AuthUser(uid: 'b'));
      await pumpEventQueue();
      expect(c.read(themeSettingsProvider), const ThemeSettings.defaults());
      cache.writeGate!.complete();
      await pending;
      await pumpEventQueue();
      expect(
        (
          c.read(themeSettingsProvider).family,
          c.read(themeSettingsProvider).brightnessMode,
        ),
        (AppThemeFamily.a, ThemeMode.system),
        reason:
            'B has neither profile nor B cache; A late disk completion is not B data',
      );
    },
  );
  test('B pending cache read must not reuse prior A value', () async {
    final auth = UnknownSessionAuthService()..restore(const AuthUser(uid: 'a'));
    final cache = ControlledCache();
    final c = ProviderContainer(
      overrides: [
        teamsProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        stadiumsProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        placesProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        scheduleProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        authServiceProvider.overrideWithValue(auth),
        userProfileProvider.overrideWithValue(
          const AsyncLoading<UserProfile?>(),
        ),
        themeSettingsStoreProvider.overrideWithValue(cache),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    c.listen(themeSettingsProvider, (_, _) {});
    await pumpEventQueue();
    await c.read(cachedThemeSettingsProvider.notifier).write('a', bd);
    await pumpEventQueue();
    expect(c.read(themeSettingsProvider), bd);
    cache.readGate = Completer<ThemeSettings?>();
    auth.restore(const AuthUser(uid: 'b'));
    await pumpEventQueue();
    expect(
      (
        c.read(themeSettingsProvider).family,
        c.read(themeSettingsProvider).brightnessMode,
      ),
      (AppThemeFamily.a, ThemeMode.system),
      reason: 'An AsyncLoading previous value must retain owner identity',
    );
    cache.readGate!.complete(null);
  });
  test('cache failure does not roll back successful remote setting', () async {
    final auth = UnknownSessionAuthService()..restore(const AuthUser(uid: 'a'));
    final store = FakeUserDataStore();
    await store.createProfile(
      'a',
      const NewUserProfile(nickname: '원정러', favoriteTeamId: null),
    );
    final c = ProviderContainer(
      overrides: [
        teamsProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        stadiumsProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        placesProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        scheduleProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
        themeSettingsStoreProvider.overrideWithValue(
          ControlledCache()..failWrite = true,
        ),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    addTearDown(store.dispose);
    c.listen(themeSettingsProvider, (_, _) {});
    await pumpEventQueue();
    await c
        .read(themeSettingsProvider.notifier)
        .setBrightnessMode(ThemeMode.dark);
    await pumpEventQueue();
    expect(c.read(themeSettingsProvider).brightnessMode, ThemeMode.dark);
    expect(store.documents['a']![UserFields.brightnessPreference], 'dark');
  });
  testWidgets('splash does not consume profile server confirmation grace', (
    tester,
  ) async {
    final store = FakeUserDataStore()..holdProfiles = true;
    final c = ProviderContainer(
      overrides: [
        teamsProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        stadiumsProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        placesProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        scheduleProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        authStateProvider.overrideWithValue(
          const AsyncData(AuthUser(uid: 'a')),
        ),
        userDataStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(store.dispose);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const KboAwayFansApp()),
    );
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      store.profileWatches,
      0,
      reason:
          'existing splash contract starts profile grace after splash completion',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'historical unknown team renders neutral while new writes reject it',
    () {
      final t = AppVisualTheme.resolve(
        favoriteTeamId: 'historical-team',
        defaultFamily: AppThemeFamily.b,
        brightness: Brightness.dark,
      );
      expect(t.background, NeutralTokens.darkBackground);
      expect(
        () => const NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'historical-team',
        ).toData(),
        throwsArgumentError,
      );
      expect(
        () =>
            const UserProfilePatch(favoriteTeamId: 'historical-team').toData(),
        throwsArgumentError,
      );
    },
  );

  testWidgets(
    'W1 B dark cache reaches first post-splash root while profile is delayed',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        kThemeSettingsPrefsKey: 'a|b|dark',
        kSelectedTeamPrefsKey: 'a|',
      });
      final store = FakeUserDataStore()..holdProfiles = true;
      final c = ProviderContainer(
        overrides: [
          teamsProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          stadiumsProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          placesProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          scheduleProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          authStateProvider.overrideWithValue(
            const AsyncData(AuthUser(uid: 'a')),
          ),
          userDataStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(
            () => DateTime.parse('2026-09-13T12:00:00+09:00'),
          ),
        ],
      );
      addTearDown(store.dispose);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const KboAwayFansApp()),
      );
      await tester.pump();
      await tester.pump(SplashScreen.totalDuration);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(MainTabsRoot), findsOneWidget);
      final visual = Theme.of(
        tester.element(find.byType(MainTabsRoot)),
      ).extension<AppVisualTheme>()!;
      expect(visual.brightness, Brightness.dark);
      expect(visual.background, DefaultThemeTokens.bDarkBackground);
      expect(c.read(userProfileProvider).isLoading, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'W2 same-interval resume rearms 19 boundary and survives disposal',
    (tester) async {
      var now = DateTime.parse('2026-09-13T18:59:50+09:00');
      final store = FakeUserDataStore();
      await store.createProfile(
        'a',
        const NewUserProfile(nickname: '원정러', favoriteTeamId: null),
      );
      final c = ProviderContainer(
        overrides: [
          teamsProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          stadiumsProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          placesProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          scheduleProvider.overrideWith(
            (_) async => const ContentUnavailable(
              ContentIssue(ContentIssueKind.network, 'probe'),
            ),
          ),
          authStateProvider.overrideWithValue(
            const AsyncData(AuthUser(uid: 'a')),
          ),
          userDataStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(store.dispose);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: c, child: const KboAwayFansApp()),
      );
      await tester.pumpAndSettle();
      expect(c.read(resolvedThemeBrightnessProvider), Brightness.light);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime.parse('2026-09-13T18:59:55+09:00');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      now = DateTime.parse('2026-09-13T19:00:00+09:00');
      await tester.pump(const Duration(seconds: 5));
      expect(c.read(resolvedThemeBrightnessProvider), Brightness.dark);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('W3 historical unknown server team keeps a usable neutral root', (
    tester,
  ) async {
    final store = FakeUserDataStore();
    await store.createProfile(
      'a',
      const NewUserProfile(
        nickname: '원정러',
        favoriteTeamId: null,
        brightnessPreference: BrightnessPreference.dark,
      ),
    );
    store.documents['a']![UserFields.favoriteTeamId] = 'historical-team';
    final c = ProviderContainer(
      overrides: [
        teamsProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        stadiumsProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        placesProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        scheduleProvider.overrideWith(
          (_) async => const ContentUnavailable(
            ContentIssue(ContentIssueKind.network, 'probe'),
          ),
        ),
        authStateProvider.overrideWithValue(
          const AsyncData(AuthUser(uid: 'a')),
        ),
        userDataStoreProvider.overrideWithValue(store),
        locationPermissionStatusProvider.overrideWith(
          (_) async => LocationPermissionStatus.denied,
        ),
      ],
    );
    addTearDown(store.dispose);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const KboAwayFansApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MainTabsRoot), findsOneWidget);
    expect(c.read(selectedTeamIdProvider).value, 'historical-team');
    expect(
      c.read(appVisualThemeProvider).background,
      NeutralTokens.darkBackground,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
