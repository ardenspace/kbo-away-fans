/// phase 5 통합 검증(셋째 눈)의 탐침 — 앞선 두 탐침
/// (`phase5_seam_probe_test.dart`·`phase5_integration_audit_probe_test.dart`)이
/// 걷지 **않은** 이음매만 걷는다.
///
/// 이 파일이 재는 것:
///
///  Q1) **도장을 받은 뒤** OS 설정에서 위치 권한을 끄고 돌아온 실행.
///      앞선 탐침의 P1 은 같은 행동을 **경기 없는 날**(`noGameToday`)에서만
///      걸었다. 경기 있는 날 도장을 받고 나면 4.2 의 `judgingAddsNothing`
///      게이트가 창이 닫힐 때까지(경기 시작 +5시간) 판정을 통째로 건너뛰므로,
///      `stadiumVisitProvider` 는 권한이 있던 시절의 `visited` 를 그대로 들고
///      있고 5.2 의 `currentLocationVisible` 은 그 갈래를 "권한이 있다"로
///      읽는다. 5.2 acceptance 2("권한이 없으면 그 자리가 사라지거나 권한
///      안내로 바뀐다")가 그 구간에서 서는가.
///
///  Q2) Q1 의 대조군 — 같은 날 같은 시각에 **도장을 받지 못한** 사람(구장
///      밖)이 같은 행동을 하면 자리가 접힌다. 게이트가 열려 있어 재판정이
///      권한을 다시 보기 때문이고, 그래서 Q1 의 갈래가 게이트 때문이라는 것이
///      이 대조군으로 못 박힌다.
///
///  Q3) 5.1 이 1.2 의 산출물(`content-pipeline/data/schedule.json`,
///      schemaVersion 2)과 어긋나지 않는가 — 실 데이터로 열 팀 전부를 대조한다.
///
///  Q4) 최근 종료 경기가 하나도 없는 팀의 홈 — 빈 상태가 뜨는가(5.1
///      acceptance 3)를 화면으로 잰다.
library;

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
import 'package:kbo_away_fans/features/home/recent_games.dart';
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

/// 리그 전체에 경기가 하나도 없는 시각.
late DateTime _noGameDay;

/// 기기가 그 구장 안에 있다.
_Spot _atStadium() => _Spot(lat: _anchor.stadium.lat, lng: _anchor.stadium.lng);

/// 기기가 어느 구장에서도 멀다.
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

