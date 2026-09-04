/// Step 4.2 boundary tests — 도장 쓰기와 칸별 요약 갱신.
///
/// 계약이 이름 지은 네 갈래를 그대로 잰다:
///   1. 중복 쓰기 멱등 — 같은 경기를 여러 번 판정해도 도장 문서가 하나다.
///   2. 요약과 도장의 일치 — 칸의 개수·등급이 실제 도장과 어긋나지 않는다.
///   3. 잠실 홈팀 분기 — 그날 홈팀에 따라 `jamsil_lg`·`jamsil_doosan` 이 갈린다.
///   4. 오프라인 큐 재전송 — 오프라인에서 찍은 도장이 복구 후 한 번만 올라간다.
///
/// 계약의 나머지 문장 둘도 여기서 잰다:
///   - "도장에 좌표가 담기지 않는다" — 서버로 나가는 payload 의 **키 집합
///     자체**를 계약 상수와 대조한다(1.6 의 `probe_user_payload_contract_test`
///     와 같은 방식이고, 이름을 바꿔 숨긴 좌표까지 잡으려는 자리가 아니라
///     계약 밖 키가 하나라도 섞이는 것을 잡는 자리다 — 규칙의 `hasOnly` 가
///     서버에서 하는 일과 같다).
///   - "이미 받은 경기에서 판정(과 측위)이 다시 돌지 않는다"
///     (`.wellbegun/decisions.md` 2026-09-04 `[S]`) — 이 단계가 "이 경기의
///     도장은 이미 있다"를 아는 유일한 계층이라, 그 앎이 실제로 측위를
///     막는지를 `fixReads` 로 잰다. 결과의 이유만 보면 좌표를 읽고 나서
///     버린 실행과 구분되지 않는다.
///
/// **짝 파일:** 규칙 쪽에서 같은 쓰기 모양을 재는 자리는
/// `firebase/test/rules-writes.test.mjs` 의 "도장 + 칸 요약을 한 배치로"이고,
/// 판정 자체는 `test/features/badges/visit_check_test.dart` 가 잰다.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/badges/stadium_visit.dart';
import 'package:kbo_away_fans/features/badges/stamp_award.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';

import 'fake_backend.dart';

const String _uid = 'google-uid';

/// 잠실야구장 좌표(stadiums.json 과 같은 값의 근사).
const double _jamsilLat = 37.5121;
const double _jamsilLng = 127.0719;

/// 사직야구장 좌표 — 잠실 밖의 칸을 짓는 자리.
const double _sajikLat = 35.1940;
const double _sajikLng = 129.0615;

const NewUserProfile _newProfile = NewUserProfile(
  nickname: '원정러',
  favoriteTeamId: 'lotte',
  profileThemeKey: 'lotte',
);

StampWrite _stampAt({
  required String stadiumId,
  required String gameId,
  required String homeTeamId,
  required String gameDate,
}) => StampWrite(
  stadiumId: stadiumId,
  gameId: gameId,
  homeTeamId: homeTeamId,
  gameDate: gameDate,
);

const StampWrite _jamsilLgStamp = StampWrite(
  stadiumId: 'jamsil',
  gameId: 'g-jamsil-lg',
  homeTeamId: 'lg',
  gameDate: '2026-08-25',
);

Game _game({
  required String id,
  required String date,
  String startTime = '18:30',
  required String home,
  required String away,
  required String stadium,
}) => Game(
  id: id,
  date: date,
  startTime: startTime,
  homeTeamId: home,
  awayTeamId: away,
  stadiumId: stadium,
  status: GameStatus.scheduled,
);

Stadium _stadium(String id, double lat, double lng, List<String> homeTeams) =>
    Stadium(id: id, name: id, city: id, lat: lat, lng: lng, homeTeams: homeTeams);

/// 판정기 대역 — 측위 횟수를 세고, 결과를 시험이 정한다.
class _RecordingChecker {
  _RecordingChecker({this.fix});

  final DeviceFix? fix;

