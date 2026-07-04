/// 스탬프북 렌더 조각 — 데이터 provider + 10칸 그리드 위젯 (R6·R7).
///
/// 렌더 소스는 오직 데이터 계층([stampbookProvider])이 반환한 목록이다 — 별도
/// 캐시·기본값 없음 (R6). 조회 실패는 빈 "0/10" 이 아니라 오류+재시도로 그린다.
library;

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/theme/team_colors.dart';
import 'stamp_models.dart';
import 'stamp_repository.dart';
import 'stadium_repository.dart';

part 'stampbook_widgets.g.dart';

/// 한 칸(=한 팀 구장)의 방문 여부.
class StampCellData {
  const StampCellData({required this.stadium, required this.visited});

  final StampStadium stadium;
  final bool visited;
}

/// 스탬프북 전체 상태 — 칸 목록 + 수집률.
class StampbookView {
  const StampbookView(this.cells);

  final List<StampCellData> cells;

  int get visitedCount => cells.where((c) => c.visited).length;

  int get total => cells.length;

  /// "N/전체" 수집률 텍스트 (R7).
  String get rateText => '$visitedCount/$total';
}

/// 스탬프북 데이터 — 구장 목록 + 내 스탬프를 합쳐 칸별 방문 여부로 만든다.
///
/// 클라우드가 진실원천 (R6): 두 원격 조회 중 하나라도 실패하면 AsyncError 로
/// 전파되어 화면이 오류+재시도를 그린다. 로컬 폴백 없음.
@riverpod
Future<StampbookView> stampbook(Ref ref) async {
  final stadiums = await ref.watch(stadiumRepositoryProvider).listStadiums();
  final stamps = await ref.watch(stampRepositoryProvider).myStamps();
  final stampedIds = stamps.map((s) => s.stadiumId).toSet();
  return StampbookView([
    for (final s in stadiums)
      StampCellData(stadium: s, visited: stampedIds.contains(s.id)),
  ]);
}

/// 칸 Key — 방문/미방문 및 팀별 구분에 쓴다 (R7 위젯 속성 검증 지점).
Key stampCellKey(String teamAbbr) => ValueKey('stamp-cell-$teamAbbr');

/// 한 칸 도장. 방문이면 팀 컬러 채움, 미방문이면 회색 아웃라인 (R7).
class StampCellTile extends StatelessWidget {
  StampCellTile({required this.teamAbbr, required this.visited})
      : super(key: stampCellKey(teamAbbr));

  final String teamAbbr;
  final bool visited;

  /// 미방문 칸 색 — 회색 아웃라인.
  static const Color unvisitedColor = Color(0xFF9E9E9E);

  /// 도장 색 — 방문이면 그 칸의 팀 컬러, 미방문이면 회색.
  Color get stampColor => visited
      ? (kTeamColors[teamAbbr]?.primary ?? kNeutralColors.primary)
      : unvisitedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: visited ? stampColor : Colors.transparent,
            border: visited ? null : Border.all(color: unvisitedColor, width: 2),
          ),
          child: visited
              ? const Icon(Icons.check, color: Colors.white, size: 24)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          teamAbbr,
          style: TextStyle(
            fontSize: 12,
            color: visited ? stampColor : unvisitedColor,
            fontWeight: visited ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// 팀 단위 10칸 그리드 + 상단 수집률 (R7).
class StampbookGrid extends StatelessWidget {
  const StampbookGrid({super.key, required this.view});

  final StampbookView view;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            view.rateText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 5,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final cell in view.cells)
                StampCellTile(
                  teamAbbr: cell.stadium.teamAbbr,
                  visited: cell.visited,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 조회 실패 상태 — 빈 "0/10" 대신 오류 안내 + 재시도 (R6).
class StampbookError extends StatelessWidget {
  const StampbookError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('스탬프북을 불러오지 못했어요'),
          const SizedBox(height: 12),
          StampbookRetryButton(onRetry: onRetry),
        ],
      ),
    );
  }
}

/// 재시도 버튼 — 데이터 provider 를 다시 조회한다.
class StampbookRetryButton extends StatelessWidget {
  const StampbookRetryButton({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onRetry,
      child: const Text('다시 시도'),
    );
  }
}
