/// Step 4.5 boundary tests — 배지 탭의 방문 판정 안내.
///
/// 재는 갈래:
///  1) 권한 거부(`permissionMissing`)는 이유 안내 + 설정으로 가는 경로가
///     있다 — 다시 물을 수 있으면(`denied`) 앱 안에서 다시 묻고, 영구
///     거절(`permanentlyDenied`)이면 설정 앱을 연다.
///  2) 판정 실패(그 밖의 네 이유)는 권한 거부와 다른 문구로 안내하고, 이유
///     넷끼리도 서로 다른 문구다.
///  3) 권한이 없어도(그리고 판정이 아예 없어도) 판은 그대로 열리고 빈 칸이
///     보인다.
///  4) 추천·좋아요·홈은 위치 권한과 무관하게 그대로 동작한다 — 앱 골격
///     전체를 위치 권한 거부 상태로 띄워 세 탭이 실제로 렌더되는지, 그리고
///     배지 탭까지 본 뒤에도 추천·좋아요를 오가는 동안 위치 게이트웨이가
///     더 불리지 않는지를 함께 잰다(배지 탭 자신은 재요청 여부를 가르려고
///     정당하게 다시 묻는 쪽이라 그 호출은 기준에 넣지 않는다).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/badges/badges_tab_screen.dart';
import 'package:kbo_away_fans/features/badges/stadium_visit.dart';
import 'package:kbo_away_fans/features/badges/visit_status_notice.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart' show clockProvider;
import 'package:kbo_away_fans/features/likes/likes_tab_screen.dart';
import 'package:kbo_away_fans/features/places/recommend_tab_screen.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/ui/shared/stadium_picker.dart';
import 'package:kbo_away_fans/ui/shared/stamp_badge.dart';
import 'package:kbo_away_fans/ui/shared/stamp_board.dart';
import 'package:kbo_away_fans/weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';
import '../../location/fake_location_permission_gateway.dart';

const _uid = 'kakao:1234567890';

/// [stadiumVisitProvider] 를 고정된 값으로 갈아 끼우는 대역 — 실 판정을
/// 돌리지 않고 안내 위젯만 재는 시험에 쓴다. [run] 이 불린 횟수도 센다
/// ([_PermissionMissingNotice] 가 허용을 받은 뒤 판정을 다시 도는지 재기
/// 위해서다).
class _FixedStadiumVisitCheck extends StadiumVisitCheck {
  _FixedStadiumVisitCheck(this._fixed);

  final StadiumVisitResult? _fixed;

  /// [run] 이 불린 횟수.
  int runCalls = 0;

  @override
  StadiumVisitResult? build() => _fixed;

  @override
  Future<void> run() async {
    runCalls++;
  }
}

/// 2026-08-25(화) KST 20:00 — 그날 14:00 경기의 시간 창(19:00 에 닫힌다) 밖.
final DateTime _afterWindowClosed = DateTime.parse('2026-08-25T20:00:00+09:00');

/// 칸 요약 하나짜리 판 — [day] 가 그 칸의 마지막 도장 날짜다.
Map<String, BoardCell> _boardStampedOn(String day) => {
  'jamsil_lg': BoardCell.forCount(count: 1, lastStampedOn: day),
};

/// [VisitStatusNotice] 하나만 세우는 host — 판 없이 안내 위젯의 모습만 잰다.
Widget _noticeHost({
  required StadiumVisitResult? visit,
  LocationPermissionGateway? gateway,
  Map<String, BoardCell> board = const {},
  DateTime? now,
}) {
  return ProviderScope(
    overrides: [
      stadiumVisitProvider.overrideWith(() => _FixedStadiumVisitCheck(visit)),
      if (gateway != null)
        locationPermissionGatewayProvider.overrideWithValue(gateway),
      if (now != null) clockProvider.overrideWithValue(() => now),
    ],
    child: MaterialApp(
      home: Scaffold(body: VisitStatusNotice(board: board)),
    ),
  );
}

