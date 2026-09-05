/// 배지 판 칸의 짧은 라벨 (step 4.3) — [badges_tab_screen.dart]·[stamp_reveal.dart]
/// 둘이 함께 쓴다.
///
/// **왜 별도 파일인가.** `stamp_reveal.dart` 가 이 함수 하나 때문에
/// `badges_tab_screen.dart` 를 import 하고 있었는데, step 4.5 가 배지 탭에
/// `stadium_visit.dart`(→ `stamp_reveal.dart` → 옛 자리)를 잇는 순간 그 방향이
/// 돌아 라이브러리 순환(`badges_tab_screen.dart` → `stadium_visit.dart` →
/// `stamp_reveal.dart` → `badges_tab_screen.dart`)이 생긴다. 함수를 두 파일
/// 아래의 잎(leaf) 자리로 옮기면 그 순환이 애초에 생기지 않는다 — 동작은
/// 한 글자도 바뀌지 않는다.
library;

import '../../backend/user_data.dart';
import '../../content/models.dart';

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
