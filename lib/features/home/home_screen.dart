import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/content_loader.dart';
import '../../content/content_providers.dart';
import '../../content/models.dart';
import '../../design/tokens.dart';
import '../../ui/shared/team_theme_scope.dart';
import '../team_select/team_select_screen.dart';

/// 홈 화면 자리 (step 2.2) — D-day 기본 얼굴의 본격 구현은 step 2.3.
///
/// 선택한 팀을 teams.json 에서 찾아 계약상 포인터인 `themeKey` 로
/// [TeamThemeScope] 를 걸어, 하위 전체에 팀 테마를 적용한다.
/// teams 문서를 얻지 못하면 스코프 없이(기본 토큰, maybeOf 폴백) 렌더한다.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.teamId});

  /// 선택된 응원 팀 id (common.defs teamId).
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsDoc = switch (ref.watch(teamsProvider)) {
      AsyncData(:final value) => switch (value) {
          ContentFresh(:final data) || ContentFromCache(:final data) => data,
          ContentUnavailable() => null,
        },
      _ => null,
    };
    final team = teamsDoc?.byId(teamId);

    final scaffold = _HomeScaffold(team: team);
    if (team == null) return scaffold;
    return TeamThemeScope.forTeam(teamId: team.themeKey, child: scaffold);
  }
}

class _HomeScaffold extends StatelessWidget {
  const _HomeScaffold({required this.team});

  /// 응원 팀 — teams 문서를 아직 얻지 못했으면 null.
  final Team? team;

  @override
  Widget build(BuildContext context) {
    final theme = TeamThemeScope.maybeOf(context);
    final barBg = theme?.primary ?? ColorTokens.surface;
    final barFg = theme?.onPrimary ?? ColorTokens.textPrimary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: barBg,
        foregroundColor: barFg,
        title: Text(
          'KBO 원정 도장깨기',
          style: TextStyle(
            fontFamily: TypeTokens.fontFamily,
            fontSize: TypeTokens.heading,
            fontWeight: TypeTokens.weightExtraBold,
            color: barFg,
          ),
        ),
        actions: [
          // 팀 변경 진입점 (설정) — 같은 선택 화면을 변경 모드로 연다.
          IconButton(
            tooltip: '응원 팀 바꾸기',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const TeamSelectScreen(isChange: true),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (team != null)
              Text(
                '응원 팀: ${team!.name}',
                style: TextStyle(
                  fontFamily: TypeTokens.fontFamily,
                  fontSize: TypeTokens.title,
                  fontWeight: TypeTokens.weightExtraBold,
                  color: theme?.primary ?? ColorTokens.textPrimary,
                ),
              ),
            const SizedBox(height: SpaceTokens.md),
            const Text(
              '다음 원정 경기 D-day가 여기에 떠요. (step 2.3)',
              style: TextStyle(
                fontFamily: TypeTokens.fontFamily,
                fontSize: TypeTokens.body,
                fontWeight: TypeTokens.weightMedium,
                color: ColorTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
