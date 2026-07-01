import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/supabase_client.dart';
import '../team/favorite_team_provider.dart';
import 'game.dart';

part 'away_games_provider.g.dart';

/// 내 팀 원정 경기(= 내 팀이 away) 다가오는 순. on-demand: 화면 진입마다 DB 최신 1회 조회
/// (autoDispose → 재진입 = 재조회). 크롤러(task-006)가 유지하는 상태를 읽기만 한다.
@riverpod
Future<List<Game>> awayGames(Ref ref) async {
  final team = await ref.watch(favoriteTeamProvider.future);
  if (team == null) return const [];

  final client = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);

  final rows = await client
      .from('games')
      .select(
        'id, scheduled_at, status, stadium_id, '
        'home_team:teams!home_team_id(short_name, abbr), '
        'stadium:stadiums!stadium_id(name)',
      )
      .eq('away_team_id', team.id)
      .gte('scheduled_at', startOfToday.toUtc().toIso8601String())
      .order('scheduled_at');

  return rows.map(Game.fromJson).toList();
}
