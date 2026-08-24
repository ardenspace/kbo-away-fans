import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 날씨 연동 배경 연출 (홈·추천 화면 배경).
///
/// 골격 단계: 비 오는 날 배경색 오버레이 전환만 구현한다.
/// 빗줄기 애니메이션 → 플랜B 유도 연출은 이후 step에서 내부만 확장한다.
class WeatherBackdrop extends StatelessWidget {
  const WeatherBackdrop({
    super.key,
    required this.raining,
    required this.child,
  });

  /// 비 연출 활성 여부.
  final bool raining;

  /// 배경 위에 올라가는 화면 콘텐츠.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final background = raining
        ? Color.alphaBlend(ColorTokens.rainOverlay, ColorTokens.background)
        : ColorTokens.background;

    return AnimatedContainer(
      duration: MotionTokens.weatherShift,
      curve: MotionTokens.standard,
      color: background,
      child: child,
    );
  }
}
