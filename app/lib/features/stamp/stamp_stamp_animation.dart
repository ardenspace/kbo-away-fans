/// 도장 "쾅 찍히기" 애니메이션 + 햅틱 (R8).
///
/// 외부 애니 에셋(Lottie/Rive) 의존 없이 Flutter 기본 애니 프리미티브만 쓴다:
/// [AnimationController] + [TweenSequence] 오버슈트 스케일 + 낙하 오프셋 + 기울기.
/// 큰 도장이 위에서 떨어져 오버슈트로 찍히고, 살짝 기울어진 채 안착하며,
/// 재생 시작 시 햅틱이 1회 울린다. 복수 칸은 [StampCelebrationLayer] 가 칸당
/// 이 위젯을 하나씩 순차로 마운트해 재생한다.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stamp_controller.dart';
import 'stamp_models.dart';
import '../../shared/theme/team_colors.dart';

/// 발급 성공 애니가 한 칸을 재생하기 시작하는 순간(=도장 컨트롤러 forward 호출
/// 시점)을 관측하는 seam. 프로덕션 기본은 no-op(null). 위젯 테스트가 override 해서
/// 재생된 칸의 순서·횟수를 기록한다 (R8 호출 횟수·순서 검증).
typedef StampCelebrationObserver = void Function(StampStadium slot);

final stampCelebrationObserverProvider =
    Provider<StampCelebrationObserver?>((ref) => null);

/// 한 칸 도장 애니. 마운트되는 즉시 햅틱 1회 + 컨트롤러 forward 1회를 재생한다.
class StampStampAnimation extends StatefulWidget {
  const StampStampAnimation({
    super.key,
    required this.color,
    required this.label,
    this.onPlay,
    this.onCompleted,
  });

  /// 도장 색(그 칸의 팀 컬러).
  final Color color;

  /// 도장 안에 찍히는 팀 abbr.
  final String label;

  /// forward 호출 직전에 발화한다 — 재생 시작(=도장 찍힘) 관측 지점.
  final VoidCallback? onPlay;

  /// 애니가 끝나면 발화한다 — 다음 칸으로 넘어가는 순차 재생 훅.
  final VoidCallback? onCompleted;

  @override
  State<StampStampAnimation> createState() => _StampStampAnimationState();
}

class _StampStampAnimationState extends State<StampStampAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _drop;
  late final Animation<double> _tilt;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    // 오버슈트 스케일: 크게 떨어져 살짝 작아졌다가 제자리로 안착.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 2.2, end: 0.86)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 62,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.86, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 38,
      ),
    ]).animate(_controller);

    // 위에서 떨어져 내리는 오프셋.
    _drop = Tween<double>(begin: -46, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.62,
          curve: Curves.easeIn)),
    );

    // 안착하며 살짝 기울어진다.
    _tilt = Tween<double>(begin: -0.32, end: -0.09).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // 찍히는 순간 빠르게 나타난다.
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.25, curve: Curves.easeOut),
    );

    _play();
  }

  void _play() {
    // 발급된 칸당 정확히 1회: 햅틱 → 관측 훅 → 컨트롤러 forward.
    HapticFeedback.mediumImpact();
    widget.onPlay?.call();
    _controller.forward().whenComplete(() => widget.onCompleted?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, _drop.value),
            child: Transform.rotate(
              angle: _tilt.value,
              child: Transform.scale(scale: _scale.value, child: child),
            ),
          ),
        );
      },
      child: _StampMark(color: widget.color, label: widget.label),
    );
  }
}

/// 도장 자국 — 팀 컬러 링 + abbr.
class _StampMark extends StatelessWidget {
  const _StampMark({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color, width: 5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 34,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// 발급 성공 상태를 구독해 발급된 칸을 순차로 재생하는 오버레이.
///
/// [StampIssued]/[StampPartiallyIssued] 가 방출되면 발급된 칸을 큐에 넣고
/// 한 번에 하나씩(이전 칸 애니 완료 시 다음 칸) 재생한다 — R8 "칸 순서대로 순차".
/// 성공한 칸만 재생하므로 부분 실패 시 실패 칸 애니는 나오지 않는다.
class StampCelebrationLayer extends ConsumerStatefulWidget {
  const StampCelebrationLayer({super.key});

  @override
  ConsumerState<StampCelebrationLayer> createState() =>
      _StampCelebrationLayerState();
}

class _StampCelebrationLayerState extends ConsumerState<StampCelebrationLayer> {
  final List<StampStadium> _queue = [];
  StampStadium? _current;
  int _seq = 0;

  void _enqueue(List<StampStadium> slots) {
    if (slots.isEmpty) return;
    _queue.addAll(slots);
    if (_current == null) _advance();
  }

  void _advance() {
    if (_queue.isEmpty) {
      setState(() => _current = null);
      return;
    }
    setState(() {
      _current = _queue.removeAt(0);
      _seq++;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<StampIssueState>(stampControllerProvider, (prev, next) {
      final slots = switch (next) {
        StampIssued(:final slots) => slots,
        StampPartiallyIssued(:final issuedSlots) => issuedSlots,
        _ => const <StampStadium>[],
      };
      _enqueue([...slots]);
    });

    final current = _current;
    if (current == null) return const SizedBox.shrink();

    final color =
        kTeamColors[current.teamAbbr]?.primary ?? kNeutralColors.primary;
    final observer = ref.read(stampCelebrationObserverProvider);
    return IgnorePointer(
      child: Center(
        child: StampStampAnimation(
          key: ValueKey('stamp-anim-${current.teamAbbr}-$_seq'),
          color: color,
          label: current.teamAbbr,
          onPlay: () => observer?.call(current),
          onCompleted: _advance,
        ),
      ),
    );
  }
}
