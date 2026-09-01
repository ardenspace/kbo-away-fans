import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/team_themes.dart';
import '../../design/tokens.dart';

/// 배지 판의 칸 하나 — 빈 상태·획득·등급 세 모습.
///
/// 모습을 가르는 것은 도장 개수([stamps]) 하나뿐이다. 등급도 개수에서
/// [BadgeTierTokens.tierFor] 로 나오므로, 부르는 쪽이 "빈 칸인가"와 "무슨
/// 등급인가"를 따로 판단해 서로 어긋나게 만들 자리가 없다.
///
/// - **빈 상태** (0개): 팀 색을 [BadgeTokens.emptyOpacity] 로 흐리게 깔고
///   테두리만 두른다. 무엇을 채우면 되는지는 읽히되 획득 칸과 확실히 갈린다.
/// - **획득** (1개 이상): 몸통이 팀 대표색으로 꽉 찬다. 실제로 칠하는 색은
///   [BadgeTierStyle.bodyColor] 를 거쳐 나온다 — 화면과 대비 검사가 같은
///   색을 보게 하는 유일한 경로다.
/// - **등급**: 몸통 위에 [BadgeTierStyle.rings] 를 그대로 그린다. 색·굵기·겹
///   순서를 이 위젯이 지어내지 않으므로 등급 표현이 두 벌로 갈리지 않는다.
class StampBadge extends StatelessWidget {
  const StampBadge({
    super.key,
    required this.theme,
    this.stamps = 0,
    this.label,
    this.size = BadgeTokens.cellSize,
    this.onTap,
    this.semanticLabel,
  }) : assert(stamps >= 0, '도장 개수는 음수가 될 수 없다');

  /// 칸 몸통의 색을 내는 팀 테마 (칸은 팀 테마 10개와 1:1).
  final TeamTheme theme;

  /// 그 칸에 쌓인 도장 개수. 0이면 빈 칸이다.
  final int stamps;

  /// 칸에 적을 짧은 글자 (팀 약칭 등). 없으면 색과 링만 그린다.
  final String? label;

  /// 칸 지름.
  final double size;

  /// 칸 상세로 들어가는 경로. null 이면 누를 수 없다.
  final VoidCallback? onTap;

  /// 스크린리더가 읽을 이름. 없으면 [label] 을 쓴다.
  final String? semanticLabel;

  /// 이 칸의 등급 — 빈 칸이면 null.
  BadgeTier? get tier => BadgeTierTokens.tierFor(stamps);

  @override
  Widget build(BuildContext context) {
    final style = tier == null ? null : BadgeTierTokens.byTier[tier]!;
    final empty = style == null;

    Widget cell = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: empty
            ? theme.primary.withValues(alpha: BadgeTokens.emptyOpacity)
            : style.bodyColor(theme.primary),
        border: empty
            ? Border.all(
                color: BadgeTokens.emptyBorderColor,
                width: BadgeTokens.emptyBorderWidth,
              )
            : null,
      ),
      child: label == null
          ? null
          : Text(
              label!,
              textAlign: TextAlign.center,
              style: empty
                  ? TextTokens.onTeamLabel.copyWith(
                      color: ColorTokens.textSecondary,
                    )
                  : TextTokens.onTeamLabel.copyWith(color: theme.onPrimary),
            ),
    );

    if (!empty) {
      cell = CustomPaint(
        foregroundPainter: BadgeTierRingPainter(
          layers: style.rings,
          inset: BadgeTokens.tierRingInset,
        ),
        child: cell,
      );
    }

    return Semantics(
      label: semanticLabel ?? label,
      button: onTap != null,
      child: GestureDetector(onTap: onTap, child: cell),
    );
  }
}

/// 등급 링을 그리는 painter — [BadgeTierStyle.rings] 를 **바깥에서 안쪽
/// 순서로** 동심원 테두리로 쌓는다.
///
/// 색과 굵기를 만들지 않고 받은 값만 그린다. 겹의 구성(겉테 → 윤곽 → 금속 띠
/// → …)은 토큰의 판단이라, 그리는 쪽이 순서를 바꾸거나 겹을 더하면 등급
/// 표현이 토큰과 조용히 갈린다.
class BadgeTierRingPainter extends CustomPainter {
  const BadgeTierRingPainter({required this.layers, required this.inset});

  /// 그릴 겹 — 바깥에서 안쪽 순서.
  final List<BadgeRingLayer> layers;

  /// 칸 가장자리에서 링을 안쪽으로 들이는 거리.
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 테두리는 반지름을 가운데로 두고 양쪽으로 굵어지므로, 겹의 바깥 끝을
    // 기준으로 반지름을 잡고 겹 굵기만큼 안으로 들어간다.
    var outerRadius = math.min(size.width, size.height) / 2 - inset;

    for (final layer in layers) {
      final radius = outerRadius - layer.width / 2;
      if (radius <= 0) break;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer.width
          ..color = layer.color,
      );
      outerRadius -= layer.width;
    }
  }

  @override
  bool shouldRepaint(BadgeTierRingPainter oldDelegate) =>
      oldDelegate.layers != layers || oldDelegate.inset != inset;
}
