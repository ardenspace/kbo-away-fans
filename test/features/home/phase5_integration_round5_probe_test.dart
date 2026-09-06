/// phase 5 통합 검증(다섯째 눈)의 탐침 — 앞선 세 탐침
/// (`phase5_seam_probe_test.dart` · `phase5_integration_audit_probe_test.dart` ·
/// `phase5_integration_round3_probe_test.dart`)이 걷지 **않은** 이음매만 걷는다.
///
/// 이 파일이 재는 것:
///
///  R1) **4.5 의 안내에서 5.2 의 자리로 건너오는 길.** 권한을 거부한 채 앱을
///      연 사람은 홈 상단에 아무것도 못 본다(자리가 접힌다). 그 사람이 권한을
///      다시 여는 진입점은 홈이 아니라 배지 탭의 `VisitStatusNotice` 하나뿐
///      이고(5.2 가 "재요청 버튼을 두지 않는다"고 정한 대가다), 그 버튼을
///      누른 뒤 홈으로 돌아왔을 때 위치 자리가 서지 않으면 그 사람은 홈에서
///      위치를 되살릴 길이 아예 없다. 두 탭에 걸친 그 길을 앞선 탐침들은
///      걷지 않았다 — 이 저장소의 두 화면이 권한 provider 하나를 함께 쓰게
///      된 것도 phase 5 이므로, 그 승격이 4.5 를 깨지 않았는지도 여기서 함께
///      잰다.
///
///  R2) **한 화면이 같은 경기를 두 번 말하는 자리.** 5.1 이 홈 중단에 과거
///      경기를 세우면서, 2.3 의 D-day 얼굴과 **같은 경기**가 한 화면에 동시에
///      설 수 있게 됐다 — `findNextAwayGame` 은 오늘 끝난 원정 경기도 "오늘"
///      로 세고(그 계약이 `next_away_game_test.dart` 에 못 박혀 있다),
///      `recentGamesFor` 는 같은 경기를 "최근 결과"로 센다. 실 일정
///      (`content-pipeline/data/schedule.json`)에서 그런 경기를 **실행
///      시점에 골라**, 그 화면이 무엇을 말하는지를 값으로 적어 둔다.
///
///  R3) **사람의 행동에 비례해 조회가 늘지 않는가.** 5.2 는 판정이 권한을
///      대신 말해 주지 못하는 갈래에서 `locationPermissionStatusProvider` 를
///      구독한다. 그 provider 는 `autoDispose` 라 구독이 끊겼다 이어지면 새
///      답을 낸다 — 탭을 오가는 것만으로 조회가 늘면 그것이 곧 4.1 의 절제를
///      갉아먹는 자리다. 탭 이동·스크롤·복귀를 실제로 걸어 조회 횟수와 측위
///      횟수를 값으로 잰다.
///
///  R4) **복귀 직후 첫 프레임.** `StadiumVisitTrigger` 의 문서가 "판정보다
///      먼저 권한 답을 버린다 — 그래야 이 복귀에서 다시 그리는 화면이 옛 답을
///      **한 프레임도** 참으로 쓰지 않는다"고 적었다. 그 문장이 참인지를
///      프레임 하나 단위로 잰다.
///
///  R5) **두 자리의 순서를 한 화면에서 함께 못 박는다.** 5.2 의 "상단"은
///      단계 시험이 목록의 첫 자식으로 재고 있지만, 5.1 의 "홈 중단"(Goal)은
///      실 배선 위에서 자리로 재는 못이 없다. 화면을 충분히 길게 잡아 네
///      자리(위치 · D-day 얼굴 · 최근 5경기 · 구장 골라 구경하기)의 세로
///      좌표를 그대로 비교한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/features/badges/stamp_reveal.dart';
import 'package:kbo_away_fans/features/badges/visit_status_notice.dart';
import 'package:kbo_away_fans/features/home/current_location.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/ui/shared/dday_header.dart';
import 'package:kbo_away_fans/ui/shared/stadium_picker.dart';
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

