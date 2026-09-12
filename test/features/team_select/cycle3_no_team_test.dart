import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/team_select/selected_team.dart';
import 'package:kbo_away_fans/features/team_select/team_select_screen.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';
import '../../location/fake_location_permission_gateway.dart';

void main() {
  const uid = 'no-team-user';
  late FakeUserDataStore store;
  late FakeAuthService auth;
  late ProviderContainer container;
  late TeamsDocument teams;
  late StadiumsDocument stadiums;
  late PlacesDocument places;

  setUpAll(() {
    Map<String, Object?> read(String name) =>
        jsonDecode(File('content-pipeline/data/$name.json').readAsStringSync())
            as Map<String, Object?>;
    teams = TeamsDocument.fromJson(read('teams'));
    stadiums = StadiumsDocument.fromJson(read('stadiums'));
    places = PlacesDocument.fromJson(read('places'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = FakeUserDataStore();
    auth = FakeAuthService(signedIn: const AuthUser(uid: uid));
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
        locationPermissionGatewayProvider.overrideWithValue(
          FakeLocationPermissionGateway(
            initial: LocationPermissionStatus.granted,
          ),
        ),
        teamsProvider.overrideWith((ref) async => ContentFresh(teams)),
        stadiumsProvider.overrideWith((ref) async => ContentFresh(stadiums)),
        placesProvider.overrideWith((ref) async => ContentFresh(places)),
        scheduleProvider.overrideWith(
          (ref) async => ContentFresh(
            ScheduleDocument(generatedAt: DateTime.utc(2026), games: const []),
          ),
        ),
      ],
    );
    addTearDown(auth.dispose);
    addTearDown(store.dispose);
    addTearDown(container.dispose);
  });

  Map<String, Object?> profile({String? team, String family = 'b'}) => {
    UserFields.nickname: '원정러',
    UserFields.favoriteTeamId: team,
    UserFields.defaultThemeFamily: family,
    UserFields.brightnessPreference: 'dark',
    UserFields.joinedAt: DateTime.utc(2026, 3, 1),
    UserFields.board: <String, Object?>{},
  };

  Future<void> showApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const KboAwayFansApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('팀 없이 시작해 정상 프로필을 저장하고 홈에 진입한다', (tester) async {
    await showApp(tester);
    await tester.tap(find.text('팀 없이 시작하기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('no-team-home')), findsOneWidget);
    expect(find.byType(TeamSelectScreen), findsNothing);
    final saved = store.documents[uid]!;
    expect(saved.containsKey(UserFields.favoriteTeamId), isTrue);
    expect(saved[UserFields.favoriteTeamId], isNull);
    expect(saved[UserFields.defaultThemeFamily], 'a');
    expect(saved[UserFields.brightnessPreference], 'auto');
    expect(store.profileCreates, 1);
    expect(await const SelectedTeamStore().hasNoTeamProfile(uid), isTrue);
  });

  testWidgets('기존 팀 없음 프로필은 다시 온보딩하지 않는다', (tester) async {
    store.documents[uid] = profile();
    await showApp(tester);
    expect(find.byKey(const ValueKey('no-team-home')), findsOneWidget);
    expect(find.byType(TeamSelectScreen), findsNothing);
    expect(store.profileCreates, 0);
  });

  testWidgets('B 계열에서 팀을 골랐다 해제해도 B와 수동 밝기가 남는다', (tester) async {
    store.documents[uid] = profile();
    await showApp(tester);
    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await tester.pumpAndSettle();
    final lg = find.text('LG 트윈스', skipOffstage: false);
    await tester.ensureVisible(lg);
    await tester.tap(lg);
    await tester.pumpAndSettle();
    expect(store.documents[uid]![UserFields.favoriteTeamId], 'lg');
    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('팀 없음으로 변경'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('no-team-home')), findsOneWidget);
    expect(find.byType(TeamSelectScreen), findsNothing);
    final restored = (await store.readProfile(uid))!;
    expect(restored.favoriteTeamId, isNull);
    expect(restored.defaultThemeFamily, DefaultThemeFamily.b);
    expect(restored.brightnessPreference, BrightnessPreference.dark);
    expect(restored.joinedAt, DateTime.utc(2026, 3, 1));
    final visual = AppVisualTheme.resolve(
      favoriteTeamId: restored.favoriteTeamId,
      defaultFamily: AppThemeFamily.values.byName(
        restored.defaultThemeFamily.name,
      ),
      brightness: Brightness.dark,
    );
    expect(visual.background, DefaultThemeTokens.bDarkBackground);
    expect(await const SelectedTeamStore().read(uid), isNull);
    expect(await const SelectedTeamStore().hasNoTeamProfile(uid), isTrue);
  });

  testWidgets('legacy 프로필을 해제하면 A/auto로 호환된다', (tester) async {
    store.documents[uid] = profile(team: 'lg')
      ..remove(UserFields.defaultThemeFamily)
      ..remove(UserFields.brightnessPreference);
    await showApp(tester);
    final before = container.read(userProfileProvider).requireValue!;
    expect(before.defaultThemeFamily, DefaultThemeFamily.a);
    expect(before.brightnessPreference, BrightnessPreference.auto);
    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('팀 없음으로 변경'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('no-team-home')), findsOneWidget);
    expect(store.documents[uid]![UserFields.favoriteTeamId], isNull);
    expect(store.documents[uid]![UserFields.defaultThemeFamily], 'a');
    expect(store.documents[uid]![UserFields.brightnessPreference], 'auto');
  });

  testWidgets('팀 없음의 첫 저장 실패는 온보딩과 안내로 돌아온다', (tester) async {
    await showApp(tester);
    store.profileWriteFailure = const BackendNetworkError(code: 'unavailable');
    await tester.tap(find.text('팀 없이 시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(TeamSelectScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text(TeamSelectScreen.saveFailureNotice), findsOneWidget);
    expect(store.documents, isEmpty);
    expect(await const SelectedTeamStore().hasNoTeamProfile(uid), isFalse);
  });

  testWidgets('팀 해제 저장 실패는 기존 팀과 계열을 보존한다', (tester) async {
    store.documents[uid] = profile(team: 'lg');
    await showApp(tester);
    store.profileWriteFailure = const BackendNetworkError(code: 'unavailable');
    await tester.tap(find.byTooltip('응원 팀 바꾸기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('팀 없음으로 변경'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(container.read(selectedTeamIdProvider).value, 'lg');
    expect(store.documents[uid]![UserFields.defaultThemeFamily], 'b');
    expect(await const SelectedTeamStore().read(uid), 'lg');
    expect(find.text(TeamSelectScreen.saveFailureNotice), findsOneWidget);
  });

  testWidgets('팀 없음 캐시로 서버 대기 중에도 홈에 진입한다', (tester) async {
    await const SelectedTeamStore().writeNoTeam(uid);
    store.holdProfiles = true;
    await showApp(tester);
    expect(find.byKey(const ValueKey('no-team-home')), findsOneWidget);
    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('no-team-home')), findsOneWidget);
  });

  test('팀 없음 캐시의 소유자와 서버 문서 부재를 구분한다', () async {
    await const SelectedTeamStore().writeNoTeam(uid);
    expect(
      await const SelectedTeamStore().hasNoTeamProfile('other-user'),
      isFalse,
    );
    container.listen(selectedProfileExistsProvider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(selectedProfileExistsProvider).value, isFalse);
  });
}