  int fixReads = 0;

  StadiumVisitChecker build() => StadiumVisitChecker(
    readPermission: () async => LocationPermissionStatus.granted,
    readFix: () async {
      fixReads++;
      return fix;
    },
  );
}

/// 칸 요약 하나를 사용자 문서에서 꺼내 온다 (없으면 null).
Future<BoardCell?> _cellOf(
  FakeUserDataStore store,
  String uid,
  String cellId,
) async => (await store.readProfile(uid))!.board[cellId];

void main() {
  // 기준 시각: 2026-08-25(화) 잠실 18:30 경기의 1시간 전.
  final duringPregame = DateTime.parse('2026-08-25T17:30:00+09:00');

  group('도장 하나가 문서와 칸 요약을 함께 남긴다', () {
    late FakeUserDataStore store;

    setUp(() async {
      store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);
    });

    test('새 도장은 문서 하나와 그 칸의 첫 요약을 남긴다', () async {
      final outcome = await store.writeStamp(_uid, _jamsilLgStamp);

      expect(outcome, StampWriteOutcome.created);
      final stamps = await store.readStamps(_uid);
      expect(stamps.single.documentId, 'jamsil_g-jamsil-lg');
      expect(stamps.single.cellId, 'jamsil_lg');

      final cell = await _cellOf(store, _uid, 'jamsil_lg');
      expect(cell!.count, 1);
      expect(cell.tier, BadgeTier.first);
      expect(cell.lastStampedOn, '2026-08-25');
    });

    test('같은 경기를 여러 번 써도 문서가 하나고 개수도 하나다', () async {
      expect(
        await store.writeStamp(_uid, _jamsilLgStamp),
        StampWriteOutcome.created,
      );
      expect(
        await store.writeStamp(_uid, _jamsilLgStamp),
        StampWriteOutcome.alreadyStamped,
      );
      expect(
        await store.writeStamp(_uid, _jamsilLgStamp),
        StampWriteOutcome.alreadyStamped,
      );

      expect(await store.readStamps(_uid), hasLength(1));
      expect((await _cellOf(store, _uid, 'jamsil_lg'))!.count, 1);
      expect(
        store.stampUploads,
        ['jamsil_g-jamsil-lg'],
        reason: '서버로 나간 쓰기도 하나여야 한다',
      );
    });

    test('같은 칸의 도장이 늘면 개수와 등급이 사다리를 따라 오른다', () async {
      for (var day = 1; day <= 10; day++) {
        final date = '2026-09-${day.toString().padLeft(2, '0')}';
        await store.writeStamp(
          _uid,
          _stampAt(
            stadiumId: 'jamsil',
            gameId: 'g-jamsil-$day',
            homeTeamId: 'lg',
            gameDate: date,
          ),
        );

        final cell = (await _cellOf(store, _uid, 'jamsil_lg'))!;
        expect(cell.count, day);
        expect(cell.tier, BadgeTierTokens.tierFor(day));
        expect(cell.lastStampedOn, date);
      }

      expect(await store.readStamps(_uid, cellId: 'jamsil_lg'), hasLength(10));
      expect((await _cellOf(store, _uid, 'jamsil_lg'))!.tier, BadgeTier.master);
    });

    test('요약의 개수는 그 칸의 실제 도장 수와 언제나 같다', () async {
      await store.writeStamp(_uid, _jamsilLgStamp);
      await store.writeStamp(
        _uid,
        _stampAt(
          stadiumId: 'jamsil',
          gameId: 'g-jamsil-doosan',
          homeTeamId: 'doosan',
          gameDate: '2026-08-26',
        ),
      );
      await store.writeStamp(
        _uid,
        _stampAt(
          stadiumId: 'sajik',
          gameId: 'g-sajik',
          homeTeamId: 'lotte',
          gameDate: '2026-08-27',
        ),
      );

      final profile = (await store.readProfile(_uid))!;
      for (final entry in profile.board.entries) {
        final actual = await store.readStamps(_uid, cellId: entry.key);
        expect(
          entry.value.count,
          actual.length,
          reason: '${entry.key} 의 요약이 실제 도장과 어긋난다',
        );
        expect(entry.value.tier, BadgeTierTokens.tierFor(actual.length));
      }
      expect(profile.board.keys, unorderedEquals(<String>[
        'jamsil_lg',
        'jamsil_doosan',
        'sajik_lotte',
      ]));
    });

    test('도장이 없는 칸은 요약에 키 자체가 없다', () async {
      await store.writeStamp(_uid, _jamsilLgStamp);

      final profile = (await store.readProfile(_uid))!;
      expect(profile.board.containsKey('jamsil_doosan'), isFalse);
      expect(profile.board, hasLength(1));
    });

    test('잠실은 그날 홈팀 칸에 찍힌다 — 두 칸이 따로 센다', () async {
      await store.writeStamp(_uid, _jamsilLgStamp);
      await store.writeStamp(
        _uid,
        _stampAt(
          stadiumId: 'jamsil',
          gameId: 'g-jamsil-ob1',
          homeTeamId: 'doosan',
          gameDate: '2026-08-26',
        ),
      );
      await store.writeStamp(
        _uid,
        _stampAt(
          stadiumId: 'jamsil',
          gameId: 'g-jamsil-ob2',
          homeTeamId: 'doosan',
          gameDate: '2026-08-27',
        ),
      );

      expect((await _cellOf(store, _uid, 'jamsil_lg'))!.count, 1);
      expect((await _cellOf(store, _uid, 'jamsil_doosan'))!.count, 2);
    });

    test('칸 요약 갱신 payload 는 점 경로 하나와 updatedAt 뿐이다', () {
      // 이 키 모양을 규칙 쪽에서 그대로 베껴 재는 자리가
      // `firebase/test/probe-4-2-stamp-batch.test.mjs` 다 — 여기서 모양이
      // 바뀌면 그 사본도 함께 고쳐야 한다.
      final data = _jamsilLgStamp.boardPatchData(
        BoardCell.forCount(count: 1, lastStampedOn: '2026-08-25'),
      );

      expect(data.keys.toSet(), {'board.jamsil_lg', UserFields.updatedAt});
      expect(data['board.jamsil_lg'], {
        BoardCellFields.count: 1,
        BoardCellFields.tier: 'first',
        BoardCellFields.lastStampedOn: '2026-08-25',
      });
      expect(data[UserFields.updatedAt], isA<ServerTimestamp>());
    });

    test('서버로 나가는 도장 payload 에 계약 밖 키가 없다', () async {
      await store.writeStamp(_uid, _jamsilLgStamp);

      final data = store.stamps[_uid]!['jamsil_g-jamsil-lg']!;
      expect(data.keys.toSet(), StampFields.all);
    });

    test('사용자 문서가 없으면 도장을 쓸 수 없다 (도메인 오류로 실패한다)', () async {
      final empty = FakeUserDataStore();
      addTearDown(empty.dispose);

      await expectLater(
        empty.writeStamp(_uid, _jamsilLgStamp),
        throwsA(isA<BackendError>()),
      );
      expect(empty.stampUploads, isEmpty);
    });
  });

  group('오프라인 큐 — 복구 후 한 번만 올라간다', () {
    late FakeUserDataStore store;

    setUp(() async {
      store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);
    });

    test('오프라인 쓰기는 로컬에 곧바로 보이고 서버 확인은 복구 뒤에 온다', () async {
      store.offline = true;

      var acked = false;
      unawaited(store.writeStamp(_uid, _jamsilLgStamp).then((_) {
        acked = true;
      }));
      await pumpEventQueue();

      expect(acked, isFalse, reason: '서버에 닿기 전에는 확정되지 않는다');
      expect(
        await store.readStamps(_uid),
        hasLength(1),
        reason: '로컬 반영은 즉시다 (판정한 사람에게 도장이 보인다)',
      );
      expect((await _cellOf(store, _uid, 'jamsil_lg'))!.count, 1);

      store.goOnline();
      await pumpEventQueue();

      expect(acked, isTrue);
      expect(await store.readStamps(_uid), hasLength(1));
      expect((await _cellOf(store, _uid, 'jamsil_lg'))!.count, 1);
      expect(store.stampUploads, ['jamsil_g-jamsil-lg']);
    });

    test('오프라인에서 같은 경기를 다시 써도 올라가는 쓰기는 하나다', () async {
      store.offline = true;
      unawaited(store.writeStamp(_uid, _jamsilLgStamp));
      await pumpEventQueue();

      // 두 번째 쓰기는 로컬에 이미 있는 문서를 보고 곧바로 끝난다 —
      // 서버 확인을 기다릴 것이 없다.
      expect(
        await store.writeStamp(_uid, _jamsilLgStamp),
        StampWriteOutcome.alreadyStamped,
      );

      store.goOnline();
      await pumpEventQueue();

      expect(await store.readStamps(_uid), hasLength(1));
      expect((await _cellOf(store, _uid, 'jamsil_lg'))!.count, 1);
      expect(store.stampUploads, ['jamsil_g-jamsil-lg']);
    });
  });

  group('판정 → 도장 — 앱이 두 계층을 잇는 자리', () {
    final stadiums = StadiumsDocument(
      stadiums: [
        _stadium('jamsil', _jamsilLat, _jamsilLng, const ['lg', 'doosan']),
        _stadium('sajik', _sajikLat, _sajikLng, const ['lotte']),
      ],
    );

    ScheduleDocument scheduleOf(List<Game> games) =>
        ScheduleDocument(generatedAt: DateTime.utc(2026), games: games);

    final lgHomeSchedule = scheduleOf([
      _game(
        id: 'g-jamsil',
        date: '2026-08-25',
        home: 'lg',
        away: 'lotte',
        stadium: 'jamsil',
      ),
    ]);

    final doosanHomeSchedule = scheduleOf([
      _game(
        id: 'g-jamsil',
        date: '2026-08-25',
        home: 'doosan',
        away: 'lotte',
        stadium: 'jamsil',
      ),
    ]);

    Future<ProviderContainer> buildContainer({
      required FakeUserDataStore store,
      required _RecordingChecker recorder,
      required ScheduleDocument schedule,
      AuthUser? user = const AuthUser(uid: _uid),
    }) async {
      final auth = FakeAuthService(signedIn: user);
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => duringPregame),
          authServiceProvider.overrideWithValue(auth),
          userDataStoreProvider.overrideWithValue(store),
          stadiumsProvider.overrideWith((ref) async => ContentFresh(stadiums)),
          scheduleProvider.overrideWith((ref) async => ContentFresh(schedule)),
          stadiumVisitCheckerProvider.overrideWithValue(recorder.build()),
        ],
      );
      addTearDown(container.dispose);
      // 세션이 흐르기를 기다린다 — 도장을 쓸 계정이 없으면 아무것도 쓰지 않는다.
      container.listen(authStateProvider, (_, _) {});
      await pumpEventQueue();
      return container;
    }

    test('방문 판정이 그날 홈팀 칸에 도장을 남긴다 (잠실 LG)', () async {
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);
      final recorder = _RecordingChecker(
        fix: const DeviceFix(lat: _jamsilLat, lng: _jamsilLng),
      );
      final container = await buildContainer(
        store: store,
        recorder: recorder,
        schedule: lgHomeSchedule,
      );

      await container.read(stadiumVisitProvider.notifier).run();

      expect(container.read(stadiumVisitProvider)!.isVisit, isTrue);
      final stamps = await store.readStamps(_uid);
      expect(stamps.single.documentId, 'jamsil_g-jamsil');
      expect(stamps.single.homeTeamId, 'lg');
      expect(stamps.single.gameDate, '2026-08-25');
      expect((await _cellOf(store, _uid, 'jamsil_lg'))!.count, 1);
    });

    test('같은 경기의 홈팀이 두산이면 두산 칸에 찍힌다', () async {
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);
      final recorder = _RecordingChecker(
        fix: const DeviceFix(lat: _jamsilLat, lng: _jamsilLng),
      );
      final container = await buildContainer(
        store: store,
        recorder: recorder,
        schedule: doosanHomeSchedule,
      );

      await container.read(stadiumVisitProvider.notifier).run();

      expect((await store.readStamps(_uid)).single.homeTeamId, 'doosan');
      expect((await _cellOf(store, _uid, 'jamsil_doosan'))!.count, 1);
      expect(
        (await store.readProfile(_uid))!.board.containsKey('jamsil_lg'),
        isFalse,
      );
    });

    test('이미 도장을 받은 경기만 남았으면 다시 측위하지 않는다', () async {
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);
      final recorder = _RecordingChecker(
        fix: const DeviceFix(lat: _jamsilLat, lng: _jamsilLng),
      );
      final container = await buildContainer(
        store: store,
        recorder: recorder,
        schedule: lgHomeSchedule,
      );

      await container.read(stadiumVisitProvider.notifier).run();
      expect(recorder.fixReads, 1);

      // 포그라운드 복귀 두 번 — 이 경기의 도장은 이미 있다.
      await container.read(stadiumVisitProvider.notifier).run();
      await container.read(stadiumVisitProvider.notifier).run();

      expect(
        recorder.fixReads,
        1,
        reason: '이미 받은 경기에서 GPS 를 다시 켜지 않는다',
      );
      expect(await store.readStamps(_uid), hasLength(1));
      expect(store.stampWrites, 1, reason: '쓰기 자체도 다시 시도하지 않는다');
    });

    test('아직 못 받은 경기가 하나라도 남아 있으면 다시 판정한다', () async {
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);
      final recorder = _RecordingChecker(
        fix: const DeviceFix(lat: _jamsilLat, lng: _jamsilLng),
      );
      final container = await buildContainer(
        store: store,
        recorder: recorder,
        // 같은 날 두 구장에 경기가 있다 — 하나를 받아도 나머지가 남는다.
        schedule: scheduleOf([
          _game(
            id: 'g-jamsil',
            date: '2026-08-25',
            home: 'lg',
            away: 'lotte',
            stadium: 'jamsil',
          ),
          _game(
            id: 'g-sajik',
            date: '2026-08-25',
            home: 'lotte',
            away: 'nc',
            stadium: 'sajik',
          ),
        ]),
      );

      await container.read(stadiumVisitProvider.notifier).run();
      await container.read(stadiumVisitProvider.notifier).run();

      expect(recorder.fixReads, 2);
    });

    test('경기가 없는 날에도 판정은 돌아 이유가 남는다', () async {
      // 게이트가 "후보가 비면 건너뛴다"로 잘못 서면 이 실행에서 상태가 null 로
      // 남고, 4.5("못 받는 날")가 신호로 쓸 이유가 사라진다.
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);
      final recorder = _RecordingChecker(
        fix: const DeviceFix(lat: _jamsilLat, lng: _jamsilLng),
      );
      final container = await buildContainer(
        store: store,
        recorder: recorder,
        schedule: scheduleOf(const []),
      );

      await container.read(stadiumVisitProvider.notifier).run();
      await container.read(stadiumVisitProvider.notifier).run();

      expect(
        container.read(stadiumVisitProvider)!.reason,
        StadiumVisitReason.noGameToday,
      );
    });

    test('오프라인에서 아직 서버 확인이 안 온 도장이 다음 판정을 막지 않는다', () async {
      // 도장 쓰기를 겹침 방지 빗장(`_running`) 안에서 기다리면, 통신이 끊긴
      // 구간 내내 다음 판정이 통째로 막힌다.
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);
      store.offline = true;
      final recorder = _RecordingChecker(
        fix: const DeviceFix(lat: _jamsilLat, lng: _jamsilLng),
      );
      final container = await buildContainer(
        store: store,
        recorder: recorder,
        schedule: scheduleOf([
          _game(
            id: 'g-jamsil',
            date: '2026-08-25',
            home: 'lg',
            away: 'lotte',
            stadium: 'jamsil',
          ),
          _game(
            id: 'g-sajik',
            date: '2026-08-25',
            home: 'lotte',
            away: 'nc',
            stadium: 'sajik',
          ),
        ]),
      );

      unawaited(container.read(stadiumVisitProvider.notifier).run());
      await pumpEventQueue();
      expect(recorder.fixReads, 1);
      expect(await store.readStamps(_uid), hasLength(1));

      await container.read(stadiumVisitProvider.notifier).run();

      expect(
        recorder.fixReads,
        2,
        reason: '서버 확인을 기다리는 동안에도 남은 경기의 판정은 돈다',
      );
    });

    test('방문이 아닌 판정은 아무것도 쓰지 않는다', () async {
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);
      // 잠실에서 한참 떨어진 지점 — 반경 밖이다.
      final recorder = _RecordingChecker(
        fix: const DeviceFix(lat: _sajikLat, lng: _sajikLng),
      );
      final container = await buildContainer(
        store: store,
        recorder: recorder,
        schedule: lgHomeSchedule,
      );

      await container.read(stadiumVisitProvider.notifier).run();

      expect(
        container.read(stadiumVisitProvider)!.reason,
        StadiumVisitReason.outsideRadius,
      );
      expect(await store.readStamps(_uid), isEmpty);
      expect((await store.readProfile(_uid))!.board, isEmpty);
    });

    test('도장 쓰기가 실패하면 다음 트리거가 다시 시도한다', () async {
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);
      store.stampWriteFailure = const BackendNetworkError(code: 'unavailable');
      final recorder = _RecordingChecker(
        fix: const DeviceFix(lat: _jamsilLat, lng: _jamsilLng),
      );
      final container = await buildContainer(
        store: store,
        recorder: recorder,
        schedule: lgHomeSchedule,
      );

      await container.read(stadiumVisitProvider.notifier).run();
      expect(await store.readStamps(_uid), isEmpty);
      expect(container.read(stampAwardProvider), isEmpty);

      store.stampWriteFailure = null;
      await container.read(stadiumVisitProvider.notifier).run();

      expect(recorder.fixReads, 2, reason: '실패한 경기는 다시 판정한다');
      expect(await store.readStamps(_uid), hasLength(1));
    });

    test('로그인한 계정이 없으면 도장을 쓰지 않는다', () async {
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      final recorder = _RecordingChecker(
        fix: const DeviceFix(lat: _jamsilLat, lng: _jamsilLng),
      );
      final container = await buildContainer(
        store: store,
        recorder: recorder,
        schedule: lgHomeSchedule,
        user: null,
      );

      await container.read(stadiumVisitProvider.notifier).run();

      expect(container.read(stadiumVisitProvider)!.isVisit, isTrue);
      expect(store.stampWrites, 0);
      expect(container.read(stampAwardProvider), isEmpty);
    });

    test('판에 없는 구장×홈팀 짝은 도장이 되지 않는다', () async {
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);
      final recorder = _RecordingChecker(
        fix: const DeviceFix(lat: _jamsilLat, lng: _jamsilLng),
      );
      final container = await buildContainer(
        store: store,
        recorder: recorder,
        // 잠실인데 홈팀이 기아 — 판의 10칸에 없는 짝이다.
        schedule: scheduleOf([
          _game(
            id: 'g-jamsil',
            date: '2026-08-25',
            home: 'kia',
            away: 'lotte',
            stadium: 'jamsil',
          ),
        ]),
      );

      await container.read(stadiumVisitProvider.notifier).run();

      expect(store.stampWrites, 0);
      expect((await store.readProfile(_uid))!.board, isEmpty);
    });
  });
}
