import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/tokens.dart';
import 'themed_surface.dart';

/// 팀 없음 기본 계열과 밝기 동작을 고르는, 저장 계층에 비결합된 설정 시트.
///
/// 현재 값과 콜백만 받는다. 실제 프로필 저장 및 앱 루트 테마 교체는 호출자가
/// 담당하므로 이 위젯은 최종 테마 상태를 소유하지 않는다.
class ThemeSettingsSheet extends StatelessWidget {
  const ThemeSettingsSheet({
    super.key,
    required this.selectedFamily,
    required this.brightnessMode,
    required this.onFamilyChanged,
    required this.onBrightnessModeChanged,
  });

  final AppThemeFamily selectedFamily;
  final ThemeMode brightnessMode;
  final ValueChanged<AppThemeFamily> onFamilyChanged;
  final ValueChanged<ThemeMode> onBrightnessModeChanged;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<AppVisualTheme>()!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SpaceTokens.lg),
        child: ThemedSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '화면 테마',
                style: TextTokens.title.copyWith(color: visual.textPrimary),
              ),
              const SizedBox(height: SpaceTokens.xs),
              Text(
                '응원팀이 없을 때의 색과 밝기를 골라 주세요.',
                style: TextTokens.bodyMuted.copyWith(
                  color: visual.textSecondary,
                ),
              ),
              const SizedBox(height: SpaceTokens.xl),
              Text(
                '기본 테마',
                style: TextTokens.label.copyWith(color: visual.textPrimary),
              ),
              const SizedBox(height: SpaceTokens.sm),
              SegmentedButton<AppThemeFamily>(
                segments: const [
                  ButtonSegment(value: AppThemeFamily.a, label: Text('A 계열')),
                  ButtonSegment(value: AppThemeFamily.b, label: Text('B 계열')),
                ],
                selected: {selectedFamily},
                onSelectionChanged: (selection) =>
                    onFamilyChanged(selection.single),
              ),
              const SizedBox(height: SpaceTokens.xl),
              Text(
                '밝기',
                style: TextTokens.label.copyWith(color: visual.textPrimary),
              ),
              const SizedBox(height: SpaceTokens.sm),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_rounded),
                    label: Text('자동'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded),
                    label: Text('밝음'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded),
                    label: Text('어두움'),
                  ),
                ],
                selected: {brightnessMode},
                onSelectionChanged: (selection) =>
                    onBrightnessModeChanged(selection.single),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
