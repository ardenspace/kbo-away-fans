/// phase 4 통합 검증 탐침(2회차) — 다섯 단계를 **하루 단위로** 걸어 본다.
///
/// `phase4_journey_probe_test.dart` 가 재는 것은 "구장에서 앱을 여는 한
/// 실행"이다. 이 파일이 재는 것은 그 실행의 **앞뒤**다: 시각이 창을 넘어가고,
/// 앱이 포그라운드로 돌아오고, 앞선 실행이 이미 남긴 도장이 서버에 있는 채로
/// 앱이 다시 뜨는 자리들.
///
///  A) 서버에 오늘 도장이 이미 있는 콜드 스타트에서 연출이 **다시 뜨지
///     않는다** — `StampAward.award` 의 `alreadyStamped → null` 갈래다.
///     실측(변이 주입): 그 한 줄을 지워도 저장소 전체가 초록불이었다.
///  B) 하루를 끝까지 걷는다 — 창이 열리기 전의 안내(4.5) → 창 안에서의
///     도장·연출(4.1·4.2·4.4) → 판 반영(4.3) → 창이 닫힌 뒤의 침묵 →
///     다음 날의 안내. 시각을 실제로 옮기고 포그라운드 복귀로 판정을 다시
///     돌려, 안내 갈래들이 **실 판정 경로**에서 서는지를 잰다(4.5 의 경계
///     시험은 판정 결과를 고정값으로 갈아 끼운다).
///  C) 권한 거부 안내에서 허용을 받으면 그 자리에서 판정·도장·연출·판이
///     한 줄로 이어지고 안내가 사라진다 — 4.5 → 4.1 → 4.2 → 4.4 → 4.3.
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
import 'package:kbo_away_fans/features/badges/visit_status_notice.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';
import '../../location/fake_location_permission_gateway.dart';

const String _uid = 'google-uid';
const double _jamsilLat = 37.5121;
const double _jamsilLng = 127.0719;
const ContentIssue _fixture = ContentIssue(ContentIssueKind.network, 'fixture');

final StadiumsDocument _stadiums = StadiumsDocument(
  stadiums: [
    Stadium(
      id: 'jamsil',
      name: '잠실야구장',
      city: '서울',
      lat: _jamsilLat,
      lng: _jamsilLng,
      homeTeams: const ['lg', 'doosan'],
    ),
  ],
);

final ScheduleDocument _schedule = ScheduleDocument(
  generatedAt: DateTime.utc(2026),
  games: const [
    Game(
      id: 'g-jamsil',
      date: '2026-08-25',
      startTime: '18:30',
      homeTeamId: 'lg',
      awayTeamId: 'doosan',
      stadiumId: 'jamsil',
      status: GameStatus.scheduled,
    ),
  ],
);

/// 지금 시각을 바꿔 가며 하루를 걷는다.
class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

class _Harness {
  _Harness({
    required this.store,
    required this.auth,
    required this.clock,
    required this.gateway,
  });
  final FakeUserDataStore store;
  final FakeAuthService auth;
  final _Clock clock;
  final FakeLocationPermissionGateway gateway;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  required DateTime at,
  LocationPermissionStatus permission = LocationPermissionStatus.granted,
  LocationPermissionStatus? afterRequest,
  bool atStadium = true,
  bool offline = false,
  void Function(FakeUserDataStore store)? seed,
}) async {
  SharedPreferences.setMockInitialValues({});
  final auth = FakeAuthService(
    signedIn: const AuthUser(uid: _uid, email: 'a@b.c'),
  );
  final store = FakeUserDataStore();
  final clock = _Clock(at);
  final gateway = FakeLocationPermissionGateway(
    initial: permission,
    afterRequest: afterRequest,
  );
  addTearDown(auth.dispose);
  addTearDown(store.dispose);
  await store.createProfile(
    _uid,
    const NewUserProfile(nickname: '원정러', favoriteTeamId: 'lg'),
  );
  seed?.call(store);
  store.offline = offline;

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
        stadiumsProvider.overrideWith((ref) async => ContentFresh(_stadiums)),
        scheduleProvider.overrideWith((ref) async => ContentFresh(_schedule)),
        placesProvider.overrideWith(
          (ref) async => const ContentUnavailable<PlacesDocument>(_fixture),
        ),
        teamsProvider.overrideWith(
          (ref) async => const ContentUnavailable<TeamsDocument>(_fixture),
        ),
        stadiumVisitCheckerProvider.overrideWith((ref) {
          final g = ref.watch(locationPermissionGatewayProvider);
          return StadiumVisitChecker(
            readPermission: g.status,
            readFix: () async {
              await Future<void>.delayed(const Duration(milliseconds: 1));
              return atStadium
                  ? const DeviceFix(lat: _jamsilLat, lng: _jamsilLng)
                  : const DeviceFix(lat: 37.0, lng: 127.0);
            },
          );
        }),
      ],
      child: const MaterialApp(home: MainTabsRoot()),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 5));
  return _Harness(store: store, auth: auth, clock: clock, gateway: gateway);
}

Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

