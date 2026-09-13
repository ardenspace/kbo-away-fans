/// phase 5 통합 검증(둘째 눈)의 탐침 — 이미 있는
/// `phase5_seam_probe_test.dart` 가 걷지 **않은** 이음매만 걷는다.
///
/// 이 파일이 재는 것:
///
///  P1) 홈이 한 번 얻은 권한 답을 **다시 묻는 자리가 있는가.** 5.2 는
///      `noGameToday`(월요일·비시즌 전체)와 "판정이 아예 없는 실행"에서
///      `locationPermissionStatusProvider` 를 구독해 권한을 가른다. 그
///      provider 는 `autoDispose` 지만 홈이 그 갈래에 서 있는 동안에는
///      구독이 끊기지 않으므로 **한 실행에서 딱 한 번만 답이 난다**. 사람이
///      OS 설정에서 권한을 끄고 돌아오는 것은 이 앱이 이미 아는 갈래인데
///      (`LocationPermissionGateway.openSettings` 문서: "돌아오면
///      `StadiumVisitTrigger` 의 `resumed` 가 다시 판정한다"), 경기 없는
///      날에는 그 재판정이 권한을 묻지 않는다 — `judgeStadiumVisit` 이 후보
///      게이트를 권한보다 먼저 보기 때문이다.
///
///  P2) 그 반대 방향 — 권한을 **켜고** 돌아온 실행.
///
///  P3) 앱을 배경으로 보내지 않고 포그라운드에 둔 채 시각만 흐른 실행.
///      5.2 가 세운 `kCurrentLocationFreshness` 는 홈이 **다시 빌드될 때만**
///      재어진다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/features/badges/stamp_reveal.dart';
import 'package:kbo_away_fans/features/home/current_location.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';
import '../../content/live_schedule.dart';

const String _uid = 'google-uid';

/// 이 탐침이 응원 팀으로 **먼저 보는** 팀 — 이 팀의 일정에 걸을 경기가 없으면
/// 앵커가 다른 팀으로 넘어간다([AwayGameAnchor.teamId] 가 실제로 고른 팀이다).
const String _teamId = 'lg';

/// 콘텐츠 4종의 실 산출물 — 이 파일의 시험들이 함께 쓴다.
late LiveContent _content;

/// 이 탐침이 걷는 원정 경기 — **실행 시점에 실 일정에서 고른다.**
///
/// 이 문서는 크롤이 경기 시간대에 20분마다 다시 쓰고 그 창이 앞뒤로
/// 움직이므로, 고른 경기를 리터럴로 박으면 아무도 코드를 건드리지 않아도 이
/// 파일이 빨간불이 된다 (`test/content/live_schedule.dart` 첫 문단).
late AwayGameAnchor _anchor;

/// 리그 전체에 경기가 하나도 없는 시각 — `judgeStadiumVisit` 이 권한을 묻기도
/// 전에 `noGameToday` 로 끝나는 갈래.
late DateTime _noGameDay;

/// 기기가 그 구장 안에 있다.
_Spot _atStadium() => _Spot(lat: _anchor.stadium.lat, lng: _anchor.stadium.lng);

/// 기기가 어느 구장에서도 멀다 — "집에 왔다".
_Spot _offStadium() => _Spot(lat: kOffStadiumLat, lng: kOffStadiumLng);

class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

class _Spot {
  _Spot({required this.lat, required this.lng});
  double lat;
  double lng;
}

/// OS 설정에서 권한이 바뀌는 것을 흉내 낼 수 있는 대역 —
/// `FakeLocationPermissionGateway` 는 `request()` 를 거치지 않고는 값을 바꿀
/// 수 없어서(그 대역의 `_status` 가 private) 이 파일이 따로 둔다.
class _SettingsGateway extends LocationPermissionGateway {
  _SettingsGateway(this.current);

  LocationPermissionStatus current;
  int statusCalls = 0;
  int requestCalls = 0;

  @override
  Future<LocationPermissionStatus> status() async {
    statusCalls++;
    return current;
  }

  @override
  Future<LocationPermissionStatus> request() async {
    requestCalls++;
    return current;
  }

  @override
  Future<bool> openSettings() async => true;
}

class _Harness {
  _Harness({
    required this.clock,
    required this.gateway,
    required this.spot,
    required this.fixReads,
  });
  final _Clock clock;
  final _SettingsGateway gateway;
  final _Spot spot;
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
  final gateway = _SettingsGateway(permission);
  final fixReads = <int>[];
  addTearDown(auth.dispose);
  addTearDown(store.dispose);
  await store.createProfile(
    _uid,
    NewUserProfile(nickname: '원정러', favoriteTeamId: _anchor.teamId),
  );