void main() {
  group('권한 거부 — 이유 안내 + 설정으로 가는 경로', () {
    testWidgets('다시 물을 수 있으면(denied) "위치 권한 허용하기" 버튼이 있다', (tester) async {
      final gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.denied,
      );

      await tester.pumpWidget(
        _noticeHost(
          visit: const StadiumVisitResult.rejected(
            StadiumVisitReason.permissionMissing,
          ),
          gateway: gateway,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(VisitStatusNotice.permissionMissingTitle), findsOneWidget);
      expect(
        find.text(VisitStatusNotice.requestPermissionLabel),
        findsOneWidget,
      );
      expect(
        find.text(VisitStatusNotice.openSettingsLabel),
        findsNothing,
        reason: '다시 물을 수 있는 상태에서는 설정 대신 앱 안에서 묻는다',
      );
    });

    testWidgets('영구 거절(permanentlyDenied)이면 "설정에서 허용하기" 버튼이 있다', (
      tester,
    ) async {
      final gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.permanentlyDenied,
      );

      await tester.pumpWidget(
        _noticeHost(
          visit: const StadiumVisitResult.rejected(
            StadiumVisitReason.permissionMissing,
          ),
          gateway: gateway,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(VisitStatusNotice.openSettingsLabel), findsOneWidget);
      expect(
        find.text(VisitStatusNotice.requestPermissionLabel),
        findsNothing,
      );
    });

    testWidgets('영구 거절에서 버튼을 누르면 설정 앱을 연다', (tester) async {
      final gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.permanentlyDenied,
      );

      await tester.pumpWidget(
        _noticeHost(
          visit: const StadiumVisitResult.rejected(
            StadiumVisitReason.permissionMissing,
          ),
          gateway: gateway,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(VisitStatusNotice.openSettingsLabel));
      await tester.pumpAndSettle();

      expect(gateway.openSettingsCalls, 1);
      expect(gateway.requestCalls, 0, reason: '영구 거절 상태에서는 OS 다이얼로그를 다시 띄우지 않는다');
    });

    testWidgets('다시 물을 수 있는 상태에서 버튼을 누르면 OS 에 다시 묻는다', (tester) async {
      final gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.denied,
        afterRequest: LocationPermissionStatus.denied,
      );

      await tester.pumpWidget(
        _noticeHost(
          visit: const StadiumVisitResult.rejected(
            StadiumVisitReason.permissionMissing,
          ),
          gateway: gateway,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(VisitStatusNotice.requestPermissionLabel));
      await tester.pumpAndSettle();

      expect(gateway.requestCalls, 1);
      expect(gateway.openSettingsCalls, 0);
    });

    testWidgets('다시 물어 허용을 받으면 판정을 그 자리에서 다시 돈다', (tester) async {
      final gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.denied,
        afterRequest: LocationPermissionStatus.granted,
      );
      final fixed = _FixedStadiumVisitCheck(
        const StadiumVisitResult.rejected(
          StadiumVisitReason.permissionMissing,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stadiumVisitProvider.overrideWith(() => fixed),
            locationPermissionGatewayProvider.overrideWithValue(gateway),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VisitStatusNotice(board: {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(VisitStatusNotice.requestPermissionLabel));
      await tester.pumpAndSettle();

      expect(gateway.requestCalls, 1);
      expect(
        fixed.runCalls,
        1,
        reason: '설정에 다녀올 필요가 없는 갈래라 다음 포그라운드 복귀를 기다리지 않는다',
      );
    });

    testWidgets('거부됐지만 여전히 다시 물을 수 있으면 판정을 다시 돌지 않는다', (tester) async {
      final gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.denied,
        afterRequest: LocationPermissionStatus.denied,
      );
      final fixed = _FixedStadiumVisitCheck(
        const StadiumVisitResult.rejected(
          StadiumVisitReason.permissionMissing,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stadiumVisitProvider.overrideWith(() => fixed),
            locationPermissionGatewayProvider.overrideWithValue(gateway),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VisitStatusNotice(board: {})),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(VisitStatusNotice.requestPermissionLabel));
      await tester.pumpAndSettle();

      expect(fixed.runCalls, 0, reason: '여전히 허용되지 않았으니 다시 판정할 이유가 없다');
    });
  });

  group('판정 실패 — 권한 거부와 다른 문구로 안내한다', () {
    const cases = <StadiumVisitReason, (String, String)>{
      StadiumVisitReason.noGameToday: (
        VisitStatusNotice.noGameTodayTitle,
        VisitStatusNotice.noGameTodayMessage,
      ),
      StadiumVisitReason.outsideRadius: (
        VisitStatusNotice.outsideRadiusTitle,
        VisitStatusNotice.outsideRadiusMessage,
      ),
      StadiumVisitReason.outsideTimeWindow: (
        VisitStatusNotice.outsideTimeWindowTitle,
        VisitStatusNotice.outsideTimeWindowMessage,
      ),
      StadiumVisitReason.locationUnavailable: (
        VisitStatusNotice.locationUnavailableTitle,
        VisitStatusNotice.locationUnavailableMessage,
      ),
    };

    for (final entry in cases.entries) {
      testWidgets('${entry.key.name} — 고유한 제목·설명, 버튼은 없다', (tester) async {
        await tester.pumpWidget(
          _noticeHost(visit: StadiumVisitResult.rejected(entry.key)),
        );
        await tester.pumpAndSettle();

        final (title, message) = entry.value;
        expect(find.text(title), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(
          find.text(VisitStatusNotice.permissionMissingTitle),
          findsNothing,
          reason: '권한 거부 문구와 섞이지 않는다',
        );
        expect(find.byType(FilledButton), findsNothing, reason: '판정 실패에는 행동 버튼이 없다');
      });
    }

    testWidgets('이유 넷의 제목이 서로 겹치지 않는다', (tester) async {
      final titles = cases.values.map((each) => each.$1).toSet();
      expect(titles, hasLength(cases.length));
    });
  });

  group('판정이 없거나 방문이면 안내 자체가 없다', () {
    testWidgets('아직 한 번도 판정하지 않았으면(null) 아무것도 그리지 않는다', (tester) async {
      await tester.pumpWidget(_noticeHost(visit: null));
      await tester.pumpAndSettle();

      expect(find.byType(VisitStatusNotice), findsOneWidget);
      expect(find.text(VisitStatusNotice.permissionMissingTitle), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('방문이면 아무것도 그리지 않는다', (tester) async {
      await tester.pumpWidget(
        _noticeHost(
          visit: const StadiumVisitResult.visited(
            stadiumId: 'jamsil',
            gameId: 'g1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Text), findsNothing);
    });
  });

  group('오늘 도장을 이미 받았으면 "못 받는 날" 안내를 하지 않는다', () {
    // 14:00 경기에서 13:00 에 도장을 받은 사람이 20:00 에도 구장 근처에서
    // 앱을 다시 켜면, 창이 닫혔으므로 재판정 게이트가 열리고 판정이 다시 돌아
    // `outsideTimeWindow` 가 남는다 — 판에는 자기 도장이 있는데 바로 그 위에
    // "지금은 도장을 받을 시간이 아니에요"가 붙던 자리다.
    //
    // 그 사실을 얻는 자리는 **판이 이미 손에 든 칸 요약**이라, 4.3 이 지킨
    // 읽기 성질("판을 여는 동안 읽는 문서가 사용자 문서 하나다")을 건드리지
    // 않는다.
    testWidgets('창이 닫힌 뒤여도 오늘 받은 도장이 있으면 안내가 없다', (tester) async {
      await tester.pumpWidget(
        _noticeHost(
          visit: const StadiumVisitResult.rejected(
            StadiumVisitReason.outsideTimeWindow,
          ),
          board: _boardStampedOn('2026-08-25'),
          now: _afterWindowClosed,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('집으로 돌아가 반경 밖이어도 마찬가지다', (tester) async {
      await tester.pumpWidget(
        _noticeHost(
          visit: const StadiumVisitResult.rejected(
            StadiumVisitReason.outsideRadius,
          ),
          board: _boardStampedOn('2026-08-25'),
          now: _afterWindowClosed,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(VisitStatusNotice.outsideRadiusTitle), findsNothing);
    });

    testWidgets('권한 거부 안내도 뜨지 않는다', (tester) async {
      await tester.pumpWidget(
        _noticeHost(
          visit: const StadiumVisitResult.rejected(
            StadiumVisitReason.permissionMissing,
          ),
          gateway: FakeLocationPermissionGateway(
            initial: LocationPermissionStatus.denied,
          ),
          board: _boardStampedOn('2026-08-25'),
          now: _afterWindowClosed,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(VisitStatusNotice.permissionMissingTitle), findsNothing);
    });

    testWidgets('어제 받은 도장은 오늘의 안내를 가리지 않는다', (tester) async {
      await tester.pumpWidget(
        _noticeHost(
          visit: const StadiumVisitResult.rejected(
            StadiumVisitReason.outsideTimeWindow,
          ),
          board: _boardStampedOn('2026-08-24'),
          now: _afterWindowClosed,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(VisitStatusNotice.outsideTimeWindowTitle),
        findsOneWidget,
        reason: '오늘 못 받은 사람에게는 이유를 그대로 알려야 한다',
      );
    });

    testWidgets('배지 탭이 실제로 자기 칸 요약을 안내에 넘긴다', (tester) async {
      // 위 시험들은 안내 위젯만 세우므로, 탭이 빈 판을 넘기도록 되돌려도
      // 전부 초록불이다. 이 시험이 그 배선을 잡는다.
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      final auth = FakeAuthService(signedIn: const AuthUser(uid: _uid));
      addTearDown(auth.dispose);
      await store.createProfile(
        _uid,
        const NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'lg',
          profileThemeKey: 'lg',
        ),
      );
      await (await store.writeStamp(
        _uid,
        const StampWrite(
          stadiumId: 'jamsil',
          gameId: 'g-jamsil',
          homeTeamId: 'lg',
          gameDate: '2026-08-25',
        ),
      )).serverConfirmed;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            userDataStoreProvider.overrideWithValue(store),
            clockProvider.overrideWithValue(() => _afterWindowClosed),
            teamsProvider.overrideWith(
              (ref) async => const ContentUnavailable<TeamsDocument>(
                ContentIssue(ContentIssueKind.network, 'fixture'),
              ),
            ),
            stadiumVisitProvider.overrideWith(
              () => _FixedStadiumVisitCheck(
                const StadiumVisitResult.rejected(
                  StadiumVisitReason.outsideTimeWindow,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: BadgesTabScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StampBoard), findsOneWidget, reason: '판은 그대로 열린다');
      expect(
        find.text(VisitStatusNotice.outsideTimeWindowTitle),
        findsNothing,
        reason: '자기 도장 바로 위에 "도장을 받을 시간이 아니다"가 붙으면 안 된다',
      );
    });
  });

  group('권한이 없어도 판은 그대로 열린다', () {
    testWidgets('permissionMissing 이어도 배지 판 10칸이 전부 보인다', (tester) async {
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      final auth = FakeAuthService(signedIn: const AuthUser(uid: _uid));
      addTearDown(auth.dispose);
      await store.createProfile(
        _uid,
        const NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'lg',
          profileThemeKey: 'lg',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            userDataStoreProvider.overrideWithValue(store),
            teamsProvider.overrideWith(
              (ref) async => const ContentUnavailable<TeamsDocument>(
                ContentIssue(ContentIssueKind.network, 'fixture'),
              ),
            ),
            stadiumVisitProvider.overrideWith(
              () => _FixedStadiumVisitCheck(
                const StadiumVisitResult.rejected(
                  StadiumVisitReason.permissionMissing,
                ),
              ),
            ),
            locationPermissionGatewayProvider.overrideWithValue(
              FakeLocationPermissionGateway(
                initial: LocationPermissionStatus.permanentlyDenied,
              ),
            ),
          ],
          child: const MaterialApp(home: BadgesTabScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StampBoard), findsOneWidget);
      expect(
        find.byType(StampBadge, skipOffstage: false),
        findsNWidgets(BadgeTokens.cellCount),
        reason: '권한이 없어도 빈 칸까지 판 전체가 열린다',
      );
      expect(find.text(VisitStatusNotice.permissionMissingTitle), findsOneWidget);
      expect(find.text(VisitStatusNotice.openSettingsLabel), findsOneWidget);
    });
  });

  group('추천·좋아요·홈은 위치 권한과 무관하게 그대로 동작한다', () {
    const teamsFixture = TeamsDocument(
      teams: [
        Team(id: 'lg', name: 'LG 트윈스', shortName: 'LG', themeKey: 'lg'),
        Team(id: 'doosan', name: '두산 베어스', shortName: '두산', themeKey: 'doosan'),
      ],
    );

    const stadiumsFixture = StadiumsDocument(
      stadiums: [
        Stadium(
          id: 'jamsil',
          name: '잠실야구장',
          city: '서울',
          lat: 37.512,
          lng: 127.072,
          homeTeams: ['lg', 'doosan'],
        ),
      ],
    );

    const placesFixture = PlacesDocument(places: []);

    // KST 19:00 = UTC 10:00 — 오늘 열리는 경기이자 지금이 딱 시작 시각이라
    // 시간 창 안이다. 판정이 실제로 `permissionMissing` 을 내도록 만든
    // 진짜 후보다 (그래야 이 시험이 "권한이 거부된 상태"를 흉내만 내지
    // 않고 실제로 그 상태를 판정 파이프라인으로 만들어 낸다).
    final nowFixture = DateTime.utc(2026, 4, 10, 10);
    final scheduleFixture = ScheduleDocument(
      generatedAt: DateTime.utc(2026),
      games: const [
        Game(
          id: 'g1',
          date: '2026-04-10',
          startTime: '19:00',
          homeTeamId: 'doosan',
          awayTeamId: 'lg',
          stadiumId: 'jamsil',
          status: GameStatus.scheduled,
        ),
      ],
    );

    testWidgets('위치 권한이 거부된 상태에서도 홈·추천·좋아요가 정상적으로 렌더된다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      final auth = FakeAuthService(signedIn: const AuthUser(uid: _uid));
      addTearDown(auth.dispose);
      await store.createProfile(
        _uid,
        const NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'lg',
          profileThemeKey: 'lg',
        ),
      );

      final gateway = FakeLocationPermissionGateway(
        initial: LocationPermissionStatus.denied,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            userDataStoreProvider.overrideWithValue(store),
            weatherEffectProvider.overrideWith(
              (ref, point) async => WeatherEffect.none,
            ),
            teamsProvider.overrideWith(
              (ref) async => const ContentFresh<TeamsDocument>(teamsFixture),
            ),
            stadiumsProvider.overrideWith(
              (ref) async => const ContentFresh<StadiumsDocument>(stadiumsFixture),
            ),
            placesProvider.overrideWith(
              (ref) async => const ContentFresh<PlacesDocument>(placesFixture),
            ),
            scheduleProvider.overrideWith(
              (ref) async => ContentFresh<ScheduleDocument>(scheduleFixture),
            ),
            clockProvider.overrideWithValue(() => nowFixture),
            locationPermissionGatewayProvider.overrideWithValue(gateway),
          ],
          child: const MaterialApp(home: MainTabsRoot()),
        ),
      );
      // 상한을 짧게 준다 — `badge_board_test.dart` 의 같은 함정 회피와 같은
      // 까닭이다(`IndexedStack` 이 다섯 탭을 한꺼번에 살리는 골격에서 구독이
      // 잠잠해지지 않으면 기본 10분 상한이 원인을 가린다).
      Future<void> settle() => tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );
      await settle();

      // 오늘 실제로 경기가 있는데 권한이 거부돼 있으니, `StadiumVisitTrigger`
      // (판정 트리거 그 자체)가 이미 위치 게이트웨이에 적어도 한 번은
      // 물었어야 한다.
      expect(gateway.statusCalls, greaterThanOrEqualTo(1), reason: '트리거가 적어도 한 번은 물었다');

      // 홈(기본 탭) — 실제 팀·일정 콘텐츠로 D-day 헤더가 뜬다.
      expect(find.byType(HomeScreen), findsOneWidget);

      // 배지 — permissionMissing 안내가 실제로 뜬다(전체 파이프라인 확인).
      // 이 탭 자체는 위치 게이트웨이를 정당하게 다시 묻는 쪽이므로(재요청
      // 가능 여부를 가르는 자리, `visit_status_notice.dart` 문서 참조) 그
      // 호출은 기준선에 넣는다 — 아래에서 재는 것은 "배지 밖의 세 탭이
      // 추가로 부르지 않는다"이지 "아무도 더 부르지 않는다"가 아니다.
      await tester.tap(find.text('배지'));
      await settle();
      expect(find.text(VisitStatusNotice.permissionMissingTitle), findsOneWidget);
      expect(find.text(VisitStatusNotice.requestPermissionLabel), findsOneWidget);
      final baselineAfterBadges = gateway.statusCalls;

      // 추천 — 구장 목록이 실제로 뜬다.
      await tester.tap(find.text('추천'));
      await settle();
      expect(find.byType(RecommendTabScreen), findsOneWidget);
      expect(find.byType(StadiumPicker), findsOneWidget);
      expect(find.text('잠실야구장'), findsOneWidget);

      // 좋아요 — 좋아요가 없으니 빈 상태가 실제로 뜬다.
      await tester.tap(find.text('좋아요'));
      await settle();
      expect(find.byType(LikesTabScreen), findsOneWidget);
      expect(find.text(LikesTabScreen.emptyTitle), findsOneWidget);

      // 추천·좋아요를 오간 뒤에도 위치 게이트웨이는 배지 탭까지 본 뒤의
      // 기준선에서 더 불리지 않았다 — 이 두 화면이 위치 계층을 스스로
      // 건드리지 않는다는 뜻이다.
      expect(
        gateway.statusCalls,
        baselineAfterBadges,
        reason: '추천·좋아요는 위치 게이트웨이를 스스로 부르지 않는다',
      );
      expect(gateway.requestCalls, 0);
      expect(gateway.openSettingsCalls, 0);
    });
  });
}
