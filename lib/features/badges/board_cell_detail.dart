/// 배지 판의 칸 상세 (step 4.3) — 그 칸에 쌓인 도장을 날짜와 함께 보여준다.
///
/// **여기가 도장 문서를 읽는 유일한 화면이다.** 판([StampBoard])은 사용자
/// 문서의 칸별 요약만 보고 그리고, 개별 도장은 사람이 칸을 열 때 비로소
/// 읽힌다 — `.wellbegun/decisions.md` 의 판 읽기 패턴 `[L]` 결정이 정한 순서다.
///
/// **빈 칸은 서버를 아예 읽지 않는다.** 칸 요약([cell])이 null 이라는 것은
/// 그 칸에 도장이 하나도 없다는 뜻이고(요약 map 은 도장이 없는 칸의 키를 두지
/// 않는다 — decisions.md 2026-09-01 `[M]`), 그 답을 이미 손에 쥔 채로 다시
/// 질의하면 아무것도 돌려주지 않을 읽기가 칸을 누를 때마다 나간다. 판 위의
/// 열 칸 가운데 대부분이 한동안 빈 칸이므로, 그 낭비가 곧 이 단계가 피하려는
/// 그 비용이다.
///
/// 이름·문구를 콘텐츠에서 못 얻은 실행에서는 id 로 저하 렌더한다 — 도장은
/// 서버에 있고 이름은 정적 JSON 에서 오는 별개의 것이라, 뒤엣것 때문에 앞엣
/// 것을 못 보여줄 까닭이 없다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/user_data.dart';
import '../../content/content_providers.dart';
import '../../design/app_theme.dart';
import '../../design/tokens.dart';
import '../../ui/shared/content_fallback.dart';
import '../../ui/shared/empty_state_notice.dart';

class BoardCellDetail extends ConsumerWidget {
  const BoardCellDetail({super.key, required this.cellId, this.cell});

  /// 어느 칸인가 — `{stadiumId}_{homeTeamId}`.
  final String cellId;

  /// 그 칸의 요약. **null 이면 도장이 하나도 없는 칸이다** (요약 map 은 빈 칸의
  /// 키를 두지 않는다). 그 실행에서 이 화면은 서버를 읽지 않는다.
  final BoardCell? cell;

  /// 도장 목록을 못 읽은 자리의 안내 제목.
  static const String loadFailureTitle = '도장을 불러오지 못했어요';

  /// 아직 한 번도 못 간 칸의 안내.
  static const String emptyTitle = '아직 이 구장의 도장이 없어요';
  static const String emptyMessage = '경기가 있는 날 이 구장 근처에서 앱을 열면 도장이 찍혀요.';

  /// 표준 진입점 — 모달 바텀시트로 띄운다.
  static Future<void> show(
    BuildContext context, {
    required String cellId,
    BoardCell? cell,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RadiusTokens.xl),
        ),
      ),
      builder: (context) => BoardCellDetail(cellId: cellId, cell: cell),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = contentDataOf(ref.watch(teamsProvider));
    final stadiums = contentDataOf(ref.watch(stadiumsProvider));
    final teamId = boardCellTeamId(cellId);
    final stadiumId = boardCellStadiumId(cellId);
    final stadiumName = stadiums?.byId(stadiumId)?.name ?? stadiumId;
    final teamName = teams?.byId(teamId)?.name ?? teamId;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SpaceTokens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stadiumName,
              style: TextTokens.onSurface(context, TextTokens.title),
            ),
            const SizedBox(height: SpaceTokens.xs),
            Text(
              _subtitle(teamName),
              style: TextTokens.onSurfaceMuted(context, TextTokens.supporting),
            ),
            const SizedBox(height: SpaceTokens.md),
            Flexible(child: _stamps(context, ref)),
          ],
        ),
      ),
    );
  }

  /// 홈팀과 등급·개수 한 줄.
  String _subtitle(String teamName) {
    final cell = this.cell;
    if (cell == null) return teamName;
    final tier = BadgeTierTokens.byTier[cell.tier]!;
    return '$teamName · ${tier.label} · 도장 ${cell.count}개';
  }

  Widget _stamps(BuildContext context, WidgetRef ref) {
    final material = Theme.of(context);
    final muted =
        material.extension<AppVisualTheme>()?.textSecondary ??
        material.colorScheme.onSurfaceVariant;
    // 빈 칸 — 요약이 이미 답했으므로 질의하지 않는다 (클래스 문서 참조).
    if (cell == null) {
      return const EmptyStateNotice(title: emptyTitle, message: emptyMessage);
    }

    final stampsAsync = ref.watch(boardCellStampsProvider(cellId));
    if (stampsAsync.hasError) {
      return ContentFallback(
        loading: false,
        title: loadFailureTitle,
        onRetry: () => ref.invalidate(boardCellStampsProvider(cellId)),
      );
    }
    final stamps = stampsAsync.value;
    if (stamps == null) return const ContentFallback(loading: true);

    // 최신 경기가 위 — 목록은 저장소가 이미 그 순서로 돌려준다.
    return ListView(
      shrinkWrap: true,
      children: [
        for (final stamp in stamps)
          Padding(
            key: ValueKey('stamp-${stamp.documentId}'),
            padding: const EdgeInsets.symmetric(vertical: SpaceTokens.xs),
            child: Row(
              children: [
                Icon(Icons.verified_rounded, color: muted),
                const SizedBox(width: SpaceTokens.sm),
                Text(
                  stamp.gameDate,
                  style: TextTokens.onSurface(context, TextTokens.body),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
