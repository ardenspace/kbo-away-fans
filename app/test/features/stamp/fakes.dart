/// 스탬프 기능 공용 테스트 fake — task 1.4~1.6 에서 재사용한다.
///
/// 실 Supabase 를 전혀 쓰지 않고, provider override 로 주입한다:
/// `stampRepositoryProvider.overrideWithValue(fake)` 등.
library;

import 'package:kbo_away_fans/features/stamp/stamp_models.dart';
import 'package:kbo_away_fans/features/stamp/stamp_repository.dart';
import 'package:kbo_away_fans/features/stamp/stadium_repository.dart';

/// 인메모리 스탬프 저장소. UNIQUE(user_id, stadium_id) 를 fake 스스로 강제한다.
class FakeStampRepository implements StampRepository {
  FakeStampRepository({
    List<Stamp>? initial,
    this.userId = 'user-1',
    DateTime Function()? now,
  }) : stamps = [...?initial],
       _now = now ?? DateTime.now;

  /// fake 저장 계층 — insert 된 스탬프가 여기 남는다 (R1 검증 지점).
  final List<Stamp> stamps;

  final String userId;
  final DateTime Function() _now;

  /// 설정 시 insert 가 이 에러를 던진다 (주입된 UNIQUE 위반·네트워크 에러 경로).
  Object? insertError;

  /// 설정 시 myStamps 가 이 에러를 던진다 (조회 실패 경로).
  Object? listError;

  int _seq = 0;

  @override
  Future<Stamp> insertStamp({
    required String stadiumId,
    required double lat,
    required double lng,
  }) async {
    final error = insertError;
    if (error != null) throw error;
    if (stamps.any((s) => s.userId == userId && s.stadiumId == stadiumId)) {
      throw const DuplicateStampException();
    }
    final stamp = Stamp(
      id: 'stamp-${_seq++}',
      userId: userId,
      stadiumId: stadiumId,
      lat: lat,
      lng: lng,
      stampedAt: _now(),
    );
    stamps.add(stamp);
    return stamp;
  }

  @override
  Future<List<Stamp>> myStamps() async {
    final error = listError;
    if (error != null) throw error;
    // 서버(fake) 응답만이 소스 — 별도 캐시 없음 (R6).
    return List.unmodifiable(stamps);
  }
}

/// 인메모리 구장 저장소.
class FakeStadiumRepository implements StadiumRepository {
  FakeStadiumRepository({List<StampStadium>? stadiums})
    : stadiums = [...?stadiums];

  final List<StampStadium> stadiums;

  /// 설정 시 listStadiums 가 이 에러를 던진다.
  Object? listError;

  @override
  Future<List<StampStadium>> listStadiums() async {
    final error = listError;
    if (error != null) throw error;
    return List.unmodifiable(stadiums);
  }
}

/// fake 경기 한 건 — KST 달력일 기준.
class FakeGame {
  const FakeGame({
    required this.stadiumId,
    required this.kstDay,
    required this.homeAbbr,
    required this.awayAbbr,
  });

  final String stadiumId;
  final DateTime kstDay;
  final String homeAbbr;
  final String awayAbbr;
}

/// 인메모리 경기 조회 — 시나리오(경기 목록)와 조회 기준일 모두 주입 가능 (R13).
class FakeGamesRepository implements GamesRepository {
  FakeGamesRepository({List<FakeGame>? games}) : games = [...?games];

  final List<FakeGame> games;

  /// 설정 시 조회가 이 에러를 던진다.
  Object? listError;

  @override
  Future<Set<String>> teamAbbrsInGamesOn({
    required String stadiumId,
    required DateTime kstDay,
  }) async {
    final error = listError;
    if (error != null) throw error;
    return {
      for (final g in games)
        if (g.stadiumId == stadiumId &&
            g.kstDay.year == kstDay.year &&
            g.kstDay.month == kstDay.month &&
            g.kstDay.day == kstDay.day) ...[g.homeAbbr, g.awayAbbr],
    };
  }
}
