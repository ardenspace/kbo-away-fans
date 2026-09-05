/// 4.3 fresh 검증 탐침 — 판의 읽기가 **오래 쓰는 동안** 늘어나지 않는가.
///
/// 기존 경계 시험은 "판을 처음 여는 한 프레임"을 잰다. 이 파일이 재는 것은
/// 그 뒤다: 탭을 오가고, 칸을 열었다 닫고, 도장이 찍힌 뒤에도 판이 사용자
/// 문서 하나에만 붙어 있는가.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/badges/badges_tab_screen.dart';
import 'package:kbo_away_fans/features/badges/board_cell_detail.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
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

StampWrite _stamp(String gameId, String date) => StampWrite(
  stadiumId: 'gwangju',
  gameId: gameId,
  homeTeamId: 'kia',
  gameDate: date,
);

Future<void> _seed(FakeUserDataStore store, {int stamps = 0}) async {
  await store.createProfile(
    _uid,
    const NewUserProfile(
      nickname: '원정러',
      favoriteTeamId: 'lg',
      profileThemeKey: 'lg',
    ),
  );
  for (var i = 0; i < stamps; i++) {
    await store.writeStamp(
      _uid,
      _stamp('g-$i', '2026-04-${(i + 1).toString().padLeft(2, '0')}'),
    );
  }
  store.documentReads = 0;
  store.stampReads = 0;
}

ProviderScope _root(
  FakeAuthService auth,
  FakeUserDataStore store,
  Widget child,
) => ProviderScope(
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
  child: child,
);

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

  testWidgets('탭을 오가도 판의 읽기가 늘지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seed(store, stamps: 5);

    await tester.pumpWidget(
      _root(auth, store, const MaterialApp(home: MainTabsRoot())),
    );
    await tester.pumpAndSettle();

    final afterBoot = store.documentReads;

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('배지'));
      await tester.pumpAndSettle();
      expect(find.byType(StampBoard), findsOneWidget);
      await tester.tap(find.text('마이페이지'));
      await tester.pumpAndSettle();
    }

    expect(store.documentReads, afterBoot, reason: '탭 전환은 서버를 다시 읽지 않는다');
    expect(store.profileWatches, 1, reason: '사용자 문서 구독은 여전히 하나');
    expect(store.stampReads, 0, reason: '판은 도장을 읽지 않는다');
  });

  testWidgets('도장이 찍히면 판은 스냅샷 하나로 갱신된다 (다시 훑지 않는다)', (tester) async {
    await _seed(store, stamps: 1);

    await tester.pumpWidget(
      ProviderScope(
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
      ),
    );
    await tester.pumpAndSettle();
    final before = store.documentReads;

    await store.writeStamp(_uid, _stamp('g-new', '2026-07-01'));
    await tester.pumpAndSettle();

    // writeStamp 자체의 읽기 둘 + 스냅샷 하나. 판이 다시 훑으면 이보다 크다.
    expect(store.documentReads - before, 3);
    expect(store.stampReads, 0);
    final board = tester.widget<StampBoard>(find.byType(StampBoard));
    expect(board.board['gwangju_kia']?.count, 2, reason: '판이 새 도장을 반영한다');
  });

  testWidgets('칸을 닫았다 다시 열면 그 칸만 다시 읽는다 (판은 그대로)', (tester) async {
    await _seed(store, stamps: 4);

    await tester.pumpWidget(
      ProviderScope(
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
      ),
    );
    await tester.pumpAndSettle();
    final afterBoard = store.documentReads;

    for (var round = 1; round <= 3; round++) {
      await tester.tap(find.text('KIA'));
      await tester.pumpAndSettle();
      expect(find.byType(BoardCellDetail), findsOneWidget);
      expect(store.stampReads, round, reason: '열 때마다 딱 한 번 질의한다');
      Navigator.of(tester.element(find.byType(BoardCellDetail))).pop();
      await tester.pumpAndSettle();
    }

    // 세 번 열었으니 그 칸의 도장 4건 × 3. 판 자체는 다시 읽지 않았다.
    expect(store.documentReads - afterBoard, 12);
    expect(store.profileWatches, 1);
  });

  testWidgets('도장이 많은 칸을 열어도 목록이 넘치지 않고 전부 들어 있다', (tester) async {
    await _seed(store, stamps: 20);

    await tester.pumpWidget(
      ProviderScope(
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('KIA'));
    await tester.pumpAndSettle();

    // 최신 도장이 맨 위에 있다.
    expect(find.text('2026-04-20'), findsOneWidget);
    // 가장 오래된 도장은 처음 프레임에 없고(목록이 화면보다 길다), 스크롤해야
    // 닿는다 — "전부 보인다"가 잘림이 아니라 스크롤로 성립하는지를 잰다.
    expect(find.text('2026-04-01'), findsNothing);
    await tester.dragUntilVisible(
      find.text('2026-04-01'),
      find.byType(ListView),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(find.text('2026-04-01'), findsOneWidget, reason: '스무 번째 도장까지 닿는다');
    // 그 사이 서버를 다시 읽지 않는다 (스크롤은 질의가 아니다).
    expect(store.stampReads, 1);
  });

  testWidgets('구독을 하나 더 붙이면 profileWatches 가 늘어난다 (자가 검증)', (tester) async {
    await _seed(store);
    final extra = store.watchProfile(_uid).listen((_) {});
    addTearDown(extra.cancel);
    expect(store.profileWatches, 1);

    await tester.pumpWidget(
      ProviderScope(
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
      ),
    );
    await tester.pumpAndSettle();

    expect(store.profileWatches, 2, reason: '계수기가 구독을 실제로 센다');
  });
}
