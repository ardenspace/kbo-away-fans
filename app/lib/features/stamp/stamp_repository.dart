import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import 'stamp_models.dart';

part 'stamp_repository.g.dart';

/// 스탬프 저장·조회 인터페이스.
///
/// Supabase 직접 참조는 [SupabaseStampRepository] 안에만 둔다 —
/// 단위 테스트는 이 인터페이스의 fake 를 provider override 로 주입한다.
abstract interface class StampRepository {
  /// 스탬프 발급(insert). 현재 로그인 사용자 소유로 저장된다 (R1).
  ///
  /// - 이미 (user, stadium) 스탬프가 있으면 [DuplicateStampException] (R3).
  /// - 네트워크·서버 오류는 전부 [StampNetworkException] 하나로.
  Future<Stamp> insertStamp({
    required String stadiumId,
    required double lat,
    required double lng,
  });

  /// 내 스탬프 목록 — 서버 응답만이 소스, 로컬 캐시 폴백 없음 (R6).
  ///
  /// 조회 실패는 [StampNetworkException].
  Future<List<Stamp>> myStamps();
}

/// Postgres UNIQUE 위반 SQLSTATE.
const _uniqueViolationCode = '23505';

/// Supabase 실구현. stamps 테이블은 owner-scoped RLS — 본인 row 만 읽기/쓰기.
class SupabaseStampRepository implements StampRepository {
  const SupabaseStampRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('로그인 없이 스탬프 API 호출 — 라우터 게이팅 위반');
    }
    return user.id;
  }

  @override
  Future<Stamp> insertStamp({
    required String stadiumId,
    required double lat,
    required double lng,
  }) async {
    try {
      final row = await _client
          .from('stamps')
          .insert({
            'user_id': _userId,
            'stadium_id': stadiumId,
            'lat': lat,
            'lng': lng,
          })
          .select('id, user_id, stadium_id, lat, lng, stamped_at')
          .single();
      return Stamp.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolationCode) {
        throw const DuplicateStampException();
      }
      throw StampNetworkException(e);
    } on StateError {
      rethrow;
    } catch (e) {
      // 오프라인·타임아웃·5xx 등 — 전부 동일 취급.
      throw StampNetworkException(e);
    }
  }

  @override
  Future<List<Stamp>> myStamps() async {
    try {
      final rows = await _client
          .from('stamps')
          .select('id, user_id, stadium_id, lat, lng, stamped_at')
          .eq('user_id', _userId)
          .order('stamped_at', ascending: true);
      return rows.map(Stamp.fromJson).toList();
    } on StateError {
      rethrow;
    } catch (e) {
      throw StampNetworkException(e);
    }
  }
}

/// 실구현 주입점. 테스트에서 `stampRepositoryProvider.overrideWithValue(fake)`.
@riverpod
StampRepository stampRepository(Ref ref) =>
    SupabaseStampRepository(ref.watch(supabaseClientProvider));
