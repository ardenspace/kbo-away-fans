/// Step 4.3 boundary tests — 배지 판과 칸 상세.
///
/// 재는 갈래:
///  1) **판을 여는 동안 읽는 문서가 사용자 문서 하나다 — 도장 개수와
///     무관하다.** 이 단계의 존재 이유이자 decisions.md 의 판 읽기 패턴 `[L]`
///     결정이 지키려는 성질이다(무료 할당량: 판을 열 때마다 도장을 전부 읽으면
///     읽기가 사용자 수 × 도장 수로 늘어 약 800명에서 한도에 닿는다).
///     세는 것은 메서드 호출이 아니라 [FakeUserDataStore.documentReads] —
///     **문서 읽기** 다. 무료 할당량이 세는 단위가 그것이기 때문이다.
///  2) 빈 칸까지 10칸이 전부 보인다 (잠실은 두 칸).
///  3) 판에는 칸별 최고 등급이 보인다.
///  4) 칸을 열면 그 칸의 도장이 날짜와 함께 전부 보이고, **그때** 도장을 읽는다.
///  5) 빈 칸을 열면 서버를 아예 읽지 않는다 (칸 요약이 이미 "없다"고 말한다).
///  6) 칸 상세의 읽기가 실패하면 "못 읽었다" 얼굴과 재시도가 뜬다.
///  7) 앱 골격(`MainTabsRoot`)의 배지 탭이 실제로 이 판이고, 탭 다섯이 함께
///     살아 있어도 사용자 문서에 붙은 구독은 하나다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/badges/badges_tab_screen.dart';
import 'package:kbo_away_fans/features/badges/board_cell_detail.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/ui/shared/content_fallback.dart';
import 'package:kbo_away_fans/ui/shared/empty_state_notice.dart';
import 'package:kbo_away_fans/ui/shared/stamp_badge.dart';
import 'package:kbo_away_fans/ui/shared/stamp_board.dart';
import 'package:kbo_away_fans/weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';

const _uid = 'kakao:1234567890';

const ContentIssue _fixture = ContentIssue(ContentIssueKind.network, 'fixture');

const _teams = TeamsDocument(
  teams: [
    Team(id: 'lg', name: 'LG 트윈스', shortName: 'LG', themeKey: 'lg'),
    Team(id: 'doosan', name: '두산 베어스', shortName: '두산', themeKey: 'doosan'),
    Team(id: 'kia', name: 'KIA 타이거즈', shortName: 'KIA', themeKey: 'kia'),
    Team(id: 'lotte', name: '롯데 자이언츠', shortName: '롯데', themeKey: 'lotte'),
  ],
);

const _stadiums = StadiumsDocument(
  stadiums: [
    Stadium(
      id: 'jamsil',
      name: '잠실야구장',
      city: '서울',
      lat: 37.512,
      lng: 127.072,
      homeTeams: ['lg', 'doosan'],
    ),
    Stadium(
      id: 'gwangju',
      name: '광주기아챔피언스필드',
      city: '광주',
      lat: 35.168,
      lng: 126.889,
      homeTeams: ['kia'],
    ),
  ],
);

/// 사용자 문서를 하나 만들고 [stamps] 를 찍어 둔다 — 판을 열기 **전에**
/// 일어난 일이므로, 씨앗을 심은 뒤 읽기 계수를 0 으로 되돌린다.
Future<void> _seed(
  FakeUserDataStore store, {
  List<StampWrite> stamps = const [],
}) async {
  await store.createProfile(
    _uid,
    const NewUserProfile(
      nickname: '원정러',
      favoriteTeamId: 'lg',
      profileThemeKey: 'lg',
    ),
  );
  for (final stamp in stamps) {
    await store.writeStamp(_uid, stamp);
  }
  store.documentReads = 0;
  store.stampReads = 0;
}

StampWrite _stamp({
  required String stadiumId,
  required String homeTeamId,
  required String gameId,
  required String gameDate,
}) => StampWrite(
  stadiumId: stadiumId,
  gameId: gameId,
  homeTeamId: homeTeamId,
  gameDate: gameDate,
);

/// 잠실 LG 칸에 [count] 개, 그 밖의 칸에도 몇 개 흩어 둔 도장 목록.
List<StampWrite> _manyStamps() => [
  for (var i = 0; i < 12; i++)
    _stamp(
      stadiumId: 'jamsil',
      homeTeamId: 'lg',
      gameId: 'g-lg-$i',
      gameDate: '2026-04-${(i + 1).toString().padLeft(2, '0')}',
    ),
  _stamp(
    stadiumId: 'jamsil',
    homeTeamId: 'doosan',
    gameId: 'g-doosan-1',
    gameDate: '2026-05-01',
  ),
  for (var i = 0; i < 3; i++)
    _stamp(
      stadiumId: 'gwangju',
      homeTeamId: 'kia',
      gameId: 'g-kia-$i',
      gameDate: '2026-06-0${i + 1}',
    ),
];

