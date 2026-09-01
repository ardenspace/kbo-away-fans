import 'package:flutter/material.dart';

import '../../backend/user_data.dart';
import '../../design/team_themes.dart';
import '../../design/tokens.dart';
import 'stamp_badge.dart';

/// 10칸 배지 판 — 빈 칸까지 전부 렌더한다.
///
/// 판이 읽는 것은 사용자 문서의 **칸별 요약**([board]) 하나뿐이다. 도장 문서를
/// 세지 않으므로 읽기 수가 도장 개수에 비례하지 않는다 (칸 상세는 칸을 열 때만).
///
/// 칸 목록은 [kBoardCellIds] 가 정하고 이 위젯은 그것을 그대로 훑는다 — 부르는
/// 쪽이 칸 목록을 넘기면 화면마다 다른 판이 그려질 수 있고, 빈 칸을 빠뜨린
/// 판(= 이미 찍은 칸만 있는 판)이 조용히 만들어진다. 요약에 키가 없는 칸이
/// 곧 빈 칸이라는 것도 이 한 자리에서만 해석한다.
///
/// 배치는 격자다 — 판이 "무엇을 채우면 되는지" 보여주는 물건이라 칸이 고르게
/// 늘어서는 편이 남은 칸을 세기 쉽고, 구장의 지리적 위치를 흉내 낸 배치는
/// 잠실 두 칸이 같은 자리에 겹쳐 규칙이 깨진다.
class StampBoard extends StatelessWidget {
  const StampBoard({
    super.key,
    this.board = const {},
    this.labels = const {},
    this.onCellTap,
    this.cellSize = BadgeTokens.cellSize,
  });

  /// 칸별 요약 — `users/{uid}.board` 그대로. 키가 없는 칸은 빈 칸이다.
  final Map<String, BoardCell> board;

  /// 칸 id → 칸에 적을 짧은 글자 (팀 약칭). 없는 칸은 글자 없이 색만 그린다.
  final Map<String, String> labels;

  /// 칸을 눌렀을 때 그 칸의 id 를 받는 경로 (칸 상세).
  final void Function(String cellId)? onCellTap;

  /// 칸 지름 — 좁은 자리(홈 요약 등)에서 줄여 쓴다.
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(BadgeTokens.boardPadding),
      child: Wrap(
        spacing: BadgeTokens.cellGap,
        runSpacing: BadgeTokens.cellGap,
        alignment: WrapAlignment.center,
        children: [
          for (final cellId in kBoardCellIds)
            StampBadge(
              theme: TeamThemes.byId[boardCellTeamId(cellId)]!,
              stamps: board[cellId]?.count ?? 0,
              label: labels[cellId],
              size: cellSize,
              onTap: onCellTap == null ? null : () => onCellTap!(cellId),
            ),
        ],
      ),
    );
  }
}
