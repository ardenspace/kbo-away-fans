/// 배지 탭 (step 4.3) — 10칸 판과 칸 상세로 들어가는 입구.
///
/// `lib/features/home/main_tabs_root.dart` 의 배지 탭 자리를 채운다.
///
/// **이 화면이 서버에서 읽는 것은 사용자 문서 하나뿐이다.** 칸의 도장 개수와
/// 등급은 그 문서의 칸별 요약([UserProfile.board])에 이미 들어 있고, 개별
/// 도장 문서는 사람이 칸을 열 때 [BoardCellDetail] 이 비로소 읽는다 —
/// `.wellbegun/decisions.md` 의 판 읽기 패턴 `[L]` 결정이다. 그 결정의 까닭은
/// 성능 취향이 아니라 **무료 할당량**이다: 판을 열 때마다 도장을 전부 읽으면
/// 읽기 수가 사용자 수 × 도장 수로 늘어 오래 쓴 사람일수록 비싸지고, 일 5만
/// 읽기 기준 약 800명에서 한도에 닿는다(요약 방식은 약 2만 5천명). 그래서 이
/// 파일에는 도장 목록을 구독하는 줄이 없다 — 그것이 이 단계의 성질이고
/// `test/features/badges/badge_board_test.dart` 가 가짜 백엔드의 **문서 읽기
/// 수**로 잰다.
///
/// **탭 뿌리가 provider 를 직접 구독한다** — `_HomeTab`·[LikesTabScreen] 이
/// 세운 규칙과 같다. `MainTabScaffold` 의 탭별 Navigator 는 route 를 한 번만
/// 만들기 때문에, 판을 생성자 인자로 받으면 그 값이 route 가 만들어진 순간에
/// 얼어붙어 새 도장이 찍혀도 판이 갱신되지 않는다.
///
/// 구독하는 [userProfileProvider] 는 마이페이지 탭도 보는 **같은** provider 라,
/// 이 탭이 생겼다고 읽기가 늘지 않는다(구독은 한 자리, 스냅샷도 한 벌).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/user_data.dart';
import '../../content/content_providers.dart';
import '../../content/models.dart';
import '../../design/tokens.dart';
import '../../ui/shared/content_fallback.dart';
import '../../ui/shared/stamp_board.dart';
import 'board_cell_detail.dart';

class BadgesTabScreen extends ConsumerWidget {
  const BadgesTabScreen({super.key});

  /// 사용자 문서를 못 읽은 자리의 안내 제목 — "도장이 없다"와 다른 얼굴이다.
  static const String loadFailureTitle = '배지 판을 불러오지 못했어요';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(title: const Text('배지')),
      body: _body(context, ref),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    // "못 읽었다"를 "도장이 하나도 없다"로 접지 않는다 — 빈 판은 아직 아무 데도
    // 못 간 사람의 얼굴이라, 서버를 못 읽은 사람에게 그것을 보여주면 모아 둔
    // 도장이 사라진 것으로 읽힌다(좋아요 탭이 같은 자리에서 세운 구분이다).
    // 이 검사가 로딩 검사보다 앞에 있는 것도 그 화면과 같은 까닭이다: 사람이
    // 재시도를 누른 동안(`hasError` 와 `isLoading` 이 함께 참인 창)에도 실패
    // 얼굴을 그대로 유지해 화면이 한 번 더 깜빡이지 않게 한다.
    if (profileAsync.hasError) {
      return ContentFallback(
        loading: false,
        title: loadFailureTitle,
        onRetry: () => ref.invalidate(userProfileProvider),
      );
    }
    if (!profileAsync.hasValue) {
      return const ContentFallback(loading: true);
    }

    // 문서가 없는 계정(온보딩 전)은 도장도 없다 — 빈 판이 정확한 얼굴이다.
    final board = profileAsync.value?.board ?? const <String, BoardCell>{};
    final teams = contentDataOf(ref.watch(teamsProvider));

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: SpaceTokens.xxl),
      child: StampBoard(
        board: board,
        labels: boardCellLabels(teams),
        onCellTap: (cellId) => BoardCellDetail.show(
          context,
          cellId: cellId,
          cell: board[cellId],
        ),
      ),
    );
  }
}

/// 칸 id → 칸에 적을 팀 약칭.
///
/// 콘텐츠를 못 얻은 실행에서는 그 칸의 글자가 빠질 뿐 판은 그대로 열린다 —
/// 칸의 정체는 팀 색과 자리가 이미 말하고, 이름 하나 때문에 판 전체를 막을
/// 값어치가 없다. 잠실 두 칸이 갈리는 것도 여기서 온다(같은 구장, 다른 팀).
Map<String, String> boardCellLabels(TeamsDocument? teams) {
  if (teams == null) return const {};
  return {
    for (final cellId in kBoardCellIds)
      if (teams.byId(boardCellTeamId(cellId))?.shortName case final String name)
        cellId: name,
  };
}