Future<void> _openBadges(WidgetTester tester) async {
  // 연출이 떠 있으면 첫 탭이 그것을 닫는다.
  await tester.tap(find.text('배지'));
  await tester.pumpAndSettle(const Duration(seconds: 5));
  if (find.byType(StampReveal).evaluate().isNotEmpty) {
    await tester.tap(find.text('배지'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }
}

void main() {
  testWidgets(
    'A) 서버에 오늘 도장이 이미 있는 콜드 스타트는 연출을 다시 띄우지 않는다',
    (tester) async {
      final h = await _pump(
        tester,
        at: DateTime.parse('2026-08-25T17:30:00+09:00'),
        seed: (store) {
          // 앞선 실행에서 이미 찍은 도장 — 서버에도 판에도 남아 있다.
          store.stamps[_uid] = {
            'jamsil_g-jamsil': const StampWrite(
              stadiumId: 'jamsil',
              gameId: 'g-jamsil',
              homeTeamId: 'lg',
              gameDate: '2026-08-25',
            ).toData(),
          };
          final document = store.documents[_uid]!;
          store.documents[_uid] = {
            ...document,
            UserFields.board: <String, Object?>{
              'jamsil_lg': BoardCell.forCount(
                count: 1,
                lastStampedOn: '2026-08-25',
              ).toData(),
            },
          };
        },
      );

      expect(
        find.byType(StampReveal),
        findsNothing,
        reason: '몇 시간 전에 받은 도장의 연출이 앱을 다시 열 때 뜨면 안 된다',
      );
      expect(h.store.stampUploads, isEmpty);
      expect((await h.store.readProfile(_uid))!.board['jamsil_lg']!.count, 1);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'B) 하루를 끝까지 걷는다 — 창 전 안내 → 도장 → 창 후 침묵 → 다음 날 안내',
    (tester) async {
      // 09:00 — 오늘 경기는 있지만 창(15:30~23:30)은 아직 열리지 않았다.
      final h = await _pump(
        tester,
        at: DateTime.parse('2026-08-25T09:00:00+09:00'),
      );
      await _openBadges(tester);
      expect(
        find.text(VisitStatusNotice.outsideTimeWindowTitle),
        findsOneWidget,
        reason: '창 밖이면 그 이유가 배지 탭에 뜬다',
      );

      // 17:30 — 창 안. 포그라운드 복귀가 판정을 다시 돌린다.
      h.clock.now = DateTime.parse('2026-08-25T17:30:00+09:00');
      await _resume(tester);
      expect(
        find.byType(StampReveal),
        findsOneWidget,
        reason: '도장이 찍히고 연출이 뜬다',
      );
      await tester.tap(find.byType(StampReveal));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(h.store.stampUploads, ['jamsil_g-jamsil']);
      expect((await h.store.readProfile(_uid))!.board['jamsil_lg']!.count, 1);
      expect(
        find.text(VisitStatusNotice.outsideTimeWindowTitle),
        findsNothing,
        reason: '도장을 받은 뒤에는 옛 안내가 남아 있으면 안 된다',
      );

      // 23:45 — 창이 닫힌 뒤 집에서 앱을 다시 켠다.
      h.clock.now = DateTime.parse('2026-08-25T23:45:00+09:00');
      await _resume(tester);
      expect(
        find.text(VisitStatusNotice.outsideRadiusTitle),
        findsNothing,
        reason: '오늘 도장을 받은 사람에게 "못 받는 날" 안내가 붙으면 안 된다',
      );
      expect(find.text(VisitStatusNotice.outsideTimeWindowTitle), findsNothing);

      // 다음 날 아침 — 경기가 없는 날.
      h.clock.now = DateTime.parse('2026-08-26T09:00:00+09:00');
      await _resume(tester);
      expect(
        find.text(VisitStatusNotice.noGameTodayTitle),
        findsOneWidget,
        reason: '다음 날에는 "오늘은 경기가 없어요"가 뜬다',
      );
      expect(h.store.stampUploads, ['jamsil_g-jamsil'], reason: '도장은 하나 그대로다');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'C) 권한 거부 안내에서 허용하면 그 자리에서 판정·도장·연출·판이 이어진다',
    (tester) async {
      final h = await _pump(
        tester,
        at: DateTime.parse('2026-08-25T17:30:00+09:00'),
        permission: LocationPermissionStatus.denied,
        afterRequest: LocationPermissionStatus.granted,
      );
      await _openBadges(tester);
      expect(
        find.text(VisitStatusNotice.permissionMissingTitle),
        findsOneWidget,
      );
      expect(
        find.text(VisitStatusNotice.requestPermissionLabel),
        findsOneWidget,
      );

      await tester.tap(find.text(VisitStatusNotice.requestPermissionLabel));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(h.gateway.requestCalls, 1);
      expect(h.store.stampUploads, [
        'jamsil_g-jamsil',
      ], reason: '허용 직후 도장이 찍힌다');
      expect(
        find.byType(StampReveal),
        findsOneWidget,
        reason: '그 도장의 연출이 배지 탭 위에 뜬다',
      );
      await tester.tap(find.byType(StampReveal));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(
        find.text(VisitStatusNotice.permissionMissingTitle),
        findsNothing,
        reason: '도장을 받은 뒤에도 권한 안내가 남아 있으면 안 된다',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
