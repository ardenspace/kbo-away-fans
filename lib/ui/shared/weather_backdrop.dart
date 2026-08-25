import 'dart:math';

import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// 날씨 연동 배경 연출 (홈·추천 화면 배경).
///
/// [raining] 이면 배경색을 비 오는 톤으로 전환하고 그 위에
/// 빗줄기 애니메이션([RainLayer])을 틀어 플랜B(실내 필터)를 유도한다.
/// 날씨 계층과는 비결합 — 호출자가 bool 하나로 상태를 주입한다.
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
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (raining) const Positioned.fill(child: RainLayer()),
          child,
        ],
      ),
    );
  }
}

/// 빗줄기 애니메이션 레이어 — [WeatherBackdrop] 의 비 상태에서만 트리에
/// 존재한다 (위젯 테스트가 `find.byType(RainLayer)` 로 관찰하는 계약).
///
/// 구현: 고정 시드 의사난수 빗줄기를 [CustomPainter] 로 그리고,
/// repeat [AnimationController] ([MotionTokens.rainFall] 주기)로 흘린다.
class RainLayer extends StatefulWidget {
  const RainLayer({super.key});

  @override
  State<RainLayer> createState() => _RainLayerState();
}

class _RainLayerState extends State<RainLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionTokens.rainFall,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _RainPainter(progress: _controller),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// 빗줄기 1개의 정적 파라미터 (시드 난수로 1회 생성).
typedef _Drop = ({double x, double phase, double scale});

class _RainPainter extends CustomPainter {
  _RainPainter({required this.progress}) : super(repaint: progress);

  /// 낙하 진행도 (0..1 반복) — 리페인트 트리거.
  final Animation<double> progress;

  /// 고정 시드 빗줄기 배치 — 프레임 간 동일해 낙하만 움직여 보인다.
  static final List<_Drop> _drops = _seedDrops();

  static List<_Drop> _seedDrops() {
    final random = Random(20260825);
    return List.generate(
      RainTokens.dropCount,
      (_) => (
        x: random.nextDouble(),
        phase: random.nextDouble(),
        // 방울별 길이·기울기 변주 (원근감).
        scale: (random.nextDouble() + 1) / 2,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = ColorTokens.rainDrop
      ..strokeWidth = RainTokens.strokeWidth
      ..strokeCap = StrokeCap.round;

    for (final drop in _drops) {
      final length = RainTokens.dropLength * drop.scale;
      final t = (progress.value + drop.phase) % 1;
      // 화면 위 바깥에서 아래 바깥까지 종단한다.
      final travel = size.height + length * 2;
      final headY = t * travel - length;
      final slantDx = length * RainTokens.slant;
      final x = ((drop.x + t * RainTokens.slant * drop.scale) % 1) * size.width;
      canvas.drawLine(
        Offset(x + slantDx, headY - length),
        Offset(x, headY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RainPainter oldDelegate) =>
      !identical(oldDelegate.progress, progress);
}
