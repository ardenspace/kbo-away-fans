import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// "오늘 뭐하지?" 긁기 랜덤 추천 카드 (추천 목록의 마지막 항목).
///
/// 골격 단계: 긁기 연출 없이 탭하면 즉시 공개된다.
/// 실제 긁기 연출(CustomPainter/shader 등)은 implementer discretion 영역으로,
/// 이후 이 위젯 내부에서 교체한다.
class ScratchCard extends StatefulWidget {
  const ScratchCard({
    super.key,
    required this.hiddenLabel,
    this.onRevealed,
  });

  /// 긁으면 드러나는 추천 문구.
  final String hiddenLabel;

  /// 공개 완료 시 1회 호출.
  final VoidCallback? onRevealed;

  @override
  State<ScratchCard> createState() => _ScratchCardState();
}

class _ScratchCardState extends State<ScratchCard> {
  bool _revealed = false;

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
    widget.onRevealed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _reveal,
      child: AnimatedContainer(
        duration: MotionTokens.base,
        curve: MotionTokens.emphasized,
        padding: const EdgeInsets.all(SpaceTokens.xl),
        decoration: BoxDecoration(
          color: _revealed ? ColorTokens.surface : ColorTokens.surfaceDim,
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
        ),
        child: Center(
          child: Text(
            _revealed ? widget.hiddenLabel : '오늘 뭐하지? 긁어 보기',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TypeTokens.fontFamily,
              fontSize: TypeTokens.heading,
              fontWeight: TypeTokens.weightBold,
              color: _revealed
                  ? ColorTokens.textPrimary
                  : ColorTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
