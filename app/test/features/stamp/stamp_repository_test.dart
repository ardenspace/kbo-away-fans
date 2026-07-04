import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/stamp/stamp_models.dart';
import 'package:kbo_away_fans/features/stamp/stamp_repository.dart';

import 'fakes.dart';

void main() {
  group('Stamp 모델', () {
    test('fromJson — user_id·stadium_id·lat·lng·stamped_at 매핑', () {
      final stamp = Stamp.fromJson(const {
        'id': 'stamp-1',
        'user_id': 'user-1',
        'stadium_id': 'stadium-jamsil',
        'lat': 37.5122,
        'lng': 127.0717,
        'stamped_at': '2026-07-04T10:30:00Z',
      });
      expect(stamp.id, 'stamp-1');
      expect(stamp.userId, 'user-1');
      expect(stamp.stadiumId, 'stadium-jamsil');
      expect(stamp.lat, 37.5122);
      expect(stamp.lng, 127.0717);
      expect(stamp.stampedAt, DateTime.utc(2026, 7, 4, 10, 30));
    });
  });

  group('insert (R1·R3)', () {
    test('insert 하면 fake 저장 계층에 user·stadium·좌표·시각이 남는다', () async {
      final now = DateTime.utc(2026, 7, 4, 9);
      final repo = FakeStampRepository(now: () => now);

      await repo.insertStamp(
        stadiumId: 'stadium-jamsil',
        lat: 37.5122,
        lng: 127.0717,
      );

      expect(repo.stamps, hasLength(1));
      final saved = repo.stamps.single;
      expect(saved.userId, 'user-1');
      expect(saved.stadiumId, 'stadium-jamsil');
      expect(saved.lat, 37.5122);
      expect(saved.lng, 127.0717);
      expect(saved.stampedAt, now);
    });

    test('같은 (user, stadium) 재-insert — DuplicateStampException 으로 구분된다', () async {
      final repo = FakeStampRepository();
      await repo.insertStamp(stadiumId: 's1', lat: 1, lng: 2);

      await expectLater(
        repo.insertStamp(stadiumId: 's1', lat: 1, lng: 2),
        throwsA(isA<DuplicateStampException>()),
      );
      // 저장은 1건 그대로 — 재발급 없음.
      expect(repo.stamps, hasLength(1));
    });

    test('주입된 UNIQUE 위반 에러도 동일 타입으로 표면화된다', () async {
      final repo = FakeStampRepository()
        ..insertError = const DuplicateStampException();

      await expectLater(
        repo.insertStamp(stadiumId: 's9', lat: 1, lng: 2),
        throwsA(isA<DuplicateStampException>()),
      );
    });

    test('중복 예외는 network 에러 타입과 구분된다', () {
      expect(const DuplicateStampException(), isNot(isA<StampNetworkException>()));
      expect(const StampNetworkException(), isNot(isA<DuplicateStampException>()));
    });
  });

  group('내 스탬프 목록 (R6)', () {
    test('fake 가 N개 반환하면 목록 길이도 N — 다른 소스 없음', () async {
      final stamps = List.generate(
        3,
        (i) => Stamp(
          id: 'stamp-$i',
          userId: 'user-1',
          stadiumId: 'stadium-$i',
          lat: 37.0 + i,
          lng: 127.0 + i,
          stampedAt: DateTime.utc(2026, 7, i + 1),
        ),
      );
      final repo = FakeStampRepository(initial: stamps);

      final result = await repo.myStamps();

      expect(result, hasLength(3));
      expect(result.map((s) => s.stadiumId), ['stadium-0', 'stadium-1', 'stadium-2']);
    });

    test('조회 실패(network error) — StampNetworkException 으로 받는다', () async {
      final repo = FakeStampRepository()
        ..listError = const StampNetworkException();

      await expectLater(
        repo.myStamps(),
        throwsA(isA<StampNetworkException>()),
      );
    });
  });

  group('provider 주입점', () {
    test('stampRepositoryProvider 를 fake 로 override 할 수 있다', () async {
      final fake = FakeStampRepository();
      final container = ProviderContainer(
        overrides: [stampRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final repo = container.read(stampRepositoryProvider);
      expect(repo, same(fake));

      // 인터페이스 경유로만 동작 — Supabase 없이 insert/조회가 성립한다.
      await repo.insertStamp(stadiumId: 's1', lat: 1, lng: 2);
      expect(await repo.myStamps(), hasLength(1));
    });
  });
}