/// 이 탐침이 두고 재는 원정 경기 — **실행 시점에 실 일정에서 고른다.**
///
/// 날짜도 경기 id 도 여기 적지 않는다. 이 문서는 크롤이 경기 시간대에
/// 20분마다 다시 쓰고 그 창이 앞뒤로 움직이므로, 고른 경기를 리터럴로 박으면
/// 아무도 코드를 건드리지 않아도 이 파일이 빨간불이 된다
/// (`test/content/live_schedule.dart` 첫 문단 — R2·R5 가 실제로 그렇게
/// 빨간불이 된 적이 있다).
late AwayGameAnchor _anchor;

/// 리그 전체에 경기가 하나도 없는 시각 — `judgeStadiumVisit` 이 권한을 묻기도
/// 전에 `noGameToday` 로 끝나는 갈래.
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

/// 권한 게이트웨이 대역 — 조회 횟수를 세고, **앱 밖에서**(OS 설정) 바뀌는
/// 것과 **앱 안에서**([request] 다이얼로그) 바뀌는 것을 둘 다 흉내 낸다.
class _Gateway extends LocationPermissionGateway {
  _Gateway(this._status, this._afterRequest);

  LocationPermissionStatus _status;
  final LocationPermissionStatus _afterRequest;

  int statusCalls = 0;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  /// OS 설정에서 사람이 바꾼 것 — 앱은 다시 물어야만 알 수 있다.
  void setFromSettings(LocationPermissionStatus next) => _status = next;

  @override
  Future<LocationPermissionStatus> status() async {
    statusCalls++;
    return _status;
  }

  @override
  Future<LocationPermissionStatus> request() async {
    requestCalls++;
    _status = _afterRequest;
    return _status;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return true;
  }
}

