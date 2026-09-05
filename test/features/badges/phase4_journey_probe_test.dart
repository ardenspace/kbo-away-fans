/// Phase 4 통합 검증 탐침 — 다섯 단계를 **한 실행 안에서** 잇는다.
///
/// 단계별 시험은 각자 자기 계층에 대역을 놓고 돈다. 4.1 은 트리거만 띄운
/// 컨테이너에서 돌고(계정 없음으로 못 박아 도장 경로를 잘라 둔다), 4.4 는
/// `StampRevealOverlay` 를 자기 손으로 세운 최소 host 위에서 돌며, 4.3 은
/// 판만 그린다. 그래서 **판정 → 도장 → 연출 → 판**이 실제 앱 골격
/// (`MainTabsRoot`) 위에서 한 번에 이어지는 것을 재는 자리가 없다.
///
/// 이 파일이 그 자리다. 재는 것은 넷이다.
///
///  1) 사람이 구장에서 앱을 여는 실행 하나가 도장·연출·판을 **함께** 만든다.
///  2) 연출이 나르는 개수·등급 상승([StampAwardResult])이 그 사람의 **이전
///     칸 요약**을 실제로 따른다 — 재방문이면 "등급 상승"이 뜨지 않고,
///     임계를 넘는 도장이면 뜬다.
///  3) 연출이 떠 있는 동안 하단 탭 바가 어떻게 반응하는가 — 첫 탭은 연출을
///     닫는 데 쓰이고 탭은 두 번째에 옮겨진다(4.4 의 재량 안에서 고른 거동).
///  4) 통신이 끊긴 구장에서 찍은 도장(4.2 가 `WriteBatch` 를 고른 바로 그
///     갈래)에서도 연출이 **그 자리에서** 뜬다 — phase 4 통합 검증이 REJECT
///     로 지목했던 이음매이고, 마지막 시험이 그 자리를 반대 방향으로
///     붙잡는다. `writeStamp` 를 서버 확인까지 기다리도록 되돌리면 빨간불이다.
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
import 'package:kbo_away_fans/features/badges/stamp_reveal.dart';
import 'package:kbo_away_fans/features/home/main_tabs_root.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/ui/shared/stamp_badge.dart';
import 'package:kbo_away_fans/weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';

const String _uid = 'google-uid';
const double _jamsilLat = 37.5121;
const double _jamsilLng = 127.0719;
const ContentIssue _fixture = ContentIssue(ContentIssueKind.network, 'fixture');

/// 2026-08-25(화) 잠실 18:30 경기의 1시간 전 — 시간 창 안이다.
final DateTime _duringPregame = DateTime.parse('2026-08-25T17:30:00+09:00');

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

/// 실측 한 번에 드는 시간 — 0 으로 두면 안 된다.
///
/// 측위가 **마이크로태스크 안에서** 끝나면 `userProfileProvider` 의 첫
/// 스냅샷이 아직 도착하지 않은 채로 [StampAward.award] 가 이전 개수를 0 으로
/// 읽는다(`.wellbegun/decisions.md` 2026-09-05 `[M]` 이 Deferred 로 적어 둔
/// 콜드 스타트 창이다 — 실측: `fixDelay` 를 0 으로 두면 재방문에도
/// "등급 상승"이 뜬다). 실제 측위는 초 단위라 그 창은 이 1ms 로 이미 닫힌다.
const Duration kRealisticFixDelay = Duration(milliseconds: 1);

/// 잠실 한복판에 선 기기 — 반경 안이다.
StadiumVisitChecker _atJamsil({Duration fixDelay = kRealisticFixDelay}) =>
    StadiumVisitChecker(
      readPermission: () async => LocationPermissionStatus.granted,
      readFix: () async {
        await Future<void>.delayed(fixDelay);
        return const DeviceFix(lat: _jamsilLat, lng: _jamsilLng);
      },
    );

