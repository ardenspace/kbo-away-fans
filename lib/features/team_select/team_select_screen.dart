import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/errors.dart';
import '../../content/content_loader.dart';
import '../../content/content_providers.dart';
import '../../content/models.dart';
import '../../design/tokens.dart';
import 'selected_team.dart';

/// 응원 팀 선택 화면 — 최초 실행 온보딩과 팀 변경(설정 진입점) 겸용.
///
/// 팀 목록은 teams.json([teamsProvider])에서 온다. 각 팀 카드는 그 팀의
/// 테마 색으로 칠해져, 고르기 전에 "앱이 물들 색"을 미리 보여 준다.
/// 탭 즉시 반영([SelectedTeamNotifier.select])되고, 온보딩 모드에서는
/// 루트 게이트가 홈으로 전환하며, 변경 모드([isChange])에서는 pop 한다.
///
/// 사용자 문서 쓰기(2.4)가 끝나기를 기다렸다가 화면을 넘기지 않는다 —
/// Firestore 쓰기의 Future 는 서버에 닿아야 끝나므로, 통신이 나쁜 자리에서
/// 기다리면 선택이 먹히지 않은 것처럼 보인다. 쓰기가 실패하면 그때 안내를
/// 띄운다.
///
/// 실패가 아닌데도 선택이 서버에 남지 않는 갈래가 하나 있다: 이 화면이
/// **온보딩으로 떴는데**(= [isChange] 가 false) 서버에는 이미 그 계정의 문서가
/// 있던 경우다 ([SelectedTeamNotifier.select] 참조 — 그 원본을 덮지 않는다).
/// 안내를 띄우지 않는 것은 실패한 것이 아니기 때문이고, 그 자리에서 원본을 한
/// 번 읽어 화면이 그 계정의 진짜 팀으로 수렴한다(스냅샷에 맡기지 않는다 — 이
/// 갈래에 이르는 주된 길이 스냅샷을 끝내 보지 못한 실행이라 뒤이어 오는
/// 스냅샷이 없을 수 있다). 읽기까지 실패해 수렴시키지 못하면 그때는
/// `BackendError` 로 던져 오고, 아래 [saveFailureNotice] 가 뜬다 — 화면이 고른
/// 팀에 남은 채 조용히 끝나지 않게 하는 자리다.
///
/// **변경 모드에서는 그 갈래가 없다.** 이 화면이 [isChange] 를 그대로
/// 건네므로([_select]), 같은 상태(스냅샷을 보지 못한 세션)에서도 고른 팀이
/// 원본을 갱신한다 — 바꾸려고 누른 사람의 선택을 물러서게 하면 화면이 잠깐
/// 새 팀으로 바뀌었다가 옛 팀으로 되돌아오고 까닭도 들리지 않는다.
class TeamSelectScreen extends ConsumerWidget {
  const TeamSelectScreen({super.key, this.isChange = false});

  /// 서버에 선택을 남기지 못했을 때의 안내.
  static const String saveFailureNotice = '선택을 저장하지 못했어요. 잠시 뒤 다시 시도해 주세요.';

  /// true 면 팀 변경 모드 — 앱바(뒤로 가기)가 있고 선택 후 pop 한다.
  final bool isChange;

  Future<void> _select(BuildContext context, WidgetRef ref, Team team) async {
    // 안내를 띄울 자리를 **첫 await 앞에서** 잡아 둔다. 변경 모드에서는 아래
    // `pop()` 이 이 화면을 트리에서 빼내는데, 서버 쓰기는 그 뒤에 끝나므로
    // 실패는 언제나 화면이 사라진 다음에 온다 — 그때 가서 context 로 조회하면
    // 이미 없는 화면을 뒤지게 되어 안내가 아무 데도 닿지 못한다. 대역의 쓰기가
    // 즉시 실패하는 시험에는 그 구간이 아예 없어서 이 순서가 뒤집혀도 드러나지
    // 않는다 — 서버 왕복을 붙잡아 그 구간을 만들어 재는 자리가
    // `team_select_test.dart` 의 '늦게 실패한 팀 바꾸기의 안내는 화면이 닫힌
    // 뒤에도 닿는다' 다.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = isChange ? Navigator.of(context) : null;
    // `select` 는 첫 await 앞에서 상태를 이미 옮겨 놓는다 — 그래서 여기서
    // 곧바로 화면을 넘겨도 홈은 새 팀 테마로 뜬다. 원본(사용자 문서)과
    // 사본(기기 캐시)은 그 뒤에 그 순서로 따라간다.
    final saved = ref
        .read(selectedTeamIdProvider.notifier)
        .select(team.id, isChange: isChange);
    // 서버 쓰기를 기다리지 않고 곧바로 닫는다 — `await saved` 뒤로 옮기면
    // 통신이 나쁜 자리에서 팀을 눌러도 이 화면이 그대로 남아 선택이 먹히지
    // 않은 것처럼 보인다.
    navigator?.pop();
    try {
      await saved;
    } on BackendError {
      // 문구만 얹고 꾸밈은 SnackBar 기본값에 맡긴다 — 어두운 바탕 위의 글자라
      // 본문 토큰(어두운 글자색)을 그대로 쓰면 읽히지 않는다.
      messenger?.showSnackBar(const SnackBar(content: Text(saveFailureNotice)));
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
