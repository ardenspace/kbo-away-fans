import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import 'team_theme_scope.dart';

/// 다음 원정 경기 D-day와 경기 정보 헤더 (홈 화면의 기본 얼굴).
class DdayHeader extends StatelessWidget {
  const DdayHeader({
    super.key,
    required this.dDay,
    required this.matchLabel,
  });

  /// 경기까지 남은 일수. 0이면 오늘.
  final int dDay;

  /// 경기 정보 한 줄 (예: '8/30 (토) 사직 · vs 롯데').
  final String matchLabel;

  @override
  Widget build(BuildContext context) {
    final team = TeamThemeScope.maybeOf(context);
    final accent = team?.primary ?? ColorTokens.textPrimary;

    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dDay <= 0 ? 'D-DAY' : 'D-$dDay',
            style: TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: TypeTokens.display,
              fontWeight: TypeTokens.weightExtraBold,
              color: accent,
            ),
          ),
          const SizedBox(height: SpaceTokens.xs),
          Text(
            matchLabel,
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
