import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/supabase_client.dart';
import 'stadium.dart';

part 'stadium_provider.g.dart';

/// 구장 상세 — id 로 1행 조회. on-demand: 화면 진입마다 최신 1회(autoDispose → 재진입=재조회).
/// task-010 awayGames 와 같은 읽기 패턴.
@riverpod
Future<Stadium> stadium(Ref ref, String id) async {
  final client = ref.watch(supabaseClientProvider);
  final row = await client
      .from('stadiums')
      .select(
        'id, name, city, address, '
        'parking_info, seating_info, route_info, convenience_info',
      )
      .eq('id', id)
      .single();
  return Stadium.fromJson(row);
}
