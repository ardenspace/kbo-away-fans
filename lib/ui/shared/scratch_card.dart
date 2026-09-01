import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// "오늘 뭐하지?" 긁기 랜덤 추천 카드 (추천 목록의 마지막 항목).
///
/// 범용 동작(긁기 제스처·드러남 연출)만 담당한다. "무엇을 숨길지"
/// (예: 현재 필터 풀에서 랜덤 장소 선택)는 소유 화면이 [hiddenLabel] /
/// [hiddenSublabel] 로 넘기고, 재긁기 시 [onRescratch] 안에서 갈아끼운다.
///
/// 구현: CustomPainter 커버를 saveLayer + BlendMode.clear 스트로크로
/// 지우고, 그리드 커버리지 비율이 임계에 닿으면 커버가 페이드아웃하며
/// 공개된다. 연출 지속시간·커브는 전부 `motion.*` 토큰에서 온다.
class ScratchCard extends StatefulWidget {
  const ScratchCard({
    super.key,
    required this.hiddenLabel,
    this.hiddenSublabel,
    this.onRevealed,
    this.onRescratch,
  });

  /// 긁으면 드러나는 추천 문구 (장소 이름 등).
  final String hiddenLabel;

  /// 함께 드러나는 보조 문구 (카테고리 라벨 등). null 이면 한 줄만.
  final String? hiddenSublabel;

  /// 공개 완료 시 1회 호출 (재긁기 후 다시 공개되면 다시 1회).
  final VoidCallback? onRevealed;

  /// non-null 이면 공개 후 '다시 긁기' 버튼을 노출한다.
  /// 탭 시 카드가 커버·긁기 상태를 스스로 리셋한 뒤 이 콜백을 불러,
  /// 소유자가 숨김 내용([hiddenLabel] 등)을 새로 고를 기회를 준다.
  final VoidCallback? onRescratch;

  @override
  State<ScratchCard> createState() => _ScratchCardState();
}

class _ScratchCardState extends State<ScratchCard> {
  /// 긁기 브러시 반경 — 치수이므로 space 토큰을 재사용한다.
  static const double _brushRadius = SpaceTokens.xl;

  /// 공개 판정용 커버리지 그리드 밀도·임계 비율.
  /// 연출 수치(시간·커브)가 아닌 판정 파라미터라 위젯 내 상수로 둔다.
  static const int _gridCols = 10;
  static const int _gridRows = 4;
  static const double _revealThreshold = 0.55;

  /// 긁은 자취 — 스트로크(포인트 목록)의 목록. 커버 좌표계 기준.
  final List<List<Offset>> _strokes = [];

  /// 브러시가 지나간 그리드 셀 인덱스 (진행률 = 크기 / 전체 셀 수).
  final Set<int> _scratchedCells = {};

  int _revision = 0;
  bool _revealed = false;
  Size _coverSize = Size.zero;

  void _addPoint(Offset point, {required bool newStroke}) {
    if (_revealed) return;
    var justRevealed = false;
    setState(() {
      if (newStroke || _strokes.isEmpty) _strokes.add([]);
      _strokes.last.add(point);
      _revision++;
      _markCells(point);
      if (_scratchedCells.length >=
          _revealThreshold * (_gridCols * _gridRows)) {
        _revealed = true;
        justRevealed = true;
      }
    });
    if (justRevealed) widget.onRevealed?.call();
  }

  void _markCells(Offset point) {
    final size = _coverSize;
    if (size.isEmpty) return;
    final cellWidth = size.width / _gridCols;
    final cellHeight = size.height / _gridRows;
    for (var row = 0; row < _gridRows; row++) {
      for (var col = 0; col < _gridCols; col++) {
        final center = Offset(
          (col + 0.5) * cellWidth,
          (row + 0.5) * cellHeight,
        );
        if ((center - point).distance <= _brushRadius) {
          _scratchedCells.add(row * _gridCols + col);
        }
      }
    }
  }

  void _rescratch() {
    setState(() {
      _revealed = false;
      _strokes.clear();
      _scratchedCells.clear();
      _revision++;
    });
    widget.onRescratch?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        border: Border.all(color: ColorTokens.outline),
      ),
      child: Stack(
        children: [
          _revealedContent(),
          Positioned.fill(child: _cover()),
        ],
      ),
    );
  }

  /// 커버 밑에 깔리는 실제 내용 — 공개 전에는 빈 문구로 자리만 잡는다
  /// (커버가 불투명해 보이지 않고, find.text 로도 잡히지 않는다).
  Widget _revealedContent() {
    final sublabel = widget.hiddenSublabel;
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(SpaceTokens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _revealed ? widget.hiddenLabel : '',
              textAlign: TextAlign.center,
              style: TextTokens.sectionTitle,
            ),
            if (sublabel != null) ...[
              const SizedBox(height: SpaceTokens.xs),
              Text(
                _revealed ? sublabel : '',
                textAlign: TextAlign.center,
                style: TextTokens.supporting,
              ),
            ],
            if (_revealed && widget.onRescratch != null) ...[
              const SizedBox(height: SpaceTokens.sm),
              TextButton(
                onPressed: _rescratch,
                child: Text(
                  '다시 긁기',
                  style: TextTokens.inheritColor(TextTokens.label),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 긁히는 커버 — 공개되면 페이드아웃하고 포인터를 통과시킨다.
  Widget _cover() {
    return IgnorePointer(
      ignoring: _revealed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) =>
            _addPoint(details.localPosition, newStroke: true),
        onPanUpdate: (details) =>
            _addPoint(details.localPosition, newStroke: false),
        child: AnimatedOpacity(
          opacity: _revealed ? 0 : 1,
          duration: MotionTokens.base,
          curve: MotionTokens.standard,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _coverSize = constraints.biggest;
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _ScratchCoverPainter(
                      strokes: _strokes,
                      revision: _revision,
                      brushRadius: _brushRadius,
                    ),
                  ),
                  Center(
                    child: AnimatedOpacity(
                      opacity: _strokes.isEmpty ? 1 : 0,
                      duration: MotionTokens.fast,
                      curve: MotionTokens.standard,
                      child: Padding(
                        padding: const EdgeInsets.all(SpaceTokens.md),
                        child: Text(
                          '오늘 뭐하지? 긁어 보기',
                          textAlign: TextAlign.center,
                          style: TextTokens.sectionTitleMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 커버를 그리고, 긁은 자취를 BlendMode.clear 로 지우는 painter.
class _ScratchCoverPainter extends CustomPainter {
  _ScratchCoverPainter({
    required this.strokes,
    required this.revision,
    required this.brushRadius,
  });

  final List<List<Offset>> strokes;
  final int revision;
  final double brushRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(bounds, Paint()..color = ColorTokens.surfaceDim);

    final strokeErase = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = brushRadius * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dotErase = Paint()..blendMode = BlendMode.clear;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, brushRadius, dotErase);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, strokeErase);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScratchCoverPainter oldDelegate) =>
      oldDelegate.revision != revision ||
      oldDelegate.brushRadius != brushRadius;
}
