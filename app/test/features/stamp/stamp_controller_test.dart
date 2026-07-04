/// task 1.5 — 발급 컨트롤러 상태머신·실패 분기·연타/중복 방지 테스트
/// (R3·R4·R5·R13·R14).
///
/// 위치 provider mock + repository fake 주입만으로 성립한다 — 실 Supabase·실기기
/// 시계·플러그인 없음. 위치는 `currentLocationProvider.overrideWith`, 저장 계층은
/// fake, 기준 시각은 `stampClockProvider` 로 주입한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/stamp/location_provider.dart';
import 'package:kbo_away_fans/features/stamp/stamp_controller.dart';
import 'package:kbo_away_fans/features/stamp/stamp_models.dart';
import 'package:kbo_away_fans/features/stamp/stamp_repository.dart';
import 'package:kbo_away_fans/features/stamp/stadium_repository.dart';

import 'fakes.dart';

// ── 구장 fixture (도메인 테스트와 동일 좌표) ────────────────────────────────
const _jamsilLat = 37.5122;
const _jamsilLng = 127.0717;
const _suwonLat = 37.2997;
const _suwonLng = 127.0098;

StampStadium _jamsilOb() => const StampStadium(
      id: 'stadium-jamsil-ob',
      name: '잠실야구장',
      lat: _jamsilLat,
      lng: _jamsilLng,
      stampRadiusM: 500,
      teamId: 'team-ob',
      teamAbbr: 'OB',
    );
StampStadium _jamsilLg() => const StampStadium(
      id: 'stadium-jamsil-lg',
      name: '잠실야구장 (LG)',
      lat: _jamsilLat,
      lng: _jamsilLng,
      stampRadiusM: 500,
      teamId: 'team-lg',
      teamAbbr: 'LG',
    );
StampStadium _suwonKt() => const StampStadium(
      id: 'stadium-suwon',
      name: '수원KT위즈파크',
      lat: _suwonLat,
      lng: _suwonLng,
      stampRadiusM: 500,
      teamId: 'team-kt',
      teamAbbr: 'KT',
    );

List<StampStadium> _allStadiums() => [_jamsilOb(), _jamsilLg(), _suwonKt()];

/// insert 호출 횟수를 세는 얇은 wrapper — 실패해도(예외 전에) 카운트한다 (R5·R14).
class CountingStampRepository implements StampRepository {
  CountingStampRepository(this.inner);

  final FakeStampRepository inner;
  int insertCalls = 0;
  int myStampsCalls = 0;

  @override
  Future<Stamp> insertStamp({
    required String stadiumId,
    required double lat,
    required double lng,
  }) {
    insertCalls++;
    return inner.insertStamp(stadiumId: stadiumId, lat: lat, lng: lng);
  }

  @override
  Future<List<Stamp>> myStamps() {
    myStampsCalls++;
    return inner.myStamps();
  }
}

