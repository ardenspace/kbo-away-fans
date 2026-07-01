import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/supabase_client.dart';
import '../../shared/theme/team_theme_provider.dart';
import 'team.dart';
import 'teams_provider.dart';

part 'favorite_team_provider.g.dart';

/// 내 응원팀 — 진실의 원천 = `profiles.favorite_team_id` (클라우드, 재설치 생존).
///
/// 상태가 바뀔 때마다(초기 로드·선택) `listenSelf` 로 [CurrentTeam] 에 abbr 를 sync 해
/// 테마 컬러(task-008)를 따라가게 한다. 선택은 낙관적 — 로컬 먼저, DB 실패 시 롤백.
@Riverpod(keepAlive: true)
class FavoriteTeam extends _$FavoriteTeam {
  @override
  Future<Team?> build() async {
    final client = ref.watch(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;

    final teams = await ref.watch(teamsProvider.future);
    final row = await client
        .from('profiles')
        .select('favorite_team_id')
        .eq('id', userId)
        .maybeSingle();

    final teamId = row?['favorite_team_id'] as String?;
    final team = teamId == null ? null : {for (final t in teams) t.id: t}[teamId];

    // 초기 로드 결과를 테마에 반영. build 중 타 provider 변경 금지라 microtask 로 미룬다.
    Future.microtask(() => _syncTheme(team?.abbr));
    return team;
  }

  /// 응원팀 변경. 낙관적: 로컬 상태(→테마) 먼저, profiles update 실패 시 롤백 후 rethrow.
  Future<void> select(Team team) async {
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final previous = state.value;
    state = AsyncData(team);
    _syncTheme(team.abbr);
    try {
      await client
          .from('profiles')
          .update({'favorite_team_id': team.id}).eq('id', userId);
    } catch (e) {
      state = AsyncData(previous);
      _syncTheme(previous?.abbr);
      rethrow;
    }
  }

  /// 런타임 테마 전환 — [CurrentTeam] 에 abbr 를 밀어넣는다.
  void _syncTheme(String? abbr) =>
      ref.read(currentTeamProvider.notifier).select(abbr);
}
