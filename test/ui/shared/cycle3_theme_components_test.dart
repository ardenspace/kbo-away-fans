import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/app_theme.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/ui/shared/journey_status_visual.dart';
import 'package:kbo_away_fans/ui/shared/journey_ticket.dart';
import 'package:kbo_away_fans/ui/shared/theme_settings_sheet.dart';
import 'package:kbo_away_fans/ui/shared/themed_surface.dart';

void main() {
  final visual = AppVisualTheme.resolve(
    favoriteTeamId: null,
    defaultFamily: AppThemeFamily.a,
    brightness: Brightness.light,
  );

  Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
    theme: visual.toThemeData(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: child),
    ),
  );

  testWidgets('ThemedSurface는 AppVisualTheme 표면과 선택적 tint를 쓴다', (tester) async {
    await tester.pumpWidget(host(const ThemedSurface(child: Text('plain'))));
    var decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(ThemedSurface),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.color, visual.surface);

    await tester.pumpWidget(
      host(const ThemedSurface(tinted: true, child: Text('tinted'))),
    );
    decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(ThemedSurface),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(
      decoration.color,
      Color.alphaBlend(
        visual.primary.withValues(alpha: JourneyTokens.surfaceTintOpacity),
        visual.surface,
      ),
    );
  });

  testWidgets('TextTokens 표면 글자는 AppVisualTheme의 현재 전경 역할을 쓴다', (tester) async {
    final dark = AppVisualTheme.resolve(
      favoriteTeamId: null,
      defaultFamily: AppThemeFamily.b,
      brightness: Brightness.dark,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: dark.toThemeData(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                Text(
                  '기본 전경',
                  style: TextTokens.onSurface(context, TextTokens.title),
                ),
                Text(
                  '보조 전경',
                  style: TextTokens.onSurfaceMuted(
                    context,
                    TextTokens.bodyMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('기본 전경')).style!.color,
      dark.textPrimary,
    );
    expect(
      tester.widget<Text>(find.text('보조 전경')).style!.color,
      dark.textSecondary,
    );
  });

  testWidgets('JourneyTicket 끝점은 70/30 혼합이고 취소는 danger가 우선한다', (tester) async {
    await tester.pumpWidget(host(const JourneyTicket(child: Text('game'))));
    var decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(JourneyTicket),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    final endAccent = Color.lerp(
      visual.primary,
      visual.secondary,
      JourneyTokens.ticketSecondaryBlend,
    );
    expect(
      decoration.gradient!.colors.last,
      Color.alphaBlend(
        endAccent!.withValues(alpha: JourneyTokens.surfaceTintOpacity),
        visual.surface,
      ),
    );

    await tester.pumpWidget(
      host(const JourneyTicket(cancelled: true, child: Text('rain'))),
    );
    decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(JourneyTicket),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.border, Border.all(color: visual.danger));
    expect(decoration.gradient!.colors.first, decoration.gradient!.colors.last);
  });

  testWidgets('JourneyStatusVisual은 상태별 의미색을 쓰고 reduced motion은 정적이다', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const JourneyStatusVisual(status: JourneyStatus.live),
        disableAnimations: true,
      ),
    );
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.sensors_rounded)).color,
      visual.success,
    );

    await tester.pumpWidget(
      host(
        const JourneyStatusVisual(status: JourneyStatus.cancelled),
        disableAnimations: true,
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.cloud_off_rounded)).color,
      visual.danger,
    );
  });

  testWidgets('ThemeSettingsSheet는 상태를 소유하지 않고 선택을 콜백으로 전달한다', (tester) async {
    AppThemeFamily? family;
    ThemeMode? mode;
    await tester.pumpWidget(
      host(
        ThemeSettingsSheet(
          selectedFamily: AppThemeFamily.a,
          brightnessMode: ThemeMode.system,
          onFamilyChanged: (value) => family = value,
          onBrightnessModeChanged: (value) => mode = value,
        ),
      ),
    );

    await tester.tap(find.text('B 계열'));
    await tester.pump();
    await tester.tap(find.text('어두움'));
    await tester.pump();
    expect(family, AppThemeFamily.b);
    expect(mode, ThemeMode.dark);
  });
}
