import 'package:flutter/material.dart';

import '../../design/team_themes.dart';
import '../../design/tokens.dart';

/// 팀을 나타내는 작은 표시 — 약칭 글자 + 대표색 몸통 + 보조색 탭.
///
/// 구단 엠블럼과 마스코트는 저작권·상표권이 걸려 쓸 수 없으므로, 팀을
/// 가리키는 일은 약칭 글자가 맡고 색은 그것을 거든다. 색만으로는 열 팀을
/// 가를 수 없다: 대표색이 SSG·KIA·LG 는 빨강 계열로, 두산·롯데·삼성·NC 는
/// 남색 계열로 몰려 있다. 그래서 왼쪽에 보조색 탭을 세워 같은 계열끼리도
/// 갈라 놓되, 최종적인 식별은 언제나 글자가 책임진다.
///
/// 색은 [TeamTheme] 에서만 오므로 콘텐츠 계층과 묶이지 않는다. 문장 안이나
/// 좁은 자리에 끼울 때는 [compact] 를 켠다.
class TeamBadge extends StatelessWidget {
  const TeamBadge({
    super.key,
    required this.shortName,
    required this.theme,
    this.compact = false,
  });

  /// 팀 약칭 (`teams.json` 의 shortName — 예: 'LG', '두산').
  final String shortName;

  /// 대표색·보조색을 제공하는 팀 테마.
  final TeamTheme theme;

  /// 글자와 여백을 줄인 판본. 문장 안에 끼울 때 쓴다.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // 보조색을 바탕에 깔고 그 위에 대표색 몸통을 왼쪽만 비켜 얹으면,
    // 비어 남은 왼쪽 띠가 보조색 탭이 된다.
    final tabWidth = compact ? SpaceTokens.xs : SpaceTokens.sm;

    return ClipRRect(
      borderRadius: BorderRadius.circular(RadiusTokens.sm),
      child: Container(
        color: theme.secondary,
        padding: EdgeInsets.only(left: tabWidth),
        child: Container(
          color: theme.primary,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? SpaceTokens.sm : SpaceTokens.md,
            vertical: compact ? SpaceTokens.xs : SpaceTokens.sm,
          ),
          child: Text(
            shortName,
            style: TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: compact ? TypeTokens.caption : TypeTokens.label,
              fontWeight: TypeTokens.weightExtraBold,
              color: theme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
