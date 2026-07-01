import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/supabase_client.dart';
import 'team.dart';

part 'teams_provider.g.dart';

/// 전체 10팀 1회 로드(거의 불변이라 keepAlive). 팀 선택 그리드·abbr↔id 해소의 원천.
@Riverpod(keepAlive: true)
Future<List<Team>> teams(Ref ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client.from('teams').select('id, abbr, name, short_name').order('abbr');
  return rows.map((r) => Team.fromJson(r)).toList();
}

/// abbr → Team. 로딩 중이면 빈 맵(룩업은 null).
@riverpod
Map<String, Team> teamsByAbbr(Ref ref) {
  final teams = ref.watch(teamsProvider).value ?? const [];
  return {for (final t in teams) t.abbr: t};
}

/// id → Team. 로딩 중이면 빈 맵(룩업은 null).
@riverpod
Map<String, Team> teamsById(Ref ref) {
  final teams = ref.watch(teamsProvider).value ?? const [];
  return {for (final t in teams) t.id: t};
}
