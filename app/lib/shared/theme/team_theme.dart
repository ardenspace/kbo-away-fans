import 'package:flutter/material.dart';

import 'team_colors.dart';

/// 팀 색 → Material 3 ThemeData.
///
/// seed = primary (M3 가 조화로운 팔레트 자동 생성), secondary 는 브랜드 보조색으로 덮어쓴다.
/// `copyWith` 로 secondary 를 주입해 구버전 `ColorScheme.fromSeed` override 인자 의존을 피한다.
ThemeData buildTeamTheme(TeamColors colors) {
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.primary,
  ).copyWith(secondary: colors.secondary);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
  );
}
