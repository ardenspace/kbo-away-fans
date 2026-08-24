import 'package:flutter/material.dart';

import '../../design/tokens.dart';
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
  });

  /// 남은 원정 일정이 없을 때(시즌 종료)의 명시적 빈 상태.
  const DdayHeader.empty({super.key})
      : dDay = null,
        matchLabel = null;

  /// 경기까지 남은 일수. 0이면 오늘. null 이면 빈 상태.
  final int? dDay;

  /// 경기 정보 한 줄 (예: '8/30 (토) 사직 · vs 롯데'). 빈 상태에선 null.
  final String? matchLabel;

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
    final subtitle =
        matchLabel ?? '이번 시즌 원정 일정을 다 소화했어요. 다음 시즌에 만나요!';

    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: TypeTokens.fontFamily,
              // 빈 상태는 문장형이라 display 대신 title 크기.
              fontSize:
                  remaining == null ? TypeTokens.title : TypeTokens.display,
              fontWeight: TypeTokens.weightExtraBold,
              color: accent,
            ),
          ),
          const SizedBox(height: SpaceTokens.xs),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: TypeTokens.body,
              fontWeight: TypeTokens.weightMedium,
              color: ColorTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
