import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/features/profile/profile_tab_screen.dart';
import 'package:kbo_away_fans/features/profile/theme_settings.dart';
import 'package:kbo_away_fans/ui/shared/theme_settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';

const _uid = 'theme-settings-user';
final _noonKst = DateTime.parse('2026-09-12T12:00:00+09:00');

class _SlowThemeStore extends FakeUserDataStore {
  final Completer<void> releasePatch = Completer<void>();

  @override
  Future<void> patchProfile(String uid, UserProfilePatch patch) async {
    await releasePatch.future;
    await super.patchProfile(uid, patch);
  }
}

void main() {
  late FakeUserDataStore store;
  late FakeAuthService auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = FakeUserDataStore();
    auth = FakeAuthService(signedIn: const AuthUser(uid: _uid));
  });

  tearDown(() async {
    await auth.dispose();
    await store.dispose();
  });

  Future<void> seedProfile({
    String? teamId,
    DefaultThemeFamily family = DefaultThemeFamily.a,
    BrightnessPreference brightness = BrightnessPreference.auto,
  }) => store.createProfile(
    _uid,
    NewUserProfile(
      nickname: '원정러',
      favoriteTeamId: teamId,
      defaultThemeFamily: family,
      brightnessPreference: brightness,
    ),
  );

  Widget screen() => ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      userDataStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => _noonKst),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final visual = ref.watch(appVisualThemeProvider);
        return MaterialApp(
          theme: visual.toThemeData(),
          home: const ProfileTabScreen(),
        );
      },
    ),
  );

  AppVisualTheme visualOf(WidgetTester tester) => Theme.of(
    tester.element(find.byType(ProfileTabScreen)),
  ).extension<AppVisualTheme>()!;

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip(ProfileTabScreen.themeSettingsTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeSettingsSheet), findsOneWidget);
  }

  testWidgets('A/B와 밝기 선택은 저장 전부터 전역 테마에 반영되고 프로필에 남는다', (tester) async {
    final slow = _SlowThemeStore();
    await store.dispose();
    store = slow;
    await seedProfile();
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await openSettings(tester);

    await tester.tap(find.text('B 계열'));
    // MaterialApp은 새 ThemeData로 즉시 재빌드한 뒤 기본 테마 전환 시간 동안
    // 보간한다. 서버 쓰기는 여전히 붙잡힌 채로 그 전환만 끝낸다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProfileTabScreen)),
    );
    expect(container.read(themeSettingsProvider).family, AppThemeFamily.b);
    expect(
      container.read(appVisualThemeProvider).background,
      DefaultThemeTokens.bLightBackground,
    );
    expect(visualOf(tester).background, DefaultThemeTokens.bLightBackground);
    expect(store.documents[_uid]![UserFields.defaultThemeFamily], 'a');

    slow.releasePatch.complete();
    await tester.pumpAndSettle();
    expect(store.documents[_uid]![UserFields.defaultThemeFamily], 'b');

    await tester.tap(find.text('어두움'));
    await tester.pumpAndSettle();
    expect(visualOf(tester).brightness, Brightness.dark);
    expect(store.documents[_uid]![UserFields.brightnessPreference], 'dark');

    await tester.tap(find.text('자동'));
    await tester.pumpAndSettle();
    expect(visualOf(tester).brightness, Brightness.light);
    expect(store.documents[_uid]![UserFields.brightnessPreference], 'auto');
  });

  testWidgets('팀을 고른 동안 B 계열을 저장해도 팀 색이 우선하고 팀 없음에서 B가 복원된다', (tester) async {
    await seedProfile(teamId: 'lg');
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await openSettings(tester);

    await tester.tap(find.text('B 계열'));
    await tester.pumpAndSettle();

    expect(store.documents[_uid]![UserFields.defaultThemeFamily], 'b');
    expect(visualOf(tester).primary, TeamThemes.lg.primary);
    expect(visualOf(tester).background, NeutralTokens.lightBackground);

    await store.patchProfile(
      _uid,
      const UserProfilePatch(favoriteTeamId: null),
    );
    await tester.pumpAndSettle();

    expect(visualOf(tester).background, DefaultThemeTokens.bLightBackground);
    expect(visualOf(tester).primary, DefaultThemeTokens.bPrimary);
  });

  test('자동 밝기는 KST 07:00~18:59만 밝음이다', () {
    expect(
      automaticThemeBrightness(DateTime.parse('2026-09-12T06:59:59+09:00')),
      Brightness.dark,
    );
    expect(
      automaticThemeBrightness(DateTime.parse('2026-09-12T07:00:00+09:00')),
      Brightness.light,
    );
    expect(
      automaticThemeBrightness(DateTime.parse('2026-09-12T18:59:59+09:00')),
      Brightness.light,
    );
    expect(
      automaticThemeBrightness(DateTime.parse('2026-09-12T19:00:00+09:00')),
      Brightness.dark,
    );
  });
}
