import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/content_loader.dart';
import '../../content/content_providers.dart';
import '../../content/models.dart';
import '../../design/tokens.dart';
import 'selected_team.dart';

/// 응원 팀 선택 화면 — 최초 실행 온보딩과 팀 변경(설정 진입점) 겸용.
///
/// 팀 목록은 teams.json([teamsProvider])에서 온다. 각 팀 카드는 그 팀의
/// 테마 색으로 칠해져, 고르기 전에 "앱이 물들 색"을 미리 보여 준다.
/// 탭 즉시 저장([SelectedTeamNotifier.select])되고, 온보딩 모드에서는
/// 루트 게이트가 홈으로 전환하며, 변경 모드([isChange])에서는 pop 한다.
class TeamSelectScreen extends ConsumerWidget {
  const TeamSelectScreen({super.key, this.isChange = false});

  /// true 면 팀 변경 모드 — 앱바(뒤로 가기)가 있고 선택 후 pop 한다.
  final bool isChange;

  Future<void> _select(BuildContext context, WidgetRef ref, Team team) async {
    await ref.read(selectedTeamIdProvider.notifier).select(team.id);
    if (isChange && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsResult = ref.watch(teamsProvider);
    final currentId = switch (ref.watch(selectedTeamIdProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };

    final body = switch (teamsResult) {
      AsyncData(:final value) => switch (value) {
        ContentFresh(:final data) || ContentFromCache(:final data) => _TeamList(
          teams: data.teams,
          currentId: currentId,
          isChange: isChange,
          onSelect: (team) => _select(context, ref, team),
        ),
        ContentUnavailable() => _LoadFailure(
          onRetry: () => ref.invalidate(teamsProvider),
        ),
      },
      AsyncError() => _LoadFailure(
        onRetry: () => ref.invalidate(teamsProvider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return Scaffold(
      appBar: isChange
          ? AppBar(
              backgroundColor: ColorTokens.background,
              foregroundColor: ColorTokens.textPrimary,
              title: Text('응원 팀 바꾸기', style: _titleStyle),
            )
          : null,
      body: SafeArea(child: body),
    );
  }

  static const TextStyle _titleStyle = TextTokens.heading;
}

/// 10팀 목록 — 전 팀이 한 번에 위젯 트리에 올라간다(스크롤 가능).
class _TeamList extends StatelessWidget {
  const _TeamList({
    required this.teams,
    required this.currentId,
    required this.isChange,
    required this.onSelect,
  });

  final List<Team> teams;
  final String? currentId;
  final bool isChange;
  final ValueChanged<Team> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: SpaceTokens.lg,
        vertical: SpaceTokens.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isChange) ...[
            const Text('어느 팀을 응원하세요?', style: TextTokens.display),
            const SizedBox(height: SpaceTokens.sm),
          ],
          const Text('선택한 팀의 컬러로 앱이 물들어요.', style: TextTokens.bodyMuted),
          const SizedBox(height: SpaceTokens.xl),
          for (final team in teams)
            Padding(
              padding: const EdgeInsets.only(bottom: SpaceTokens.md),
              child: _TeamCard(
                team: team,
                selected: team.id == currentId,
                onTap: () => onSelect(team),
              ),
            ),
        ],
      ),
    );
  }
}

/// 팀 카드 — 팀 테마 primary 로 칠하고 onPrimary 로 글자를 올린다.
///
/// 왼쪽 보조색 띠는 [TeamBadge] 와 같은 짜임이다. 카드가 배지의 큰 판본처럼
/// 읽혀야 홈 화면에서 배지를 만났을 때 같은 팀으로 이어 보이기 때문이다.
class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.selected,
    required this.onTap,
  });

  final Team team;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = team.theme;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        child: ColoredBox(
          color: theme.secondary,
          // 대표색 몸통을 왼쪽만 비켜 얹어, 남는 띠를 보조색 탭으로 쓴다.
          child: Padding(
            padding: const EdgeInsets.only(left: SpaceTokens.md),
            child: AnimatedContainer(
              duration: MotionTokens.fast,
              curve: MotionTokens.standard,
              padding: const EdgeInsets.symmetric(
                horizontal: SpaceTokens.lg,
                vertical: SpaceTokens.lg,
              ),
              color: theme.primary,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      team.name,
                      style: TextTokens.sectionTitle.copyWith(
                        color: theme.onPrimary,
                      ),
                    ),
                  ),
                  // 선택 표시만 오른쪽에 둔다. 약칭은 왼쪽 팀 이름과 겹치는
                  // 정보라서 두지 않는다.
                  if (selected)
                    Icon(Icons.check_circle_rounded, color: theme.onPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 팀 목록을 얻지 못했을 때의 명시적 실패 상태 + 재시도.
class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('팀 목록을 불러오지 못했어요.', style: TextTokens.bodyStrong),
          const SizedBox(height: SpaceTokens.md),
          TextButton(
            onPressed: onRetry,
            child: const Text('다시 시도', style: TextTokens.label),
          ),
        ],
      ),
    );
  }
}