Widget _host(FakeAuthService auth, FakeUserDataStore store) => ProviderScope(
  overrides: [
    authServiceProvider.overrideWithValue(auth),
    userDataStoreProvider.overrideWithValue(store),
    teamsProvider.overrideWith(
      (ref) async => const ContentFresh<TeamsDocument>(_teams),
    ),
    stadiumsProvider.overrideWith(
      (ref) async => const ContentFresh<StadiumsDocument>(_stadiums),
    ),
  ],
  child: const MaterialApp(home: BadgesTabScreen()),
);

List<StampBadge> _badges(WidgetTester tester) => tester
    .widgetList<StampBadge>(find.byType(StampBadge, skipOffstage: false))
    .toList();

void main() {
  late FakeUserDataStore store;
  late FakeAuthService auth;

  setUp(() {
    store = FakeUserDataStore();
    auth = FakeAuthService(signedIn: const AuthUser(uid: _uid));
  });

  tearDown(() async {
    await auth.dispose();
    await store.dispose();
  });

  group('판을 여는 동안 읽는 문서가 사용자 문서 하나다', () {
    testWidgets('도장이 하나도 없어도 문서 하나', (tester) async {
      await _seed(store);

      await tester.pumpWidget(_host(auth, store));
      await tester.pumpAndSettle();

      expect(find.byType(StampBoard), findsOneWidget);
      expect(store.documentReads, 1, reason: '사용자 문서 하나');
      expect(store.stampReads, 0, reason: '판은 도장 문서를 열지 않는다');
    });

    testWidgets('도장이 16개여도 문서 하나 — 개수와 무관하다', (tester) async {
      await _seed(store, stamps: _manyStamps());

      await tester.pumpWidget(_host(auth, store));
      await tester.pumpAndSettle();

      expect(find.byType(StampBoard), findsOneWidget);
      expect(
        store.documentReads,
        1,
        reason: '도장이 16개라도 판이 읽는 문서는 사용자 문서 하나뿐이다',
      );
      expect(store.stampReads, 0);
    });
  });

  group('판의 모습', () {
    testWidgets('빈 칸까지 10칸이 전부 보인다 (잠실은 두 칸)', (tester) async {
      await _seed(store, stamps: _manyStamps());

      await tester.pumpWidget(_host(auth, store));
      await tester.pumpAndSettle();

      expect(_badges(tester), hasLength(BadgeTokens.cellCount));
      expect(_badges(tester), hasLength(kBoardCellIds.length));
      // 잠실 두 칸은 팀 약칭으로 갈린다.
      expect(find.text('LG'), findsOneWidget);
      expect(find.text('두산'), findsOneWidget);
      // 아직 못 간 칸도 그려진다.
      expect(
        _badges(tester).where((badge) => badge.stamps == 0),
        hasLength(kBoardCellIds.length - 3),
      );
    });

    testWidgets('판에는 칸별 최고 등급이 보인다', (tester) async {
      await _seed(store, stamps: _manyStamps());

      await tester.pumpWidget(_host(auth, store));
      await tester.pumpAndSettle();

      final byStamps = {
        for (final badge in _badges(tester)) badge.stamps: badge.tier,
      };
      expect(byStamps[12], BadgeTier.master, reason: '12개는 마스터');
      expect(byStamps[3], BadgeTier.regular, reason: '3개는 단골');
      expect(byStamps[1], BadgeTier.first, reason: '1개는 첫 방문');
      expect(byStamps[0], isNull, reason: '빈 칸은 등급이 없다');
    });

    testWidgets('사용자 문서를 못 읽으면 재시도가 있는 실패 얼굴이다', (tester) async {
      await _seed(store);

      await tester.pumpWidget(_host(auth, store));
      await tester.pumpAndSettle();
      store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
      await tester.pumpAndSettle();

      expect(find.byType(StampBoard), findsNothing);
      final fallback = tester.widget<ContentFallback>(
        find.byType(ContentFallback),
      );
      expect(fallback.onRetry, isNotNull);
    });
  });

  group('칸 상세', () {
    testWidgets('칸을 열면 그 칸의 도장이 날짜와 함께 전부 보인다', (tester) async {
      await _seed(store, stamps: _manyStamps());

      await tester.pumpWidget(_host(auth, store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIA'));
      await tester.pumpAndSettle();

      expect(find.byType(BoardCellDetail), findsOneWidget);
      expect(find.text('광주기아챔피언스필드'), findsOneWidget);
      // 그 칸의 도장 세 개가 날짜와 함께 전부 보인다.
      expect(find.text('2026-06-01'), findsOneWidget);
      expect(find.text('2026-06-02'), findsOneWidget);
      expect(find.text('2026-06-03'), findsOneWidget);
      // 다른 칸의 도장은 섞이지 않는다.
      expect(find.text('2026-05-01'), findsNothing);
    });

    testWidgets('도장은 칸을 열 때 딱 한 번 질의한다', (tester) async {
      await _seed(store, stamps: _manyStamps());

      await tester.pumpWidget(_host(auth, store));
      await tester.pumpAndSettle();
      expect(store.stampReads, 0, reason: '판을 여는 동안에는 읽지 않는다');
      final beforeOpen = store.documentReads;

      await tester.tap(find.text('KIA'));
      await tester.pumpAndSettle();

      expect(store.stampReads, 1);
      expect(
        store.documentReads - beforeOpen,
        3,
        reason: '그 칸의 도장 세 건만 읽는다',
      );
    });

    testWidgets('빈 칸을 열면 서버를 아예 읽지 않는다', (tester) async {
      await _seed(store, stamps: _manyStamps());

      await tester.pumpWidget(_host(auth, store));
      await tester.pumpAndSettle();
      final beforeOpen = store.documentReads;

      await tester.tap(find.text('롯데'));
      await tester.pumpAndSettle();

      expect(find.byType(BoardCellDetail), findsOneWidget);
      expect(find.byType(EmptyStateNotice), findsOneWidget);
      expect(store.stampReads, 0, reason: '칸 요약이 이미 "도장 없음"을 말한다');
      expect(store.documentReads, beforeOpen);
    });

    testWidgets('칸 상세를 못 읽으면 재시도가 있는 실패 얼굴이다', (tester) async {
      final failing = _FailingStampsStore();
      addTearDown(failing.dispose);
      await _seed(failing, stamps: _manyStamps());

      await tester.pumpWidget(_host(auth, failing));
      await tester.pumpAndSettle();

      await tester.tap(find.text('KIA'));
      await tester.pumpAndSettle();

      final fallback = tester.widget<ContentFallback>(
        find.byType(ContentFallback),
      );
      expect(fallback.onRetry, isNotNull);
    });
  });

  testWidgets('앱 골격의 배지 탭이 실제로 이 판이다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seed(store);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          userDataStoreProvider.overrideWithValue(store),
          weatherEffectProvider.overrideWith(
            (ref, point) async => WeatherEffect.none,
          ),
          teamsProvider.overrideWith(
            (ref) async => const ContentFresh<TeamsDocument>(_teams),
          ),
          stadiumsProvider.overrideWith(
            (ref) async => const ContentFresh<StadiumsDocument>(_stadiums),
          ),
          placesProvider.overrideWith(
            (ref) async => const ContentUnavailable<PlacesDocument>(_fixture),
          ),
          scheduleProvider.overrideWith(
            (ref) async => const ContentUnavailable<ScheduleDocument>(_fixture),
          ),
          stadiumVisitCheckerProvider.overrideWithValue(
            StadiumVisitChecker(
              readPermission: () async => LocationPermissionStatus.denied,
              readFix: () async => null,
            ),
          ),
        ],
        child: const MaterialApp(home: MainTabsRoot()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('배지'));
    await tester.pumpAndSettle();

    expect(find.byType(BadgesTabScreen), findsOneWidget);
    expect(find.byType(StampBoard), findsOneWidget);
    // 탭 다섯이 함께 사는 골격에서도 사용자 문서에 붙은 구독은 하나다 —
    // 판이 공용 [userProfileProvider] 를 거치지 않고 저장소를 직접 구독하면
    // 마이페이지 탭의 구독과 겹쳐 읽기가 두 배가 된다. 화면 하나만 띄운 위
    // 시험들로는 그 변이가 드러나지 않는다(구독이 어차피 하나뿐이라 읽기
    // 수가 같다 — 실측으로 확인했다).
    expect(store.profileWatches, 1);
  });
}

/// 도장 조회가 언제나 실패하는 대역 — "칸 상세를 못 읽었다"의 대역.
class _FailingStampsStore extends FakeUserDataStore {
  @override
  Future<List<StampRecord>> readStamps(String uid, {String? cellId}) async {
    stampReads++;
    throw const BackendNetworkError(code: 'unavailable');
  }
}