/// 이미 [count] 개의 도장이 쌓인 칸 요약을 사용자 문서에 심는다.
///
/// 도장 문서 자체는 심지 않는다 — 이 실행이 재는 것은 **연출이 무엇을 보고
/// 개수·등급을 세는가**이고, 그 자리는 판이 보는 칸 요약이다.
void _seedCell(FakeUserDataStore store, {required int count}) {
  final document = store.documents[_uid]!;
  store.documents[_uid] = {
    ...document,
    UserFields.board: <String, Object?>{
      'jamsil_lg': BoardCell.forCount(
        count: count,
        lastStampedOn: '2026-08-01',
      ).toData(),
    },
  };
}

Future<FakeUserDataStore> _pumpApp(
  WidgetTester tester, {
  int? seededCount,
  bool offline = false,
  Duration fixDelay = kRealisticFixDelay,
}) async {
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
  if (seededCount != null) _seedCell(store, count: seededCount);
  store.offline = offline;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
        weatherEffectProvider.overrideWith((ref, point) async =>
            WeatherEffect.none),
        clockProvider.overrideWithValue(() => _duringPregame),
        stadiumsProvider.overrideWith((ref) async => ContentFresh(_stadiums)),
        scheduleProvider.overrideWith((ref) async => ContentFresh(_schedule)),
        placesProvider.overrideWith(
          (ref) async => const ContentUnavailable<PlacesDocument>(_fixture),
        ),
        teamsProvider.overrideWith(
          (ref) async => const ContentUnavailable<TeamsDocument>(_fixture),
        ),
        stadiumVisitCheckerProvider.overrideWithValue(_atJamsil(fixDelay: fixDelay)),
      ],
      child: const MaterialApp(home: MainTabsRoot()),
    ),
  );
  await tester.pumpAndSettle(const Duration(seconds: 5));
  return store;
}

/// 배지 탭으로 옮겨 판을 화면에 세운다.
Future<void> _openBadgesTab(WidgetTester tester) async {
  await tester.tap(find.text('배지'));
  await tester.pumpAndSettle(const Duration(seconds: 5));
}