  final teams = _content.teams;
  final stadiums = _content.stadiums;
  final places = _content.places;
  final schedule = _content.schedule;

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
    clock: clock,
    gateway: gateway,
    spot: spot,
    fixReads: fixReads,
  );
}

Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> _dismissReveal(WidgetTester tester) async {
  if (find.byType(StampReveal).evaluate().isNotEmpty) {
    await tester.tap(find.byType(StampReveal));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }
}

/// 홈 상단 위치 자리가 지금 화면에 있는가.
bool _locationRowStands() => find
    .byKey(kCurrentLocationRowKey, skipOffstage: false)
    .evaluate()
    .isNotEmpty;

void main() {
  setUpAll(() {
    _content = readLiveContent();
    _anchor = pickAwayGameAnchor(content: _content, preferredTeamId: _teamId);
    _noGameDay = pickNoGameMoment(_content.schedule);
  });

  testWidgets(
    'P1) 리그가 쉬는 날 — OS 설정에서 권한을 끄고 돌아와도 홈 상단 위치 자리가 그대로 선다',
    (tester) async {
      // 리그 전체가 쉬는 날 — `judgeStadiumVisit` 이 권한을 묻기도 전에
      // `noGameToday` 로 끝내는 날, 곧 5.2 가 권한을 따로 물어 자리를 세우는
      // 그 갈래다. 어느 날인지는 실 일정에서 고른다.
      final h = await _pump(tester, at: _noGameDay, spot: _offStadium());
      expect(_locationRowStands(), isTrue, reason: '권한이 있으면 자리가 선다');
      final callsWhileGranted = h.gateway.statusCalls;

      // 사람이 OS 설정에서 위치 권한을 껐다 (앱은 배경에 살아 있다).
      h.gateway.current = LocationPermissionStatus.denied;
      h.clock.now = _noGameDay.add(const Duration(minutes: 30));
      await _resume(tester);

      expect(
        _locationRowStands(),
        isFalse,
        reason:
            '5.2 acceptance 2: 권한이 없으면 그 자리가 사라지거나 권한 안내로 바뀐다 '
            '(권한 조회 횟수: 끄기 전 $callsWhileGranted → 지금 ${h.gateway.statusCalls})',
      );
      expect(
        h.gateway.statusCalls,
        greaterThan(callsWhileGranted),
        reason: '포그라운드로 돌아왔으면 권한을 다시 물어야 이 자리가 참을 말한다',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'P2) 리그가 쉬는 날 — OS 설정에서 권한을 켜고 돌아오면 자리가 선다',
    (tester) async {
      final h = await _pump(
        tester,
        at: _noGameDay,
        spot: _offStadium(),
        permission: LocationPermissionStatus.denied,
      );
      expect(_locationRowStands(), isFalse);

      h.gateway.current = LocationPermissionStatus.granted;
      h.clock.now = _noGameDay.add(const Duration(minutes: 30));
      await _resume(tester);

      expect(
        _locationRowStands(),
        isTrue,
        reason: '5.2 acceptance 1: 권한이 있으면 현재 위치가 상단에 뜬다',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'P3) 앱을 켠 채 구장을 떠나 시각만 흐른 실행 — 홈 상단이 옛 구장을 계속 가리키는가',
    (tester) async {
      final h = await _pump(tester, at: _anchor.atGame, spot: _atStadium());
      await _dismissReveal(tester);
      expect(find.text(_anchor.nearbyLabel), findsOneWidget);

      // 경기가 끝나고 집으로 돌아왔다. **앱은 계속 포그라운드다** —
      // 배경으로 보낸 적이 없으므로 `StadiumVisitTrigger` 의 `resumed` 도,
      // `lib/app.dart` 의 콘텐츠 재로드도 일어나지 않는다.
      h.spot
        ..lat = kOffStadiumLat
        ..lng = kOffStadiumLng;
      h.clock.now = _anchor.at(const Duration(hours: 3, minutes: 30));

      // 사람이 앱 안에서 하는 일: 탭을 오가고 홈으로 돌아온다.
      await tester.tap(find.text('배지'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.text('홈'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.text(_anchor.nearbyLabel),
        findsNothing,
        reason: '판정이 난 지 2시간 30분 — kCurrentLocationFreshness(15분)를 한참 넘겼다',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
