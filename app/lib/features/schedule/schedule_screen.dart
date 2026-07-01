import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../team/favorite_team_provider.dart';
import 'away_games_provider.dart';
import 'game.dart';

/// 원정 일정 — 내 팀이 away 인 경기만 다가오는 순. 응원팀 미설정이면 선택으로 유도.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite = ref.watch(favoriteTeamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('원정 일정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sports_baseball),
            tooltip: '응원팀 변경',
            onPressed: () => context.go('/team-select'),
          ),
        ],
      ),
      body: favorite.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message('응원팀 정보를 불러오지 못했어요\n$e'),
        data: (team) => team == null ? const _NoTeam() : const _AwayGamesList(),
      ),
    );
  }
}

class _NoTeam extends StatelessWidget {
  const _NoTeam();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('먼저 응원팀을 설정해 주세요'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/team-select'),
            child: const Text('응원팀 선택'),
          ),
        ],
      ),
    );
  }
}

class _AwayGamesList extends ConsumerWidget {
  const _AwayGamesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final games = ref.watch(awayGamesProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(awayGamesProvider),
      child: games.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message('일정을 불러오지 못했어요\n$e'),
        data: (list) {
          if (list.isEmpty) {
            return _Message('예정된 원정 경기가 없어요');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _GameCard(game: list[i]),
          );
        },
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('vs ${game.homeTeamShortName}'),
        subtitle: Text('${_formatDate(game.scheduledAt)} · ${game.stadiumName}'),
        trailing: _StatusBadge(status: game.status),
        onTap: () => context.go('/stadium/${game.stadiumId}'),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final GameStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = status == GameStatus.cancelled || status == GameStatus.postponed;
    return Chip(
      label: Text(status.label),
      backgroundColor: highlight ? scheme.errorContainer : scheme.surfaceContainerHighest,
      labelStyle: TextStyle(color: highlight ? scheme.onErrorContainer : scheme.onSurfaceVariant),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    // ListView 로 감싸 RefreshIndicator 의 당겨서새로고침이 빈/에러 상태에서도 먹게 한다.
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 120, horizontal: 24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String _formatDate(DateTime dt) {
  final wd = _weekdays[dt.weekday - 1];
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${dt.month}월 ${dt.day}일 ($wd) $hh:$mm';
}
