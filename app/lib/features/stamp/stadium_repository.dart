import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'stamp_models.dart';

part 'stadium_repository.g.dart';

/// 스탬프북용 구장 목록 인터페이스. fake 교체 가능 — Supabase 는 실구현 안에만.
abstract interface class StadiumRepository {
  /// 전체 구장 목록 (팀 식별 필드 포함). 실패는 [StampNetworkException].
  Future<List<StampStadium>> listStadiums();
}

/// 특정 날짜·구장 경기의 등장 팀 조회 인터페이스 (R13 잠실 칸 배정 재료).
///
/// 기존 games 테이블 읽기만 — 크롤러 무변경. ∩ {두산, LG} 판정은 task 1.4 몫.
abstract interface class GamesRepository {
  /// [kstDay] 가 가리키는 KST 달력일에 [stadiumId] 구장에서 열리는 경기들의
  /// 홈·원정 팀 abbr 집합. 기준일이 인자라 실기기 시계에 묶이지 않는다.
  /// 실패는 [StampNetworkException].
  Future<Set<String>> teamAbbrsInGamesOn({
    required String stadiumId,
    required DateTime kstDay,
  });
}

/// Supabase 실구현 — stadiums + teams join.
class SupabaseStadiumRepository implements StadiumRepository {
  const SupabaseStadiumRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<StampStadium>> listStadiums() async {
    try {
      final rows = await _client
          .from('stadiums')
          .select('id, name, lat, lng, stamp_radius_m, team_id, '
              'team:teams!team_id(abbr)')
          .order('name', ascending: true);
      return rows.map(StampStadium.fromJson).toList();
    } catch (e) {
      throw StampNetworkException(e);
    }
  }
}

/// KST(UTC+9) 고정 오프셋 — DST 없음.
const _kstOffset = Duration(hours: 9);

/// Supabase 실구현 — games 테이블 읽기 전용.
class SupabaseGamesRepository implements GamesRepository {
  const SupabaseGamesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Set<String>> teamAbbrsInGamesOn({
    required String stadiumId,
    required DateTime kstDay,
  }) async {
    // KST 달력일 [00:00, 24:00) → UTC 범위.
    final dayStartUtc = DateTime.utc(kstDay.year, kstDay.month, kstDay.day)
        .subtract(_kstOffset);
    final dayEndUtc = dayStartUtc.add(const Duration(days: 1));

    try {
      final rows = await _client
          .from('games')
          .select('home_team:teams!home_team_id(abbr), '
              'away_team:teams!away_team_id(abbr)')
          .eq('stadium_id', stadiumId)
          .gte('scheduled_at', dayStartUtc.toIso8601String())
          .lt('scheduled_at', dayEndUtc.toIso8601String());
      return {
        for (final row in rows) ...[
          (row['home_team'] as Map<String, dynamic>)['abbr'] as String,
          (row['away_team'] as Map<String, dynamic>)['abbr'] as String,
        ],
      };
    } catch (e) {
      throw StampNetworkException(e);
    }
  }
}

/// 실구현 주입점. 테스트에서 `stadiumRepositoryProvider.overrideWithValue(fake)`.
@riverpod
StadiumRepository stadiumRepository(Ref ref) =>
    SupabaseStadiumRepository(ref.watch(supabaseClientProvider));

/// 실구현 주입점. 테스트에서 `gamesRepositoryProvider.overrideWithValue(fake)`.
@riverpod
GamesRepository gamesRepository(Ref ref) =>
    SupabaseGamesRepository(ref.watch(supabaseClientProvider));