void main() {
  testWidgets(
    '구장에서 앱을 여는 한 실행이 도장·연출·판을 함께 만든다',
    (tester) async {
      final store = await _pumpApp(tester);

      // 4.2 — 도장 문서가 서버에 하나 남았다.
      expect(store.stamps[_uid]?.keys.toList(), ['jamsil_g-jamsil']);

      // 4.4 — 그 순간의 연출이 앱 골격 위에 실제로 떴다.
      //
      // 이 단언이 없으면 `MainTabsRoot` 의 `StampRevealOverlay(child: …)` 를
      // `_tabs()` 로 되돌려도 저장소 전체가 초록불이다(실측) — 4.1 이 자기
      // 트리거에 대해 같은 못("앱 골격이 그 트리거를 실제로 달고 있다")을
      // 박아 두었는데 4.4 는 그 짝을 두지 않았다.
      expect(
        find.byType(StampReveal),
        findsOneWidget,
        reason: '도장이 찍히는 순간의 연출이 앱 골격 위에 떠야 한다',
      );

      // 4.3 — 판이 그 도장을 반영한다(연출을 닫은 뒤 배지 탭으로).
      await tester.tap(find.byType(StampReveal));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(StampReveal), findsNothing);

      await _openBadgesTab(tester);
      final profile = await store.readProfile(_uid);
      expect(profile!.board['jamsil_lg']!.count, 1);
      expect(profile.board['jamsil_lg']!.tier, BadgeTier.first);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    '이미 도장이 있는 칸의 재방문에는 "등급 상승"이 뜨지 않는다',
    (tester) async {
      // 칸에 도장 1개가 이미 있다 → 이번 도장으로 2개가 되고 등급은 `first`
      // 그대로다. 연출이 그 사실을 따르는지 재는 자리다.
      await _pumpApp(tester, seededCount: 1);

      expect(find.byType(StampReveal), findsOneWidget);
      // 찍힘 연출이 끝날 때까지 — 등급 상승은 그 뒤에 이어 붙는다.
      await tester.pump(MotionTokens.stamp.duration + MotionTokens.base);

      expect(
        find.byKey(StampReveal.tierUpKey),
        findsNothing,
        reason: '개수만 늘어난 재방문에 "등급 상승"이 뜨면 안 된다',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    '임계를 넘기는 도장에는 "등급 상승"이 이어 붙는다',
    (tester) async {
      // 2개 → 3개는 사다리의 `regular` 임계다.
      await _pumpApp(tester, seededCount: 2);

      expect(find.byType(StampReveal), findsOneWidget);
      await tester.pump(MotionTokens.stamp.duration + MotionTokens.base);

      expect(
        find.byKey(StampReveal.tierUpKey),
        findsOneWidget,
        reason: '3개째 도장은 regular 로 오른다',
      );
      // 연출이 나르는 개수도 그 사람의 칸 요약을 따른다 — 등급 상승 여부만
      // 보면 이전 개수를 0 으로 읽는 변이가 이 갈래에서 그대로 통과한다.
      expect(
        tester.widget<StampBadge>(find.byType(StampBadge)).stamps,
        3,
        reason: '연출의 배지는 이번 도장을 포함한 새 개수를 든다',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    '연출이 떠 있는 동안 첫 탭은 연출을 닫는 데 쓰인다',
    (tester) async {
      // `StampReveal` 이 `SizedBox.expand` + `HitTestBehavior.opaque` 로 하단
      // 탭 바까지 덮으므로 탭이 옮겨지려면 두 번 눌러야 한다. 4.4 의 재량
      // 안에서 고른 거동이고(탭 한 번이면 언제든 닫힌다), 문서 셋이 한동안
      // 이것을 "연출 중에도 탭을 옮길 수 있다"로 적고 있었다 — 그 문장을
      // 사실에 맞추면서 이 자리를 값으로 못 박는다.
      await _pumpApp(tester);
      expect(find.byType(StampReveal), findsOneWidget);

      int currentIndex() => tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex;

      expect(currentIndex(), 0, reason: '연출은 홈 위에 떴다');

      await tester.tap(find.text('배지'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(StampReveal), findsNothing, reason: '첫 탭이 연출을 닫는다');
      expect(currentIndex(), 0, reason: '첫 탭은 탭 바에 닿지 않는다');

      await tester.tap(find.text('배지'));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(currentIndex(), 1, reason: '두 번째 탭에서 비로소 옮겨진다');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    '통신이 끊긴 구장에서 찍은 도장은 판에도 서고 연출도 그 자리에서 뜬다',
    (tester) async {
      // 4.2 가 트랜잭션 대신 `WriteBatch` 를 고른 까닭이 바로 이 실행이다
      // ("구장은 사람이 몰려 통신이 잘 끊기는 자리이고, 도장이 찍히는 순간을
      // 놓치면 시간 창이 닫힌 뒤에는 되찾을 길이 없다").
      //
      // **두 단계가 "찍혔다"를 같게 정의한다.** 4.2 에게 그 순간은 배치가
      // 로컬 큐에 들어간 때이고(`stampUploads` 의 doc 이 그렇게 적는다:
      // "재는 것은 '서버로 나갔다'가 아니라 '로컬에 반영됐다'"), `writeStamp`
      // 가 그 순간에 [StampWriteReceipt] 로 돌아오므로 4.4 의 연출도 같은
      // 순간에 선다. 서버 확인은 `receipt.serverConfirmed` 로 따로 흐른다.
      //
      // 이 시험이 phase 4 통합 검증의 REJECT 사유를 반대 방향으로 붙잡는다 —
      // `writeStamp` 를 서버 확인까지 기다리도록 되돌리면 여기가 빨간불이다.
      final store = await _pumpApp(tester, offline: true);

      // 도장은 이미 로컬에 확정됐고 판도 그 값을 본다.
      expect(store.stampUploads, ['jamsil_g-jamsil']);
      expect((await store.readProfile(_uid))!.board['jamsil_lg']!.count, 1);

      expect(
        find.byType(StampReveal),
        findsOneWidget,
        reason: '연출은 서버 확인이 아니라 로컬 확정을 따른다',
      );

      // 통신이 돌아와도 같은 도장의 연출이 한 번 더 쌓이지 않는다.
      store.goOnline();
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(StampReveal), findsOneWidget);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
