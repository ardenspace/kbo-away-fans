import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/shared/theme/team_colors.dart';
import 'package:kbo_away_fans/shared/theme/team_theme_provider.dart';

void main() {
  test('미선택이면 중립 테마(중립 seed 기반)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final theme = container.read(teamThemeProvider);
    final neutral = ColorScheme.fromSeed(seedColor: kNeutralColors.primary);
    expect(theme.colorScheme.primary, neutral.primary);
  });

  test('팀 선택하면 그 팀 색으로 테마 전환', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(currentTeamProvider.notifier).select('HH'); // 한화
    final theme = container.read(teamThemeProvider);
    final hanwha = ColorScheme.fromSeed(seedColor: kTeamColors['HH']!.primary);

    expect(theme.colorScheme.primary, hanwha.primary);
    expect(theme.colorScheme.secondary, kTeamColors['HH']!.secondary);
  });

  test('다른 팀으로 바꾸면 테마도 따라 바뀐다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(currentTeamProvider.notifier).select('HH');
    final hanwhaPrimary = container.read(teamThemeProvider).colorScheme.primary;

    container.read(currentTeamProvider.notifier).select('LG');
    final lgPrimary = container.read(teamThemeProvider).colorScheme.primary;

    expect(hanwhaPrimary, isNot(lgPrimary));
  });

  test('알 수 없는 abbr 은 중립으로 폴백', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(currentTeamProvider.notifier).select('ZZ');
    final theme = container.read(teamThemeProvider);
    final neutral = ColorScheme.fromSeed(seedColor: kNeutralColors.primary);
    expect(theme.colorScheme.primary, neutral.primary);
  });
}