/// 컨트롤러 테스트용 harness — 필요한 seam 을 전부 override 한 컨테이너.
class _Harness {
  _Harness({
    required LocationResult location,
    List<StampStadium>? stadiums,
    List<Stamp>? initialStamps,
    List<FakeGame> games = const [],
    Object? stadiumError,
    Object? gamesError,
    Object? insertError,
    Object? myStampsError,
    DateTime Function()? clock,
  })  : stampFake = FakeStampRepository(initial: initialStamps)
          ..insertError = insertError
          ..listError = myStampsError,
        gamesFake = FakeGamesRepository(games: games)..listError = gamesError {
    stampRepo = CountingStampRepository(stampFake);
    final stadiumFake =
        FakeStadiumRepository(stadiums: stadiums ?? _allStadiums())
          ..listError = stadiumError;
    container = ProviderContainer(
      overrides: [
        currentLocationProvider.overrideWith((ref) async => location),
        stadiumRepositoryProvider.overrideWithValue(stadiumFake),
        stampRepositoryProvider.overrideWithValue(stampRepo),
        gamesRepositoryProvider.overrideWithValue(gamesFake),
        if (clock != null)
          stampClockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
  }

  late final ProviderContainer container;
  final FakeStampRepository stampFake;
  final FakeGamesRepository gamesFake;
  late final CountingStampRepository stampRepo;

  StampController get controller =>
      container.read(stampControllerProvider.notifier);
  StampIssueState get state => container.read(stampControllerProvider);
}

const _acquiredAtJamsil =
    LocationAcquired(lat: _jamsilLat, lng: _jamsilLng);
const _acquiredAtSuwon = LocationAcquired(lat: _suwonLat, lng: _suwonLng);
// 수원 북쪽 0.05도 — 전 구장 반경 밖, 최근접은 수원(≈5.6km).
const _acquiredOutOfRange =
    LocationAcquired(lat: _suwonLat + 0.05, lng: _suwonLng);

DateTime Function() _clockKst20260704() =>
    () => DateTime.utc(2026, 7, 4, 9); // KST 2026-07-04 18:00
DateTime _kstDay20260704() => DateTime(2026, 7, 4);

void main() {
  test('초기 상태 — StampIdle, 진행 중 아님', () {
    final h = _Harness(location: _acquiredAtSuwon);
    expect(h.state, isA<StampIdle>());
    expect(h.state.isBusy, isFalse);
  });

  group('반경 내 발급 성공 (R1·R13)', () {
    test('단일 구장 반경 내 — 대상 칸 insert + StampIssued', () async {
      final h = _Harness(location: _acquiredAtSuwon);

      await h.controller.issue();

      expect(h.state, isA<StampIssued>());
      final issued = h.state as StampIssued;
      expect(issued.slots.map((s) => s.id), ['stadium-suwon']);
      // fake 저장 계층에 실제로 남는다.
      expect(h.stampFake.stamps.map((s) => s.stadiumId), ['stadium-suwon']);
      expect(h.stampRepo.insertCalls, 1);
    });

    test('발급 시 좌표가 저장된다 (lat/lng)', () async {
      final h = _Harness(location: _acquiredAtSuwon);
      await h.controller.issue();
      final saved = h.stampFake.stamps.single;
      expect(saved.lat, _suwonLat);
      expect(saved.lng, _suwonLng);
    });
  });

  group('반경 밖 (R2)', () {
    test('저장 미발생 + "구장까지 N.Nkm" 메시지', () async {
      final h = _Harness(location: _acquiredOutOfRange);

      await h.controller.issue();

      expect(h.state, isA<StampOutOfRangeState>());
      final out = h.state as StampOutOfRangeState;
      expect(out.nearest.stadium.id, 'stadium-suwon');
      expect(out.message, '구장까지 5.6km');
      expect(h.stampFake.stamps, isEmpty);
      expect(h.stampRepo.insertCalls, 0);
    });
  });

  group('위치 권한 거부 (R4)', () {
    test('설정 유도 상태 방출 + 저장 미발생 + 예외 없음(단위)', () async {
      final h = _Harness(
        location: const LocationPermissionDenied(permanently: true),
      );

      await h.controller.issue();

      expect(h.state, isA<StampPermissionRequired>());
      expect((h.state as StampPermissionRequired).permanently, isTrue);
      expect(h.stampFake.stamps, isEmpty);
      expect(h.stampRepo.insertCalls, 0);
    });

    testWidgets('권한 거부 — tester.takeException()==null (crash 없음)',
        (tester) async {
      final h = _Harness(
        location: const LocationPermissionDenied(permanently: false),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final s = ref.watch(stampControllerProvider);
                return Text('${s.runtimeType}',
                    textDirection: TextDirection.ltr);
              },
            ),
          ),
        ),
      );

      await h.controller.issue();
      await tester.pump();

      expect(h.state, isA<StampPermissionRequired>());
      expect(tester.takeException(), isNull);
    });
  });

  group('실패 분기 — 서비스 꺼짐/네트워크/타임아웃 (R5)', () {
    test('위치 서비스 꺼짐 — StampFailed(serviceDisabled), 저장 미발생', () async {
      final h = _Harness(location: const LocationServiceDisabled());

      await h.controller.issue();

      expect(h.state, isA<StampFailed>());
      expect((h.state as StampFailed).reason,
          StampFailureReason.serviceDisabled);
      expect(h.stampRepo.insertCalls, 0);
      // 재시도 가능: 진행 중 아님.
      expect(h.state.isBusy, isFalse);
    });

    test('위치 타임아웃 — StampFailed(locationTimeout)', () async {
      final h = _Harness(location: const LocationTimeout());
      await h.controller.issue();
      expect((h.state as StampFailed).reason,
          StampFailureReason.locationTimeout);
      expect(h.stampRepo.insertCalls, 0);
    });

    test('insert network error — StampFailed(network), 저장 미커밋', () async {
      final h = _Harness(
        location: _acquiredAtSuwon,
        insertError: const StampNetworkException(),
      );

      await h.controller.issue();

      expect((h.state as StampFailed).reason, StampFailureReason.network);
      // insert 는 시도됐지만(호출 1) 커밋은 안 됨.
      expect(h.stampRepo.insertCalls, 1);
      expect(h.stampFake.stamps, isEmpty);
    });

    test('구장 목록 조회 실패 — StampFailed(network), 저장 미발생', () async {
      final h = _Harness(
        location: _acquiredAtSuwon,
        stadiumError: const StampNetworkException(),
      );
      await h.controller.issue();
      expect((h.state as StampFailed).reason, StampFailureReason.network);
      expect(h.stampRepo.insertCalls, 0);
    });

    test('재시도 — 네트워크 실패 후 재호출 시 insert 카운트 +1 로 성공 수렴', () async {
      final h = _Harness(
        location: _acquiredAtSuwon,
        insertError: const StampNetworkException(),
      );

      await h.controller.issue();
      expect(h.state, isA<StampFailed>());
      expect(h.stampRepo.insertCalls, 1);

      // 네트워크 회복 → 다시 "도장 찍기".
      h.stampFake.insertError = null;
      await h.controller.issue();

      expect(h.state, isA<StampIssued>());
      expect(h.stampRepo.insertCalls, 2); // 재호출로 +1
      expect(h.stampFake.stamps, hasLength(1));
    });
  });

  group('중복 — 선판정·UNIQUE 위반 동일 수렴 (R3)', () {
    test('이미 찍힌 칸(선판정) — StampDuplicated, insert 미시도', () async {
      final h = _Harness(
        location: _acquiredAtSuwon,
        initialStamps: [
          Stamp(
            id: 'existing',
            userId: 'user-1',
            stadiumId: 'stadium-suwon',
            lat: _suwonLat,
            lng: _suwonLng,
            stampedAt: DateTime.utc(2026, 7, 1),
          ),
        ],
      );

      await h.controller.issue();

      expect(h.state, isA<StampDuplicated>());
      expect(h.stampRepo.insertCalls, 0); // 선판정으로 걸러짐
    });

    test('주입된 UNIQUE 위반(insert 중) — 동일 StampDuplicated', () async {
      final h = _Harness(
        location: _acquiredAtSuwon,
        insertError: const DuplicateStampException(),
      );

      await h.controller.issue();

      expect(h.state, isA<StampDuplicated>());
      expect(h.stampRepo.insertCalls, 1); // insert 시도 후 UNIQUE 로 수렴
      expect(h.stampFake.stamps, isEmpty);
    });
  });

  group('연타/중복 방지 (R14)', () {
    test('단일 칸 연타 — insert 호출 1회 이하', () async {
      final h = _Harness(location: _acquiredAtSuwon);

      // 첫 호출을 await 하기 전에 두 번째 호출(연타).
      final f1 = h.controller.issue();
      final f2 = h.controller.issue();
      await Future.wait([f1, f2]);

      expect(h.stampRepo.insertCalls, 1);
      expect(h.stampFake.stamps, hasLength(1));
      expect(h.state, isA<StampIssued>());
    });

    test('진행 중 상태는 isBusy 로 버튼 비활성화 신호를 준다', () async {
      final h = _Harness(location: _acquiredAtSuwon);
      final f = h.controller.issue();
      // 첫 await 이전에 동기적으로 진행 중 상태가 선다.
      expect(h.state, isA<StampIssuing>());
      expect(h.state.isBusy, isTrue);
      await f;
      expect(h.state.isBusy, isFalse);
    });
  });

  group('잠실 복수 칸 배정 (R13)', () {
    test('두산 홈 경기 — OB 칸만 발급 (insert 1)', () async {
      final h = _Harness(
        location: _acquiredAtJamsil,
        clock: _clockKst20260704(),
        games: [
          FakeGame(
            stadiumId: 'stadium-jamsil-ob',
            kstDay: _kstDay20260704(),
            homeAbbr: 'OB',
            awayAbbr: 'HT',
          ),
        ],
      );

      await h.controller.issue();

      expect(h.state, isA<StampIssued>());
      expect((h.state as StampIssued).slots.map((s) => s.teamAbbr), ['OB']);
      expect(h.stampFake.stamps.map((s) => s.stadiumId), ['stadium-jamsil-ob']);
      expect(h.stampRepo.insertCalls, 1);
    });

    test('무경기 — 두 칸 모두 발급 (insert 2)', () async {
      final h = _Harness(
        location: _acquiredAtJamsil,
        clock: _clockKst20260704(),
        games: const [],
      );

      await h.controller.issue();

      expect(h.state, isA<StampIssued>());
      expect(
        h.stampFake.stamps.map((s) => s.stadiumId).toSet(),
        {'stadium-jamsil-ob', 'stadium-jamsil-lg'},
      );
      expect(h.stampRepo.insertCalls, 2);
    });

    test('잠실 2칸 연타 — insert 호출 2회 이하', () async {
      final h = _Harness(
        location: _acquiredAtJamsil,
        clock: _clockKst20260704(),
        games: const [],
      );

      final f1 = h.controller.issue();
      final f2 = h.controller.issue();
      await Future.wait([f1, f2]);

      expect(h.stampRepo.insertCalls, 2);
      expect(h.stampFake.stamps, hasLength(2));
    });

    test('잠실 대상 전부 기발급 — StampDuplicated', () async {
      final h = _Harness(
        location: _acquiredAtJamsil,
        clock: _clockKst20260704(),
        games: const [],
        initialStamps: [
          Stamp(
            id: 'e1',
            userId: 'user-1',
            stadiumId: 'stadium-jamsil-ob',
            lat: _jamsilLat,
            lng: _jamsilLng,
            stampedAt: DateTime.utc(2026, 7, 1),
          ),
          Stamp(
            id: 'e2',
            userId: 'user-1',
            stadiumId: 'stadium-jamsil-lg',
            lat: _jamsilLat,
            lng: _jamsilLng,
            stampedAt: DateTime.utc(2026, 7, 1),
          ),
        ],
      );

      await h.controller.issue();

      expect(h.state, isA<StampDuplicated>());
      expect(h.stampRepo.insertCalls, 0);
    });

    test('잠실 한 칸 기발급 — 나머지 칸만 발급 (선판정 건너뛰기)', () async {
      final h = _Harness(
        location: _acquiredAtJamsil,
        clock: _clockKst20260704(),
        games: const [],
        initialStamps: [
          Stamp(
            id: 'e1',
            userId: 'user-1',
            stadiumId: 'stadium-jamsil-ob',
            lat: _jamsilLat,
            lng: _jamsilLng,
            stampedAt: DateTime.utc(2026, 7, 1),
          ),
        ],
      );

      await h.controller.issue();

      expect(h.state, isA<StampIssued>());
      expect((h.state as StampIssued).slots.map((s) => s.id),
          ['stadium-jamsil-lg']);
      expect(h.stampRepo.insertCalls, 1);
    });
  });

  group('잠실 부분 실패 — 성공 칸 성공·실패 칸 실패 (R13)', () {
    test('OB 성공·LG 네트워크 실패 → StampPartiallyIssued', () async {
      // 특정 칸만 실패시키는 조건부 저장 계층.
      final repo = _ConditionalStampRepository(failStadiumId: 'stadium-jamsil-lg');
      final stadiumFake = FakeStadiumRepository(stadiums: _allStadiums());
      final gamesFake = FakeGamesRepository(games: const []);
      final container = ProviderContainer(
        overrides: [
          currentLocationProvider.overrideWith((ref) async => _acquiredAtJamsil),
          stadiumRepositoryProvider.overrideWithValue(stadiumFake),
          stampRepositoryProvider.overrideWithValue(repo),
          gamesRepositoryProvider.overrideWithValue(gamesFake),
          stampClockProvider.overrideWithValue(_clockKst20260704()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(stampControllerProvider.notifier).issue();

      final state = container.read(stampControllerProvider);
      expect(state, isA<StampPartiallyIssued>());
      final partial = state as StampPartiallyIssued;
      expect(partial.issuedSlots.map((s) => s.id), ['stadium-jamsil-ob']);
      expect(partial.failedSlots.map((s) => s.id), ['stadium-jamsil-lg']);
      // 성공 칸은 저장됨.
      expect(repo.saved.map((s) => s.stadiumId), ['stadium-jamsil-ob']);
    });
  });
}

/// 특정 stadiumId 의 insert 만 [StampNetworkException] 으로 실패시키는 저장 계층.
class _ConditionalStampRepository implements StampRepository {
  _ConditionalStampRepository({required this.failStadiumId});

  final String failStadiumId;
  final List<Stamp> saved = [];
  int _seq = 0;

  @override
  Future<Stamp> insertStamp({
    required String stadiumId,
    required double lat,
    required double lng,
  }) async {
    if (stadiumId == failStadiumId) {
      throw const StampNetworkException();
    }
    final stamp = Stamp(
      id: 'stamp-${_seq++}',
      userId: 'user-1',
      stadiumId: stadiumId,
      lat: lat,
      lng: lng,
      stampedAt: DateTime.utc(2026, 7, 4),
    );
    saved.add(stamp);
    return stamp;
  }

  @override
  Future<List<Stamp>> myStamps() async => List.unmodifiable(saved);
}
