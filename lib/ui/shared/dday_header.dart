import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import 'team_badge.dart';
import 'team_theme_scope.dart';

/// 다음 원정 경기 D-day와 경기 정보 헤더 (홈 화면의 기본 얼굴).
///
/// 세 상태를 렌더한다:
/// - 오늘 경기 ([dDay] <= 0): "오늘"
/// - 미래 경기 ([dDay] >= 1): "D-n"
/// - 남은 일정 없음 ([DdayHeader.empty]): 시즌 종료 빈 상태
class DdayHeader extends StatelessWidget {
  const DdayHeader({
    super.key,
    required int this.dDay,
    required String this.matchLabel,
    this.opponentShortName,
  });

  /// 남은 원정 일정이 없을 때(시즌 종료)의 명시적 빈 상태.
  const DdayHeader.empty({super.key})
    : dDay = null,
      matchLabel = null,
      opponentShortName = null;

  /// 경기까지 남은 일수. 0이면 오늘. null 이면 빈 상태.
  final int? dDay;

  /// 경기 정보 한 줄 (예: '8/30 (토) 사직야구장 · 18:30'). 빈 상태에선 null.
  ///
  /// 상대팀은 여기 넣지 않고 [opponentShortName] 으로 넘겨 배지로 보여 준다.
  final String? matchLabel;

  /// 상대팀 약칭. 주면 경기 정보 앞에 [TeamBadge] 를 세운다.
  ///
  /// 배지 색은 따로 받지 않고 상위 [TeamThemeScope] 에서 온다. 이 헤더를
  /// 감싸는 스코프가 곧 그 경기의 홈팀, 즉 원정 팬이 만날 상대팀이기 때문이다.
  /// 스코프가 없으면 색을 정할 수 없으므로 배지 없이 문구만 렌더한다.
  final String? opponentShortName;

  @override
  Widget build(BuildContext context) {
    final team = TeamThemeScope.maybeOf(context);
    final accent = team?.primary ?? ColorTokens.textPrimary;
    final remaining = dDay;

    final title = remaining == null
        ? '남은 원정 경기가 없어요'
        : remaining <= 0
        ? '오늘'
        : 'D-$remaining';
    final subtitle = matchLabel ?? '이번 시즌 원정 일정을 다 소화했어요. 다음 시즌에 만나요!';

    const subtitleStyle = TextTokens.bodyMuted;
    final subtitleText = Text(subtitle, style: subtitleStyle);

    final opponent = opponentShortName;
    final subtitleLine = opponent == null || team == null
        ? subtitleText
        : Row(
            children: [
              TeamBadge(shortName: opponent, theme: team, compact: true),
              const SizedBox(width: SpaceTokens.sm),
              Expanded(child: subtitleText),
            ],
          );

    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            // 빈 상태는 문장형이라 display 대신 title 크기.
            style: (remaining == null ? TextTokens.title : TextTokens.display)
                .copyWith(color: accent),
          ),
          const SizedBox(height: SpaceTokens.xs),
          subtitleLine,
        ],
      ),
    );
  }
}
