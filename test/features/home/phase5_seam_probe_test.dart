/// phase 5 통합 검증 탐침 — 두 새 자리(5.1 최근 5경기 · 5.2 현재 위치)를
/// **실 배선 위에서** 걸어 본다.
///
/// 단계 시험들은 두 자리를 각각 고정값으로 갈아 끼워 잰다
/// (`home_screen_test.dart` 의 `_FixedStadiumVisitCheck`). 이 파일은 그
/// 대역을 쓰지 않는다 — `MainTabsRoot` 를 그대로 띄워 4.1 의 `StadiumVisitTrigger`
/// 가 실제로 돌린 판정 결과가 홈 상단까지 오는지, 그리고 그 값이 시간·이동·탭
/// 이동을 지나며 무엇이 되는지를 잰다. 콘텐츠도 픽스처를 짓지 않고
/// `content-pipeline/data/*.json` 실물을 쓴다.
///
///  A) 원정 구장에서 앱을 연 실행 — 홈 상단에 그 구장 이름이 뜨고, 같은
///     화면에 최근 5경기가 함께 선다(두 자리가 한 화면에서 겹치지 않는지).
///  B) 구장을 떠난 뒤 포그라운드로 돌아온 실행 — 홈 상단의 "현재 위치"가
///     무엇을 말하는가. 4.2 의 `judgingAddsNothing` 게이트가 닫혀 판정이
///     건너뛰어지는 구간이다.
///  C) 경기 없는 날(월요일) — 권한이 있으면 자리가 서고 없으면 접힌다는
///     5.2 의 acceptance 를 **실 판정 경로**에서 잰다(단계 시험은 판정
///     결과를 직접 주입한다).
///  D) 탭을 오갔다 돌아와도 홈 상단 자리가 그대로다.
///  E) 콘텐츠 문서를 못 얻은 실행 — 판정이 아예 돌지 못할 때 두 자리가
///     각각 무엇을 말하는가.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/badges/stamp_reveal.dart';
import 'package:kbo_away_fans/features/home/current_location.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';
import '../../location/fake_location_permission_gateway.dart';

const String _uid = 'google-uid';

/// 사직야구장 (`content-pipeline/data/stadiums.json`).
const double _sajikLat = 35.1941;
const double _sajikLng = 129.0615;

Map<String, Object?> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

/// 기기가 지금 어디에 있는지 — 시나리오 도중에 옮길 수 있어야 한다.
class _Spot {
  _Spot({required this.lat, required this.lng});
  double lat;
  double lng;
}

class _Harness {
  _Harness({
    required this.store,
    required this.auth,
    required this.clock,
    required this.gateway,
    required this.spot,
    required this.fixReads,
  });
  final FakeUserDataStore store;
  final FakeAuthService auth;
  final _Clock clock;
  final FakeLocationPermissionGateway gateway;
  final _Spot spot;

  /// 측위가 실제로 몇 번 일어났는가 — 판정이 건너뛰어졌는지를 가르는 값.
  final List<int> fixReads;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required DateTime at,
  required _Spot spot,
  LocationPermissionStatus permission = LocationPermissionStatus.granted,
}) async {
  SharedPreferences.setMockInitialValues({});
  final auth = FakeAuthService(
    signedIn: const AuthUser(uid: _uid, email: 'a@b.c'),
  );
  final store = FakeUserDataStore();
  final clock = _Clock(at);
  final gateway = FakeLocationPermissionGateway(initial: permission);
  final fixReads = <int>[];
  addTearDown(auth.dispose);
  addTearDown(store.dispose);
  await store.createProfile(
    _uid,
    const NewUserProfile(
      nickname: '원정러',
      favoriteTeamId: 'lg',
      profileThemeKey: 'lg',
    ),
  );

  final teams = TeamsDocument.fromJson(
    _readJson('content-pipeline/data/teams.json'),
  );
  final stadiums = StadiumsDocument.fromJson(
    _readJson('content-pipeline/data/stadiums.json'),
  );
  final places = PlacesDocument.fromJson(
    _readJson('content-pipeline/data/places.json'),
  );
  final schedule = ScheduleDocument.fromJson(
    _readJson('content-pipeline/data/schedule.json'),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
        locationPermissionGatewayProvider.overrideWithValue(gateway),
        weatherEffectProvider.overrideWith(
          (ref, point) async => WeatherEffect.none,
        ),
        clockProvider.overrideWithValue(clock.call),
        teamsProvider.overrideWith((ref) async => ContentFresh(teams)),
        stadiumsProvider.overrideWith((ref) async => ContentFresh(stadiums)),
        placesProvider.overrideWith((ref) async => ContentFresh(places)),
        scheduleProvider.overrideWith((ref) async => ContentFresh(schedule)),
        stadiumVisitCheckerProvider.overrideWith((ref) {
          final g = ref.watch(locationPermissionGatewayProvider);
          return StadiumVisitChecker(
            readPermission: g.status,
            readFix: () async {
              await Future<void>.delayed(const Duration(milliseconds: 1));
              fixReads.add(fixReads.length);
              return DeviceFix(lat: spot.lat, lng: spot.lng);
            },
          );
        }),
      ],
      child: const MaterialApp(home: MainTabsRoot()),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 5));
  return _Harness(
    store: store,
    auth: auth,
    clock: clock,
    gateway: gateway,
    spot: spot,
    fixReads: fixReads,
  );
}

Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> _dismissReveal(WidgetTester tester) async {
  if (find.byType(StampReveal).evaluate().isNotEmpty) {
    await tester.tap(find.byType(StampReveal));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }
}

