import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/team_colors.dart';
import 'favorite_team_provider.dart';
import 'team.dart';
import 'teams_provider.dart';

/// 응원팀 선택 — 10팀 그리드. 탭하면 클라우드 저장(profiles) + 테마 전환 후 일정으로.
class TeamSelectScreen extends ConsumerWidget {
  const TeamSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsProvider);
    final current = ref.watch(favoriteTeamProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('응원팀 선택')),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('팀을 불러오지 못했어요\n$e', textAlign: TextAlign.center)),
        data: (teams) => GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            for (final team in teams)
              _TeamTile(
                team: team,
                selected: team.id == current?.id,
                onTap: () => _select(context, ref, team),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _select(BuildContext context, WidgetRef ref, Team team) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final canPop = router.canPop();
    try {
      await ref.read(favoriteTeamProvider.notifier).select(team);
      if (canPop) {
        router.pop();
      } else {
        router.go('/schedule');
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('응원팀 저장에 실패했어요. 다시 시도해 주세요.')),
      );
    }
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({required this.team, required this.selected, required this.onTap});

  final Team team;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = kTeamColors[team.abbr] ?? kNeutralColors;
    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Text(
                team.shortName,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (selected)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(Icons.check_circle, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
