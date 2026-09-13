import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/design/tokens.dart';

void main() {
  group('AppVisualTheme 기본 계열 얼굴', () {
    test('팀 없음 A 계열은 A1/A4 배경과 같은 강조색을 쓴다', () {
      final light = AppVisualTheme.resolve(
        favoriteTeamId: null,
        defaultFamily: AppThemeFamily.a,
        brightness: Brightness.light,
      );
      final dark = AppVisualTheme.resolve(
        favoriteTeamId: null,
        defaultFamily: AppThemeFamily.a,
        brightness: Brightness.dark,
      );

      expect(light.background, DefaultThemeTokens.aLightBackground);
      expect(dark.background, DefaultThemeTokens.aDarkBackground);
      expect(light.primary, DefaultThemeTokens.aPrimary);
      expect(dark.primary, DefaultThemeTokens.aPrimary);
      expect(light.secondary, DefaultThemeTokens.aSecondary);
      expect(dark.secondary, DefaultThemeTokens.aSecondary);
      expect(light.onPrimary, NeutralTokens.lightInk);
      expect(dark.onSecondary, NeutralTokens.lightInk);
      expect(light.surface, NeutralTokens.lightSurface);
      expect(dark.surface, NeutralTokens.darkSurface);
    });

    test('팀 없음 B 계열은 B1/B4 배경과 같은 강조색을 쓴다', () {
      final light = AppVisualTheme.resolve(
        favoriteTeamId: null,
        defaultFamily: AppThemeFamily.b,
        brightness: Brightness.light,
      );
      final dark = AppVisualTheme.resolve(
        favoriteTeamId: null,
        defaultFamily: AppThemeFamily.b,
        brightness: Brightness.dark,
      );

      expect(light.background, DefaultThemeTokens.bLightBackground);
      expect(dark.background, DefaultThemeTokens.bDarkBackground);
      expect(light.primary, DefaultThemeTokens.bPrimary);
      expect(dark.primary, DefaultThemeTokens.bPrimary);
      expect(light.secondary, DefaultThemeTokens.bSecondary);
      expect(dark.secondary, DefaultThemeTokens.bSecondary);
      expect(light.onPrimary, NeutralTokens.darkInk);
      expect(dark.onSecondary, NeutralTokens.lightInk);
    });
  });

  group('AppVisualTheme 우선순위', () {
    test('응원팀이 있으면 A/B와 무관하게 팀 색과 공통 뉴트럴을 쓴다', () {
      final a = AppVisualTheme.resolve(
        favoriteTeamId: 'lotte',
        defaultFamily: AppThemeFamily.a,
        brightness: Brightness.dark,
      );
      final b = AppVisualTheme.resolve(
        favoriteTeamId: 'lotte',
        defaultFamily: AppThemeFamily.b,
        brightness: Brightness.dark,
      );

      for (final theme in [a, b]) {
        expect(theme.primary, TeamThemes.lotte.primary);
        expect(theme.onPrimary, TeamThemes.lotte.onPrimary);
        expect(theme.secondary, TeamThemes.lotte.secondary);
        expect(theme.onSecondary, TeamThemes.lotte.onSecondary);
        expect(theme.background, NeutralTokens.darkBackground);
      }
    });

    test('알 수 없는 non-null 팀 id를 기본 계열로 가장하지 않는다', () {
      expect(
        () => AppVisualTheme.resolve(
          favoriteTeamId: 'unknown',
          defaultFamily: AppThemeFamily.a,
          brightness: Brightness.light,
        ),
        throwsArgumentError,
      );
    });

    test('시맨틱 색은 모든 팀·계열·밝기에서 고정된다', () {
      final themes = <AppVisualTheme>[
        for (final brightness in Brightness.values) ...[
          AppVisualTheme.resolve(
            favoriteTeamId: null,
            defaultFamily: AppThemeFamily.a,
            brightness: brightness,
          ),
          AppVisualTheme.resolve(
            favoriteTeamId: null,
            defaultFamily: AppThemeFamily.b,
            brightness: brightness,
          ),
          AppVisualTheme.resolve(
            favoriteTeamId: 'hanwha',
            defaultFamily: AppThemeFamily.a,
            brightness: brightness,
          ),
        ],
      ];

      for (final theme in themes) {
        expect(theme.success, ColorTokens.success);
        expect(theme.warning, ColorTokens.warning);
        expect(theme.danger, ColorTokens.danger);
      }
    });
  });

  test('ThemeData가 최종 역할과 같은 색을 쓰고 AppVisualTheme을 품는다', () {
    final visual = AppVisualTheme.resolve(
      favoriteTeamId: 'nc',
      defaultFamily: AppThemeFamily.b,
      brightness: Brightness.light,
    );
    final material = visual.toThemeData();

    expect(material.brightness, visual.brightness);
    expect(material.scaffoldBackgroundColor, visual.background);
    expect(material.cardColor, visual.surface);
    expect(material.colorScheme.primary, visual.primary);
    expect(material.colorScheme.onPrimary, visual.onPrimary);
    expect(material.colorScheme.secondary, visual.secondary);
    expect(material.colorScheme.onSecondary, visual.onSecondary);
    expect(material.colorScheme.error, visual.danger);
    expect(material.colorScheme.outline, visual.outline);
    expect(material.extension<AppVisualTheme>(), same(visual));
  });

  test('하단 탐색 선택색은 모든 팀·기본 계열과 밝기에서 surface와 구별된다', () {
    final themes = <AppVisualTheme>[
      for (final brightness in Brightness.values) ...[
        for (final family in AppThemeFamily.values)
          AppVisualTheme.resolve(
            favoriteTeamId: null,
            defaultFamily: family,
            brightness: brightness,
          ),
        for (final teamId in TeamThemes.byId.keys)
          AppVisualTheme.resolve(
            favoriteTeamId: teamId,
            defaultFamily: AppThemeFamily.a,
            brightness: brightness,
          ),
      ],
    ];

    for (final visual in themes) {
      final navigation = visual.toThemeData().bottomNavigationBarTheme;
      final selected = navigation.selectedItemColor!;
      expect(_contrastRatio(selected, visual.surface), greaterThanOrEqualTo(3));
      expect(selected, isNot(navigation.unselectedItemColor));
    }

    final ktDark = AppVisualTheme.resolve(
      favoriteTeamId: 'kt',
      defaultFamily: AppThemeFamily.a,
      brightness: Brightness.dark,
    );
    expect(
      ktDark.toThemeData().bottomNavigationBarTheme.selectedItemColor,
      ktDark.secondary,
    );
  });

  test('테마 보간 중에도 시맨틱 색은 변하지 않는다', () {
    final from = AppVisualTheme.resolve(
      favoriteTeamId: null,
      defaultFamily: AppThemeFamily.a,
      brightness: Brightness.light,
    );
    final to = AppVisualTheme.resolve(
      favoriteTeamId: 'lg',
      defaultFamily: AppThemeFamily.b,
      brightness: Brightness.dark,
    );
    final middle = from.lerp(to, 0.5);

    expect(middle.primary, Color.lerp(from.primary, to.primary, 0.5));
    expect(middle.success, ColorTokens.success);
    expect(middle.warning, ColorTokens.warning);
    expect(middle.danger, ColorTokens.danger);
  });
}

double _contrastRatio(Color a, Color b) {
  final lighter = a.computeLuminance() >= b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