void main() {
  testWidgets(
    'A) 원정 구장에서 앱을 열면 홈 상단에 그 구장이, 중단에 최근 5경기가 함께 선다',
    (tester) async {
      // 2026-08-29 18:00 사직 (롯데 vs LG) — LG 팬의 원정 경기.
      final h = await _pump(
        tester,
        at: DateTime.parse('2026-08-29T19:00:00+09:00'),
        spot: _Spot(lat: _sajikLat, lng: _sajikLng),
      );
      await _dismissReveal(tester);

      expect(
        find.text('사직야구장 근처예요'),
        findsOneWidget,
        reason: '4.1 이 실제로 돌린 판정이 홈 상단까지 와야 한다',
      );
      expect(
        find.text('최근 5경기', skipOffstage: false),
        findsOneWidget,
        reason: '두 자리가 한 화면에 함께 선다',
      );
      expect(h.store.stampUploads, isNotEmpty, reason: '같은 판정이 도장도 찍는다');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'B) 구장을 떠나 집에 온 뒤 앱을 다시 열면 홈 상단이 무엇을 말하는가',
    // phase 5 통합 검증의 REJECT 사유였다. 5.2 가 그 자리를 닫으면서
    // `skip: true` 한 줄을 지웠고, 이제 이 시험이 그 회귀 못이다 — 판정
    // 결과와 함께 **그것이 언제 난 답인지**(`stadiumVisitRunProvider`)를 읽어,
    // 게이트에 막혀 갱신되지 못한 판정은 구장 이름으로 쓰지 않는다.
    (tester) async {
      final h = await _pump(
        tester,
        at: DateTime.parse('2026-08-29T19:00:00+09:00'),
        spot: _Spot(lat: _sajikLat, lng: _sajikLng),
      );
      await _dismissReveal(tester);
      expect(find.text('사직야구장 근처예요'), findsOneWidget);
      final readsAtStadium = h.fixReads.length;

      // 경기가 끝나고 서울 집으로 돌아왔다 (창은 아직 열려 있다: 18:00+5h).
      h.spot
        ..lat = 37.5665
        ..lng = 126.9780;
      h.clock.now = DateTime.parse('2026-08-29T21:30:00+09:00');
      await _resume(tester);
      await _dismissReveal(tester);

      // 원인을 못 박는다: 트리거는 돌았지만 4.2 의 `judgingAddsNothing` 게이트가
      // 닫혀 측위 자체가 일어나지 않았다 — 홈이 읽는 값이 갱신될 길이 없다.
      expect(
        h.fixReads.length,
        readsAtStadium,
        reason: '도장을 받은 뒤 창이 닫힐 때까지 판정이 건너뛰어진다(4.2 의 게이트)',
      );
      expect(
        find.text('사직야구장 근처예요'),
        findsNothing,
        reason: '부산 사직에서 400km 떨어진 서울에서 "사직야구장 근처예요"가 뜨면 '
            '홈 상단이 말하는 것은 현재 위치가 아니다',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'B-2) 창이 닫힌 뒤에는(같은 날 늦은 밤) 다시 판정이 돌아 일반 문구로 내려온다',
    (tester) async {
      final h = await _pump(
        tester,
        at: DateTime.parse('2026-08-29T19:00:00+09:00'),
        spot: _Spot(lat: _sajikLat, lng: _sajikLng),
      );
      await _dismissReveal(tester);

      h.spot
        ..lat = 37.5665
        ..lng = 126.9780;
      final readsAtStadium = h.fixReads.length;
      h.clock.now = DateTime.parse('2026-08-29T23:30:00+09:00');
      await _resume(tester);
      await _dismissReveal(tester);

      expect(
        h.fixReads.length,
        greaterThan(readsAtStadium),
        reason: '창이 닫히면 게이트가 열려 판정이 다시 돈다',
      );
      expect(find.text('사직야구장 근처예요'), findsNothing);
      expect(find.text(kCurrentLocationGenericLabel), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'C) 경기 없는 날(2026-08-31 월) — 권한이 있으면 자리가 서고 없으면 접힌다',
    (tester) async {
      await _pump(
        tester,
        at: DateTime.parse('2026-08-31T10:00:00+09:00'),
        spot: _Spot(lat: 37.5665, lng: 126.9780),
      );
      expect(
        find.text(kCurrentLocationGenericLabel),
        findsOneWidget,
        reason: '권한이 있으면 경기 없는 날에도 자리가 선다 (5.2 acceptance 1)',
      );
      expect(find.text('최근 5경기', skipOffstage: false), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'C-2) 경기 없는 날 + 권한 거부 — 자리가 접히고 홈의 나머지는 그대로다',
    (tester) async {
      final h = await _pump(
        tester,
        at: DateTime.parse('2026-08-31T10:00:00+09:00'),
        spot: _Spot(lat: 37.5665, lng: 126.9780),
        permission: LocationPermissionStatus.denied,
      );
      expect(find.text(kCurrentLocationGenericLabel), findsNothing);
      expect(find.text('최근 5경기', skipOffstage: false), findsOneWidget);
      expect(h.gateway.requestCalls, 0, reason: '홈은 OS 다이얼로그를 띄우지 않는다');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'E) 일정 문서를 못 얻은 실행 — 권한이 있으면 자리는 서고, 구장은 말하지 않는다',
    (tester) async {
      // **기대를 바꾼 자리다.** 이 탐침이 처음 적은 사실은 "일정 문서를 못
      // 얻으면 권한이 있어도 위치 자리가 통째로 접힌다"였고, 그것은 5.2
      // acceptance 첫 문장("권한이 있으면 현재 위치가 상단에 뜬다")이 깨지는
      // 자리였다 — 그 화면이 권한을 거부한 사람의 화면과 구분되지 않는다.
      // 5.2 가 그것을 닫으면서 거동이 바뀌었으므로 기대를 사실에 맞춘다:
      // 판정은 여전히 돌지 못하지만(`StadiumVisitCheck.run` 이 문서를 못 얻고
      // 일찍 반환한다) 트리거가 돌았다는 기록은 남고, 홈은 그 기록을 보고
      // 권한을 한 번 물어 자리를 세운다. 구장을 특정하는 문구는 여전히 뜨지
      // 않는다 — 판정이 없으니 앱은 사람이 어디 있는지 모른다.
      SharedPreferences.setMockInitialValues({});
      final auth = FakeAuthService(
        signedIn: const AuthUser(uid: _uid, email: 'a@b.c'),
      );
      final store = FakeUserDataStore();
      addTearDown(auth.dispose);
      addTearDown(store.dispose);
      await store.createProfile(
        _uid,
        const NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'lg',
          profileThemeKey: 'lg',
        ),
      );
      final stadiums = StadiumsDocument.fromJson(
        _readJson('content-pipeline/data/stadiums.json'),
      );
      const issue = ContentIssue(ContentIssueKind.network, 'fixture');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            userDataStoreProvider.overrideWithValue(store),
            locationPermissionGatewayProvider.overrideWithValue(
              FakeLocationPermissionGateway(
                initial: LocationPermissionStatus.granted,
              ),
            ),
            weatherEffectProvider.overrideWith(
              (ref, point) async => WeatherEffect.none,
            ),
            clockProvider.overrideWithValue(
              () => DateTime.parse('2026-08-29T19:00:00+09:00'),
            ),
            teamsProvider.overrideWith(
              (ref) async => const ContentUnavailable<TeamsDocument>(issue),
            ),
            stadiumsProvider.overrideWith((ref) async => ContentFresh(stadiums)),
            placesProvider.overrideWith(
              (ref) async => const ContentUnavailable<PlacesDocument>(issue),
            ),
            scheduleProvider.overrideWith(
              (ref) async => const ContentUnavailable<ScheduleDocument>(issue),
            ),
            stadiumVisitCheckerProvider.overrideWith((ref) {
              final g = ref.watch(locationPermissionGatewayProvider);
              return StadiumVisitChecker(
                readPermission: g.status,
                readFix: () async =>
                    const DeviceFix(lat: _sajikLat, lng: _sajikLng),
              );
            }),
          ],
          child: const MaterialApp(home: MainTabsRoot()),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.text(kCurrentLocationGenericLabel),
        findsOneWidget,
        reason: '권한이 있는 사람의 화면이 거부한 사람의 화면과 구분되어야 한다',
      );
      expect(
        find.text('사직야구장 근처예요'),
        findsNothing,
        reason: '판정이 돌지 못한 실행에서 구장을 말할 근거는 없다',
      );
      expect(
        find.text('최근 5경기', skipOffstage: false),
        findsNothing,
        reason: '5.1 도 일정 문서를 못 얻으면 자리를 접는다 — 두 자리가 같은 규칙이다',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'D) 배지 탭에 갔다 홈으로 돌아와도 상단 위치 자리가 그대로다',
    (tester) async {
      await _pump(
        tester,
        at: DateTime.parse('2026-08-29T19:00:00+09:00'),
        spot: _Spot(lat: _sajikLat, lng: _sajikLng),
      );
      await _dismissReveal(tester);
      expect(find.text('사직야구장 근처예요'), findsOneWidget);

      await tester.tap(find.text('배지'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.text('홈'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('사직야구장 근처예요'), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