class _Spot {
  _Spot({required this.lat, required this.lng});
  double lat;
  double lng;
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
  final _Gateway gateway;
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
  LocationPermissionStatus? afterRequest,
}) async {
  SharedPreferences.setMockInitialValues({});
  final auth = FakeAuthService(
    signedIn: const AuthUser(uid: _uid, email: 'a@b.c'),
  );
  final store = FakeUserDataStore();
  final clock = _Clock(at);
  final gateway = _Gateway(permission, afterRequest ?? permission);
  final fixReads = <int>[];
  addTearDown(auth.dispose);
  addTearDown(store.dispose);
  final team = teamId ?? _anchor.teamId;
  await store.createProfile(
    _uid,
    NewUserProfile(
      nickname: '원정러',
      favoriteTeamId: team,
      profileThemeKey: team,
    ),
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

/// 배경 → 포그라운드. [settle] 이 거짓이면 프레임 하나만 그린다 (R4).
Future<void> _resume(WidgetTester tester, {bool settle = true}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  if (settle) {
    await tester.pumpAndSettle(const Duration(seconds: 5));
  } else {
    await tester.pump();
  }
}

Future<void> _dismissReveal(WidgetTester tester) async {
  if (find.byType(StampReveal).evaluate().isNotEmpty) {
    await tester.tap(find.byType(StampReveal));
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }
}

Future<void> _goTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle(const Duration(seconds: 5));
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
    'R1) 권한을 거부한 사람이 배지 탭에서 허용하면 홈 상단 위치 자리가 선다 (4.5 → 5.2)',
    (tester) async {
      // 5.2 는 홈에 재요청 버튼을 두지 않기로 했다 — "권한을 다시 묻는
      // 진입점은 이미 배지 탭에 있다"가 그 근거다. 그렇다면 그 진입점을
      // 지난 사람의 홈이 실제로 살아나야 그 근거가 선다.
      final h = await _pump(
        tester,
        at: _anchor.atGame,
        spot: _atStadium(),
        permission: LocationPermissionStatus.denied,
        afterRequest: LocationPermissionStatus.granted,
      );

      expect(
        _locationRowStands(),
        isFalse,
        reason: '권한이 없으면 홈 상단 자리가 접힌다 (5.2 acceptance 2)',
      );
      expect(h.fixReads, isEmpty, reason: '권한이 없는 실행에서는 측위하지 않는다 (4.1)');

      await _goTab(tester, '배지');
      expect(
        find.text(VisitStatusNotice.permissionMissingTitle),
        findsOneWidget,
        reason: '권한을 다시 여는 유일한 진입점이 여기다',
      );

      await tester.tap(find.text(VisitStatusNotice.requestPermissionLabel));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await _dismissReveal(tester);

      expect(h.gateway.requestCalls, 1);

      await _goTab(tester, '홈');
      expect(
        _locationRowStands(),
        isTrue,
        reason: '배지 탭에서 허용한 권한이 홈 상단까지 와야 5.2 의 "재요청 버튼을 '
            '두지 않는다"가 선다',
      );
      expect(
        find.text(_anchor.nearbyLabel),
        findsOneWidget,
        reason: '그 자리에서 다시 돈 판정이 구장까지 말해 준다 (${_anchor.game.id})',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'R2) 오늘 끝난 원정 경기 — 한 화면이 같은 경기를 "오늘"과 "최근 결과"로 함께 말한다',
    (tester) async {
      // 이 시험은 **거동을 값으로 적어 두는 자리**다(계약이 금지한 것이
      // 아니라, 두 단계가 같은 경기를 다르게 부르는 이음매를 눈에 보이게
      // 둔다). 실 일정에서 고른 그 팀의 끝난 원정 경기 하나를 두고, 그 경기가
      // 끝난 뒤 같은 날 저녁에 홈을 보면:
      //   · D-day 얼굴 — `findNextAwayGame` 이 "오늘"로 센다
      //     (`next_away_game_test.dart` 의 "오늘 끝난 원정 경기" 그룹).
      //   · 최근 5경기 — `recentGamesFor` 가 같은 경기를 한 줄로 세운다.
      // 둘이 한 화면에 함께 선다.
      //
      // 어느 경기인지는 산출물이 정한다 — 앵커가 "그날 그 구장·그 팀의
      // 유일한 경기이고 최근 다섯 줄 안에서 날짜·점수 표기가 겹치지 않는
      // 경기"를 고르므로, 아래 네 단언은 셋 다 **그 경기 하나**를 가리킨다.
      await _pump(tester, at: _anchor.atGame, spot: _offStadium());
      await _dismissReveal(tester);

      final where = '앵커: ${_anchor.game.id}';
      expect(
        find.text('오늘'),
        findsOneWidget,
        reason: '2.3 의 얼굴은 오늘 끝난 원정 경기도 "오늘"로 센다 ($where)',
      );
      expect(
        find.text(_anchor.matchLabel),
        findsOneWidget,
        reason: '얼굴이 가리키는 경기가 그 경기다 ($where)',
      );
      expect(
        find.text(_anchor.dayLabel, skipOffstage: false),
        findsOneWidget,
        reason: '5.1 의 한 줄이 같은 경기의 날짜를 다시 적는다 ($where)',
      );
      expect(
        find.text(_anchor.scoreLabel, skipOffstage: false),
        findsOneWidget,
        reason: '같은 경기가 결과로도 한 번 더 선다 ($where)',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'R3) 탭을 오가고 스크롤해도 권한 조회·측위가 늘지 않는다 (복귀당 한 번)',
    (tester) async {
      // 5.2 가 새로 만든 유일한 I/O 가 다이얼로그 없는 `status()` 하나다.
      // 그 조회를 붙잡고 있는 provider 는 `autoDispose` 라, 구독이 끊겼다
      // 이어지면 새 답을 낸다 — 사람이 탭을 오가는 것만으로 조회가 늘면
      // 4.1 의 절제가 조용히 갉아먹힌다.
      final h = await _pump(tester, at: _noGameDay, spot: _offStadium());

      expect(
        _locationRowStands(),
        isTrue,
        reason: '경기 없는 날 + 권한 있음 — 자리가 선다 (5.2 acceptance 1)',
      );
      final afterBoot = h.gateway.statusCalls;
      expect(afterBoot, 1, reason: '부팅 한 번에 권한 조회도 한 번이다');
      expect(h.fixReads, isEmpty, reason: '후보가 없는 날은 측위하지 않는다 (4.1)');

      for (final tab in ['배지', '추천', '좋아요', '마이페이지', '홈', '배지', '홈']) {
        await _goTab(tester, tab);
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, -200));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(
        h.gateway.statusCalls,
        afterBoot,
        reason: '탭 이동·스크롤은 권한을 다시 물을 까닭이 아니다',
      );
      expect(h.fixReads, isEmpty, reason: '탭 이동이 GPS 를 켜지 않는다');

      await _resume(tester);
      expect(
        h.gateway.statusCalls,
        afterBoot + 1,
        reason: '복귀당 한 번 — 앱 밖에서 권한이 바뀌었을 수 있는 유일한 순간이다',
      );
      await _resume(tester);
      expect(h.gateway.statusCalls, afterBoot + 2);
      expect(h.fixReads, isEmpty, reason: '경기 없는 날은 복귀해도 측위가 없다');
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'R4) 복귀 직후 첫 프레임 — 옛 권한 답을 참으로 쓰는가',
    (tester) async {
      // `StadiumVisitTrigger` 의 문서가 "이 복귀에서 다시 그리는 화면이 옛
      // 답을 **한 프레임도** 참으로 쓰지 않는다"고 적었다. 그 문장을 프레임
      // 하나로 잰다 — 경기 없는 날이라 홈 상단의 답은 오직
      // `locationPermissionStatusProvider` 에서 온다.
      final h = await _pump(tester, at: _noGameDay, spot: _offStadium());
      expect(_locationRowStands(), isTrue);

      // 사람이 OS 설정에서 권한을 껐다.
      final before = h.gateway.statusCalls;
      h.gateway.setFromSettings(LocationPermissionStatus.denied);
      await _resume(tester, settle: false);

      // 이 두 줄이 그 프레임을 못 박는다: 되묻기는 **이미 떠났고**(그래서
      // "아직 안 물었다"로 넘어갈 수 없다), 그런데 화면은 그 답을 기다리지
      // 않고 그려졌다.
      expect(
        h.gateway.statusCalls,
        before + 1,
        reason: '복귀가 권한 답을 이미 버렸다 — 조회는 떠나 있다',
      );
      final standsOnFirstFrame = _locationRowStands();

      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(
        _locationRowStands(),
        isFalse,
        reason: '답이 오면 자리가 접힌다 (5.2 acceptance 2 — round 3 이 닫은 자리)',
      );

      // **이 값이 이 탐침의 산출물이다.** 참이면 위 문서 문장이 과장이라는
      // 뜻이고(자리가 옛 답으로 한 프레임 더 서 있다), 거짓이면 그대로다.
      // 어느 쪽이든 거동을 값으로 붙잡아 둔다 — 다음 사람이 이 문장을 믿을지
      // 말지를 실측으로 정할 수 있게.
      expect(
        standsOnFirstFrame,
        isTrue,
        reason: '실측: 되묻는 답이 오기 전 프레임에서는 `AsyncValue.value` 가 옛 답을 '
            '그대로 돌려주므로 자리가 한 프레임 더 서 있다',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  testWidgets(
    'R5) 네 자리의 세로 순서 — 위치(상단) · 얼굴 · 최근 5경기(중단) · 구장 고르기',
    (tester) async {
      // 5.2 의 "상단"은 단계 시험이 목록의 첫 자식으로 재고 있지만, 5.1 의
      // "홈 중단"(Goal)을 자리로 재는 못은 실 배선 위에 없었다. 화면을 충분히
      // 길게 잡아 네 자리를 한 번에 레이아웃하고 세로 좌표를 그대로 본다.
      tester.view.physicalSize = const Size(1000, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester, at: _anchor.atGame, spot: _atStadium());
      await _dismissReveal(tester);

      final location = tester.getTopLeft(find.byKey(kCurrentLocationRowKey)).dy;
      final face = tester.getTopLeft(find.byType(DdayHeader)).dy;
      final recent = tester.getTopLeft(find.text('최근 5경기')).dy;
      final picker = tester.getTopLeft(find.byType(StadiumPicker)).dy;

      expect(location, lessThan(face), reason: '위치 자리가 얼굴보다 위다 (5.2 "상단")');
      expect(face, lessThan(recent), reason: '최근 5경기는 얼굴 아래다 (5.1 "홈 중단")');
      expect(
        recent,
        lessThan(picker),
        reason: '최근 5경기는 하단의 탐색 진입점보다 위다 — 그래야 "중단"이다',
      );

      // 그 자리에 실제로 최근 경기 줄이 서 있는지도 같은 화면에서 함께 잰다 —
      // 순서만 맞고 내용이 비면 "중단에 요약을 보여 준다"가 아니다.
      expect(find.text(_anchor.dayLabel), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(_anchor.dayLabel)).dy,
        greaterThan(recent),
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
