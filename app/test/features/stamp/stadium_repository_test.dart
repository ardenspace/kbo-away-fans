import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/stamp/stamp_models.dart';
import 'package:kbo_away_fans/features/stamp/stadium_repository.dart';

import 'fakes.dart';

StampStadium stadium({
  String id = 'stadium-1',
  String name = '잠실야구장',
  String teamId = 'team-ob',
  String teamAbbr = 'OB',
}) => StampStadium(
  id: id,
  name: name,
  lat: 37.5122,
  lng: 127.0717,
  stampRadiusM: 500,
  teamId: teamId,
  teamAbbr: teamAbbr,
);

void main() {
  group('StampStadium 모델 — 팀 식별 필드 (task 1.4·1.6 의존)', () {
    test('fromJson — team_id 와 팀 abbr(컬러 키)를 포함한다', () {
      final s = StampStadium.fromJson(const {
        'id': 'stadium-jamsil-lg',
        'name': '잠실야구장 (LG)',
        'lat': 37.5122,
        'lng': 127.0717,
        'stamp_radius_m': 500,
        'team_id': 'team-lg',
        'team': {'abbr': 'LG'},
      });
      expect(s.id, 'stadium-jamsil-lg');
      expect(s.name, '잠실야구장 (LG)');
      expect(s.lat, 37.5122);
      expect(s.lng, 127.0717);
      expect(s.stampRadiusM, 500);
      // 팀 식별 정보 — 칸 식별(1.4)과 팀 컬러 도장(1.6)이 의존하는 필드.
      expect(s.teamId, 'team-lg');
      expect(s.teamAbbr, 'LG');
    });
  });

  group('구장 목록 조회', () {
    test('fake 가 반환한 구장 목록이 그대로 온다', () async {
      final repo = FakeStadiumRepository(
        stadiums: [
          stadium(id: 'ob', teamId: 'team-ob', teamAbbr: 'OB'),
          stadium(
            id: 'lg',
            name: '잠실야구장 (LG)',
            teamId: 'team-lg',
            teamAbbr: 'LG',
          ),
        ],
      );

      final result = await repo.listStadiums();

      expect(result, hasLength(2));
      expect(result.map((s) => s.teamAbbr), ['OB', 'LG']);
    });

    test('조회 실패 — StampNetworkException 으로 받는다', () async {
      final repo = FakeStadiumRepository()
        ..listError = const StampNetworkException();

      await expectLater(
        repo.listStadiums(),
        throwsA(isA<StampNetworkException>()),
      );
    });
  });

  group('특정 날짜 잠실 경기 팀 조회 (R13)', () {
    const jamsil = 'stadium-jamsil';

    test('해당 KST 날짜 경기의 홈·원정 팀 abbr 이 반환된다', () async {
      final repo = FakeGamesRepository(
        games: [
          FakeGame(
            stadiumId: jamsil,
            kstDay: DateTime(2026, 7, 4),
            homeAbbr: 'OB',
            awayAbbr: 'HT',
          ),
        ],
      );

      final teams = await repo.teamAbbrsInGamesOn(
        stadiumId: jamsil,
        kstDay: DateTime(2026, 7, 4),
      );

      expect(teams, {'OB', 'HT'});
    });

    test('경기 없는 날짜 — 빈 집합 (기준일이 주입 가능해 실기기 시계에 안 묶인다)', () async {
      final repo = FakeGamesRepository(
        games: [
          FakeGame(
            stadiumId: jamsil,
            kstDay: DateTime(2026, 7, 4),
            homeAbbr: 'OB',
            awayAbbr: 'HT',
          ),
        ],
      );

      final teams = await repo.teamAbbrsInGamesOn(
        stadiumId: jamsil,
        kstDay: DateTime(2026, 7, 5),
      );

      expect(teams, isEmpty);
    });

    test('다른 구장 경기는 제외된다', () async {
      final repo = FakeGamesRepository(
        games: [
          FakeGame(
            stadiumId: 'stadium-gocheok',
            kstDay: DateTime(2026, 7, 4),
            homeAbbr: 'KW',
            awayAbbr: 'SS',
          ),
        ],
      );

      final teams = await repo.teamAbbrsInGamesOn(
        stadiumId: jamsil,
        kstDay: DateTime(2026, 7, 4),
      );

      expect(teams, isEmpty);
    });

    test('조회 실패 — StampNetworkException 으로 받는다', () async {
      final repo = FakeGamesRepository()
        ..listError = const StampNetworkException();

      await expectLater(
        repo.teamAbbrsInGamesOn(stadiumId: jamsil, kstDay: DateTime(2026, 7, 4)),
        throwsA(isA<StampNetworkException>()),
      );
    });
  });

  group('provider 주입점', () {
    test('stadiumRepositoryProvider·gamesRepositoryProvider 를 fake 로 override 할 수 있다', () {
      final fakeStadiums = FakeStadiumRepository();
      final fakeGames = FakeGamesRepository();
      final container = ProviderContainer(
        overrides: [
          stadiumRepositoryProvider.overrideWithValue(fakeStadiums),
          gamesRepositoryProvider.overrideWithValue(fakeGames),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(stadiumRepositoryProvider), same(fakeStadiums));
      expect(container.read(gamesRepositoryProvider), same(fakeGames));
    });
  });
}
