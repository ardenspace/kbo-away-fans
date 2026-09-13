import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/profile/theme_settings.dart';
import 'package:kbo_away_fans/features/team_select/selected_team.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';

class _ControlledStore extends FakeUserDataStore {
  Completer<void>? nextPatchGate;

  @override
  Future<void> patchProfile(String uid, UserProfilePatch patch) async {
    final gate = nextPatchGate;
    nextPatchGate = null;
    if (gate != null) await gate.future;
    await super.patchProfile(uid, patch);
  }
}

void main() {
  late _ControlledStore store;
  late UnknownSessionAuthService auth;
  late ProviderContainer container;

  ProviderContainer makeContainer() {
    final result = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
      ],
    );
    result.listen(appVisualThemeProvider, (_, _) {});
    result.listen(selectedProfileExistsProvider, (_, _) {});
    return result;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _ControlledStore();
    auth = UnknownSessionAuthService()..restore(const AuthUser(uid: 'owner'));
    await store.createProfile(
      'owner',
      const NewUserProfile(nickname: '원정러', favoriteTeamId: null),
    );
    await store.createProfile(
      'other',
      const NewUserProfile(nickname: '다른 사람', favoriteTeamId: 'ssg'),
    );
    container = makeContainer();
    await pumpEventQueue();
  });

  tearDown(() async {
    container.dispose();
    await auth.dispose();
    await store.dispose();
  });

  test('select then settings then clear survives a fresh container', () async {
    final teams = container.read(selectedTeamIdProvider.notifier);
    await teams.select('lg', isChange: true);
    await pumpEventQueue();
    final settings = container.read(themeSettingsProvider.notifier);
    await settings.setFamily(AppThemeFamily.b);
    await settings.setBrightnessMode(ThemeMode.dark);
    await pumpEventQueue();
    expect(
      container.read(appVisualThemeProvider).primary,
      TeamThemes.lg.primary,
    );
    await teams.select(null, isChange: true);
    await pumpEventQueue();
    expect(
      container.read(appVisualThemeProvider).background,
      DefaultThemeTokens.bDarkBackground,
    );
    container.dispose();
    container = makeContainer();
    await pumpEventQueue();
    expect(container.read(selectedProfileExistsProvider).value, isTrue);
    expect(container.read(selectedTeamIdProvider).value, isNull);
    expect(
      container.read(appVisualThemeProvider).background,
      DefaultThemeTokens.bDarkBackground,
    );
  });

  test('settings snapshot cannot undo a pending team clear', () async {
    final teams = container.read(selectedTeamIdProvider.notifier);
    await teams.select('lg', isChange: true);
    await pumpEventQueue();
    final gate = Completer<void>();
    store.nextPatchGate = gate;
    final clear = teams.select(null, isChange: true);
    await pumpEventQueue();
    await container
        .read(themeSettingsProvider.notifier)
        .setFamily(AppThemeFamily.b);
    await container
        .read(themeSettingsProvider.notifier)
        .setBrightnessMode(ThemeMode.dark);
    await pumpEventQueue();
    expect(container.read(selectedTeamIdProvider).value, isNull);
    expect(
      container.read(appVisualThemeProvider).background,
      DefaultThemeTokens.bDarkBackground,
    );
    gate.complete();
    await clear;
    await pumpEventQueue();
    expect(store.documents['owner']![UserFields.favoriteTeamId], isNull);
    expect(store.documents['owner']![UserFields.defaultThemeFamily], 'b');
  });

  test(
    'returning to an account preserves its latest successful brightness choice',
    () async {
      final gate = Completer<void>();
      store.nextPatchGate = gate;
      final oldLight = container
          .read(themeSettingsProvider.notifier)
          .setBrightnessMode(ThemeMode.light);
      await pumpEventQueue();
      auth.restore(const AuthUser(uid: 'other'));
      await pumpEventQueue();
      expect(container.read(userProfileProvider).value!.uid, 'other');
      auth.restore(const AuthUser(uid: 'owner'));
      await pumpEventQueue();
      expect(container.read(userProfileProvider).value!.uid, 'owner');
      await container
          .read(themeSettingsProvider.notifier)
          .setBrightnessMode(ThemeMode.dark);
      await pumpEventQueue();
      expect(
        store.documents['owner']![UserFields.brightnessPreference],
        'dark',
      );
      gate.complete();
      await oldLight;
      await pumpEventQueue();
      expect(
        store.documents['owner']![UserFields.brightnessPreference],
        'dark',
        reason:
            'An older session write must not replace the latest saved selection.',
      );
      expect(
        container.read(themeSettingsProvider).brightnessMode,
        ThemeMode.dark,
      );
      container.dispose();
      container = makeContainer();
      await pumpEventQueue();
      expect(
        container.read(themeSettingsProvider).brightnessMode,
        ThemeMode.dark,
        reason:
            'The stale completion must not replace the latest account cache.',
      );
    },
  );
}