/// OS 설정에서 권한이 바뀌는 것을 흉내 내는 대역.
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
    required this.store,
  });
  final _Clock clock;
  final _SettingsGateway gateway;
  final _Spot spot;
  final List<int> fixReads;
  final FakeUserDataStore store;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required DateTime at,
  required _Spot spot,
  String? teamId,
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
  final team = teamId ?? _anchor.teamId;
  await store.createProfile(
    _uid,
    NewUserProfile(nickname: '원정러', favoriteTeamId: team),
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
    store: store,
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
    'Q1) 도장을 받은 뒤 OS 설정에서 권한을 끄고 돌아오면 홈 상단 위치 자리가 사라지는가',
    (tester) async {
      // 실 일정에서 고른 그 팀의 원정 경기 — 경기 도중, 구장 안이다.
      final h = await _pump(tester, at: _anchor.atGame, spot: _atStadium());
      await _dismissReveal(tester);
      expect(h.store.stampUploads, isNotEmpty, reason: '이 실행이 도장을 받았다');
      expect(_locationRowStands(), isTrue);
      final readsBefore = h.fixReads.length;

      // 경기 도중 배터리가 아까워(또는 그냥) OS 설정에서 위치 권한을 껐다.
      // 창은 아직 열려 있다 (시작 + 5시간).
      h.gateway.current = LocationPermissionStatus.denied;
      h.clock.now = _anchor.at(const Duration(hours: 1, minutes: 30));
      await _resume(tester);
      await _dismissReveal(tester);

      // 원인을 못 박는다 — 게이트가 닫혀 판정 자체가 돌지 않았다.
      expect(
        h.fixReads.length,
        readsBefore,
        reason: '도장을 받은 뒤 창이 닫힐 때까지 판정이 건너뛰어진다(4.2 의 게이트)',
      );
      expect(
        _locationRowStands(),
        isFalse,
        reason:
            '5.2 acceptance 2: 권한이 없으면 그 자리가 사라지거나 권한 안내로 바뀐다. '
            '권한 조회 횟수 ${h.gateway.statusCalls}',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
    // **이 탐침은 round 3 의 REJECT 사유였고(그때 실측: 자리가 그대로 서 있고
    // 권한 조회 횟수가 복귀 전후 1 → 1), 이제 회귀 못이다.**
    //
    // 까닭이었던 것: `currentLocationVisible` 이 `visited` 를 비롯한 네 이유를
    // "권한이 있다는 뜻"으로 읽는데, 그것이 참인 것은 **그 판정이 난 순간**
    // 이다. 4.2 의 `judgingAddsNothing` 게이트가 닫혀 있는 동안 그 판정은
    // 갱신되지 않으므로(위 fixReads 단언이 그것을 못 박는다) 그 읽기는 최대
    // 다섯 시간 동안 옛 사실이었다.
    //
    // 닫은 방법: 5.2 가 **구장 이름** 쪽에 이미 대 두었던 잣대
    // (`stadiumVisitRunProvider` 의 `judged`)를 **자리를 그릴지** 쪽에도
    // 댔다 — 마지막 시도가 판정까지 가지 못했으면 `noGameToday` 갈래와 똑같이
    // `locationPermissionStatusProvider` 로 권한을 한 번 묻는다. 새로 생기는
    // 것은 다이얼로그 없는 `status()` 하나뿐이라 4.1·4.2 의 측위 절제는
    // 그대로다(위 fixReads 단언이 그것도 함께 지킨다).
  );

  testWidgets(
    'Q1-b) 그 구멍은 시간 창이 닫히면 스스로 닫힌다 — 다만 그때까지 최대 다섯 시간이다',
    (tester) async {
      final h = await _pump(tester, at: _anchor.atGame, spot: _atStadium());
      await _dismissReveal(tester);
      expect(_locationRowStands(), isTrue);

      // 권한을 끈 채 창이 닫힌 뒤(시작 + 5시간)에 돌아온다.
      h.gateway.current = LocationPermissionStatus.denied;
      h.clock.now = _anchor.afterWindow;
      await _resume(tester);

      expect(
        _locationRowStands(),
        isFalse,
        reason:
            '게이트가 열리면 재판정이 권한을 다시 보고 자리를 접는다 — '
            'Q1 의 구멍이 영구적이지 않다는 것을 여기서 잰다',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'Q2) 대조군 — 도장을 못 받은 사람이 같은 행동을 하면 자리가 접힌다',
    (tester) async {
      final h = await _pump(
        tester,
        at: _anchor.atGame,
        // 구장 밖 — 같은 날 같은 시각이지만 도장이 나오지 않는다.
        spot: _offStadium(),
      );
      expect(h.store.stampUploads, isEmpty);
      expect(_locationRowStands(), isTrue);

      h.gateway.current = LocationPermissionStatus.denied;
      h.clock.now = _anchor.at(const Duration(hours: 1, minutes: 30));
      await _resume(tester);

      expect(
        _locationRowStands(),
        isFalse,
        reason: '게이트가 열려 있으면 재판정이 권한을 다시 보고 자리를 접는다',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test('Q3) 5.1 의 최근 5경기가 실 일정 문서(schemaVersion 2)와 어긋나지 않는다', () {
    final schedule = _content.schedule;
    final teams = _content.teams;
    expect(readLiveJson('schedule.json')['schemaVersion'], 2);

    for (final team in teams.teams) {
      final picked = recentGamesFor(schedule: schedule, teamId: team.id);
      expect(
        picked.length,
        lessThanOrEqualTo(kRecentGamesLimit),
        reason: '${team.id}: 최대 5개',
      );

      // 같은 것을 다른 길로 다시 계산해 대조한다.
      final expected =
          schedule.games
              .where(
                (g) =>
                    g.status == GameStatus.finished &&
                    (g.homeTeamId == team.id || g.awayTeamId == team.id),
              )
              .toList()
            ..sort((a, b) {
              final byDate = b.date.compareTo(a.date);
              return byDate != 0 ? byDate : b.startTime.compareTo(a.startTime);
            });
      expect(
        picked.map((g) => g.id).toList(),
        expected.take(kRecentGamesLimit).map((g) => g.id).toList(),
        reason: '${team.id}: 최신순 다섯',
      );

      for (final game in picked) {
        // 점수·승패가 화면에 나갈 수 있는 값인가 (5.1 acceptance 1).
        expect(game.homeScore, isNotNull, reason: game.id);
        expect(game.awayScore, isNotNull, reason: game.id);
        expect(game.result, isNotNull, reason: game.id);
        final mine = game.homeTeamId == team.id
            ? game.homeScore!
            : game.awayScore!;
        final theirs = game.homeTeamId == team.id
            ? game.awayScore!
            : game.homeScore!;
        final outcome = outcomeFor(game, team.id);
        expect(
          outcome,
          mine > theirs
              ? TeamGameOutcome.win
              : mine < theirs
              ? TeamGameOutcome.loss
              : TeamGameOutcome.draw,
          reason: '${game.id}: 점수와 승패 표기가 어긋나면 화면이 거짓을 말한다',
        );
      }
    }
  });

  testWidgets(
    'Q4) 종료된 경기가 하나도 없는 일정에서는 홈 중단에 빈 상태가 뜬다',
    (tester) async {
      // 실 문서에서 종료 경기를 전부 걷어 낸 일정 — 개막 전의 모양이다.
      final raw = readLiveJson('schedule.json');
      final games = (raw['games']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .where((g) => g['status'] != 'finished')
          .toList();
      final schedule = ScheduleDocument.fromJson({...raw, 'games': games});
      expect(
        recentGamesFor(schedule: schedule, teamId: _anchor.teamId),
        isEmpty,
      );

      SharedPreferences.setMockInitialValues({});
      final auth = FakeAuthService(
        signedIn: const AuthUser(uid: _uid, email: 'a@b.c'),
      );
      final store = FakeUserDataStore();
      addTearDown(auth.dispose);
      addTearDown(store.dispose);
      await store.createProfile(
        _uid,
        NewUserProfile(nickname: '원정러', favoriteTeamId: _anchor.teamId),
      );
      final teams = _content.teams;
      final stadiums = _content.stadiums;
      final places = _content.places;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            userDataStoreProvider.overrideWithValue(store),
            locationPermissionGatewayProvider.overrideWithValue(
              _SettingsGateway(LocationPermissionStatus.denied),
            ),
            weatherEffectProvider.overrideWith(
              (ref, point) async => WeatherEffect.none,
            ),
            clockProvider.overrideWithValue(() => _noGameDay),
            teamsProvider.overrideWith((ref) async => ContentFresh(teams)),
            stadiumsProvider.overrideWith(
              (ref) async => ContentFresh(stadiums),
            ),
            placesProvider.overrideWith((ref) async => ContentFresh(places)),
            scheduleProvider.overrideWith(
              (ref) async => ContentFresh(schedule),
            ),
            stadiumVisitCheckerProvider.overrideWith(
              (ref) => StadiumVisitChecker(
                readPermission: () async => LocationPermissionStatus.denied,
                readFix: () async => null,
              ),
            ),
          ],
          child: const MaterialApp(home: MainTabsRoot()),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        find.text('아직 경기 결과가 없어요', skipOffstage: false),
        findsOneWidget,
        reason: '5.1 acceptance 3: 하나도 없으면 빈 상태가 뜬다',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
