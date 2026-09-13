import 'package:flutter/material.dart';

import 'team_themes.dart';
import 'tokens.dart';

/// 응원팀이 없을 때 유지되는 기본 테마 계열.
///
/// 저장 모델의 문자열 값(`a`/`b`)과 이름을 맞추되 디자인 계층은 백엔드 모델을
/// import하지 않는다. 앱 루트의 상태 조립부가 저장값을 이 enum으로 옮긴다.
enum AppThemeFamily { a, b }

/// 앱 루트가 한 번 해석해 전체 widget tree에 공급하는 최종 시각 역할 값.
///
/// 화면은 응원팀·기본 계열·밝기를 다시 조합하지 않고 이 값만 읽는다. 시맨틱
/// 역할([success], [warning], [danger])은 강조 테마와 분리되어 어떤 팀/계열에서도
/// 같은 의미와 색을 유지한다.
@immutable
class AppVisualTheme extends ThemeExtension<AppVisualTheme> {
  const AppVisualTheme._({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.success,
    required this.warning,
    required this.danger,
  });

  /// 유효한 팀 id가 있으면 팀 색을, 없으면 A/B 계열의 밝기별 얼굴을 고른다.
  ///
  /// 알 수 없는 non-null id는 조용히 기본 테마로 떨어뜨리지 않는다. 사용자 문서와
  /// 팀 로스터가 어긋난 상태이므로 호출자가 경계에서 복구할 수 있게 예외로 알린다.
  factory AppVisualTheme.resolve({
    required String? favoriteTeamId,
    required AppThemeFamily defaultFamily,
    required Brightness brightness,
  }) {
    final team = favoriteTeamId == null
        ? null
        : TeamThemes.byId[favoriteTeamId];
    if (favoriteTeamId != null && team == null) {
      throw ArgumentError.value(
        favoriteTeamId,
        'favoriteTeamId',
        '등록된 KBO 팀 id여야 합니다',
      );
    }

    final isDark = brightness == Brightness.dark;
    final neutralBackground = isDark
        ? NeutralTokens.darkBackground
        : NeutralTokens.lightBackground;
    final surface = isDark
        ? NeutralTokens.darkSurface
        : NeutralTokens.lightSurface;
    final ink = isDark ? NeutralTokens.darkInk : NeutralTokens.lightInk;
    final muted = isDark ? NeutralTokens.darkMuted : NeutralTokens.lightMuted;
    final outline = isDark
        ? NeutralTokens.darkOutline
        : NeutralTokens.lightOutline;

    final defaultPrimary = defaultFamily == AppThemeFamily.a
        ? DefaultThemeTokens.aPrimary
        : DefaultThemeTokens.bPrimary;
    final defaultSecondary = defaultFamily == AppThemeFamily.a
        ? DefaultThemeTokens.aSecondary
        : DefaultThemeTokens.bSecondary;
    final defaultBackground = switch ((defaultFamily, brightness)) {
      (AppThemeFamily.a, Brightness.light) =>
        DefaultThemeTokens.aLightBackground,
      (AppThemeFamily.a, Brightness.dark) => DefaultThemeTokens.aDarkBackground,
      (AppThemeFamily.b, Brightness.light) =>
        DefaultThemeTokens.bLightBackground,
      (AppThemeFamily.b, Brightness.dark) => DefaultThemeTokens.bDarkBackground,
    };

    return AppVisualTheme._(
      brightness: brightness,
      background: team == null ? defaultBackground : neutralBackground,
      surface: surface,
      textPrimary: ink,
      textSecondary: muted,
      outline: outline,
      primary: team?.primary ?? defaultPrimary,
      onPrimary: team?.onPrimary ?? _onColor(defaultPrimary),
      secondary: team?.secondary ?? defaultSecondary,
      onSecondary: team?.onSecondary ?? _onColor(defaultSecondary),
      success: ColorTokens.success,
      warning: ColorTokens.warning,
      danger: ColorTokens.danger,
    );
  }

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color outline;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color success;
  final Color warning;
  final Color danger;

  /// 전역 배경의 큰 글자·아이콘에 쓰는 강조색 (최소 대비 3:1).
  ///
  /// 맑음·비 배경 모두에서 읽힐 때까지 primary를 textPrimary 쪽으로 조금씩
  /// 옮긴다. 팀 대표색 자체와 시맨틱 상태색은 바꾸지 않는다.
  Color get backgroundAccent {
    final rainBackground = Color.alphaBlend(
      ColorTokens.rainOverlay,
      background,
    );
    for (var step = 0; step <= 20; step++) {
      final candidate = Color.lerp(primary, textPrimary, step / 20)!;
      if (_contrastRatio(candidate, background) >= 3 &&
          _contrastRatio(candidate, rainBackground) >= 3) {
        return candidate;
      }
    }
    return textPrimary;
  }

  /// 이 최종 역할 값과 정확히 같은 색을 쓰는 Material 테마를 만든다.
  ThemeData toThemeData() {
    final navigationSelected = _navigationAccent(
      surface: surface,
      primary: primary,
      secondary: secondary,
      fallback: textPrimary,
    );
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          secondary: secondary,
          onSecondary: onSecondary,
          surface: surface,
          surfaceDim: surface,
          surfaceBright: surface,
          surfaceContainerLowest: surface,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: surface,
          surfaceContainerHighest: surface,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          error: danger,
          onError: _onColor(danger),
          outline: outline,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surface,
      dividerColor: outline,
      fontFamily: TypeTokens.fontFamily,
      extensions: <ThemeExtension<dynamic>>[this],
    );

    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: background,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: surface,
        selectedItemColor: navigationSelected,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: TextTokens.caption.copyWith(
          color: navigationSelected,
        ),
        unselectedLabelStyle: TextTokens.caption.copyWith(color: textSecondary),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: surface,
        surfaceTintColor: Colors.transparent,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
    );
  }

  @override
  AppVisualTheme copyWith() => this;

  @override
  AppVisualTheme lerp(covariant AppVisualTheme? other, double t) {
    if (other == null || identical(this, other)) return this;
    return AppVisualTheme._(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t)!,
      // 의미색은 테마 전환 중에도 변하지 않는다.
      success: success,
      warning: warning,
      danger: danger,
    );
  }
}

/// 하단 탐색 강조색은 팀색을 우선하되 실제 surface에서 읽히는 역할만 쓴다.
Color _navigationAccent({
  required Color surface,
  required Color primary,
  required Color secondary,
  required Color fallback,
}) {
  if (_contrastRatio(primary, surface) >= 3) return primary;
  if (_contrastRatio(secondary, surface) >= 3) return secondary;
  return fallback;
}

Color _onColor(Color background) {
  const dark = NeutralTokens.lightInk;
  const light = NeutralTokens.darkInk;
  return _contrastRatio(background, dark) >= _contrastRatio(background, light)
      ? dark
      : light;
}

double _contrastRatio(Color a, Color b) {
  final lighter = a.computeLuminance() >= b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
