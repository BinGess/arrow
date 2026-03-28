import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/arrow.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';

/// Renders the entire arrow puzzle board with arrows, tails, and animations.
class ArrowBoardWidget extends StatelessWidget {
  const ArrowBoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, _) {
        final state = provider.gameState;
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = provider.gridRows;
        final cols = provider.gridCols;

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth - 16;
            final maxH = constraints.maxHeight - 16;
            final cellSize = math.min(maxW / cols, maxH / rows);
            final gridW = cellSize * cols;
            final gridH = cellSize * rows;

            return Center(
              child: SizedBox(
                width: gridW,
                height: gridH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Grid background
                    CustomPaint(
                      size: Size(gridW, gridH),
                      painter: _GridPainter(rows: rows, cols: cols),
                    ),
                    // All arrows with tails (rendered as one custom paint layer)
                    CustomPaint(
                      size: Size(gridW, gridH),
                      painter: _ArrowsPainter(
                        arrows: state.remainingArrows,
                        cellSize: cellSize,
                        collisionId: state.lastCollisionId,
                        hitId: state.hitArrowId,
                      ),
                    ),
                    // Tap targets for each arrow (invisible, just for hit detection)
                    ...state.remainingArrows.map((arrow) {
                      return _ArrowTapTarget(
                        arrow: arrow,
                        cellSize: cellSize,
                        enabled: !provider.isAnimating,
                        onTap: () => provider.tapArrow(arrow.id),
                      );
                    }),
                    // Flying arrow animation
                    if (provider.flyingArrow != null &&
                        state.lastCollisionId == null)
                      _FlyingArrowWidget(
                        arrow: provider.flyingArrow!,
                        cellSize: cellSize,
                        gridRows: rows,
                        gridCols: cols,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Subtle grid lines.
class _GridPainter extends CustomPainter {
  final int rows;
  final int cols;

  _GridPainter({required this.rows, required this.cols});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF0F0F0)
      ..strokeWidth = 0.5;

    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (var i = 0; i <= cols; i++) {
      canvas.drawLine(
          Offset(i * cellW, 0), Offset(i * cellW, size.height), paint);
    }
    for (var i = 0; i <= rows; i++) {
      canvas.drawLine(
          Offset(0, i * cellH), Offset(size.width, i * cellH), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints all arrows and their tails in a single paint call for performance.
class _ArrowsPainter extends CustomPainter {
  final List<Arrow> arrows;
  final double cellSize;
  final int? collisionId;
  final int? hitId;

  _ArrowsPainter({
    required this.arrows,
    required this.cellSize,
    this.collisionId,
    this.hitId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final arrow in arrows) {
      final isCollision = arrow.id == collisionId;
      final isHit = arrow.id == hitId;
      final color = (isCollision || isHit)
          ? const Color(0xFFFF6B8A)
          : const Color(0xFF2D2D3A);

      // Draw tail first (behind the arrowhead)
      if (arrow.hasTail) {
        _drawTail(canvas, arrow, color);
      }

      // Draw arrowhead
      _drawArrowHead(canvas, arrow, color);
    }
  }

  void _drawTail(Canvas canvas, Arrow arrow, Color color) {
    final strokeWidth = (cellSize * 0.08).clamp(2.0, 5.0);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Build the tail path: head center → through each tail cell center
    final headCenter = _cellCenter(arrow.row, arrow.col);
    final path = Path()..moveTo(headCenter.dx, headCenter.dy);

    var r = arrow.row;
    var c = arrow.col;
    for (final seg in arrow.tailSegments) {
      for (var i = 0; i < seg.length; i++) {
        r += seg.direction.dr;
        c += seg.direction.dc;
        final center = _cellCenter(r, c);
        path.lineTo(center.dx, center.dy);
      }
    }

    canvas.drawPath(path, paint);

    // Draw a small end cap at the tail tip
    final tipCenter = _cellCenter(r, c);
    final capPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(tipCenter, strokeWidth * 0.8, capPaint);
  }

  void _drawArrowHead(Canvas canvas, Arrow arrow, Color color) {
    final center = _cellCenter(arrow.row, arrow.col);
    final arrowSize = cellSize * 0.32;
    final headLen = arrowSize * 0.45;
    final strokeWidth = (cellSize * 0.08).clamp(2.0, 4.5);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    double angle;
    switch (arrow.direction) {
      case Direction.up:    angle = -math.pi / 2; break;
      case Direction.down:  angle = math.pi / 2; break;
      case Direction.left:  angle = math.pi; break;
      case Direction.right: angle = 0; break;
    }

    // Shaft from center backward to center forward
    final tail = Offset(
      center.dx - arrowSize * math.cos(angle),
      center.dy - arrowSize * math.sin(angle),
    );
    final tip = Offset(
      center.dx + arrowSize * math.cos(angle),
      center.dy + arrowSize * math.sin(angle),
    );
    canvas.drawLine(tail, tip, paint);

    // Arrowhead chevron
    final h1 = Offset(
      tip.dx + headLen * math.cos(angle + math.pi * 0.8),
      tip.dy + headLen * math.sin(angle + math.pi * 0.8),
    );
    final h2 = Offset(
      tip.dx + headLen * math.cos(angle - math.pi * 0.8),
      tip.dy + headLen * math.sin(angle - math.pi * 0.8),
    );
    canvas.drawLine(tip, h1, paint);
    canvas.drawLine(tip, h2, paint);
  }

  Offset _cellCenter(int row, int col) {
    return Offset(
      col * cellSize + cellSize / 2,
      row * cellSize + cellSize / 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ArrowsPainter oldDelegate) => true;
}

/// Invisible tap targets covering all of the arrow's cells (head + tail).
class _ArrowTapTarget extends StatelessWidget {
  final Arrow arrow;
  final double cellSize;
  final bool enabled;
  final VoidCallback onTap;

  const _ArrowTapTarget({
    required this.arrow,
    required this.cellSize,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Create a tap target for each occupied cell
    final cells = arrow.occupiedCells;
    return Stack(
      children: cells.map((cell) {
        return Positioned(
          left: cell.$2 * cellSize,
          top: cell.$1 * cellSize,
          width: cellSize,
          height: cellSize,
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        );
      }).toList(),
    );
  }
}

/// Animated arrow that flies off the board with its tail.
class _FlyingArrowWidget extends StatefulWidget {
  final Arrow arrow;
  final double cellSize;
  final int gridRows;
  final int gridCols;

  const _FlyingArrowWidget({
    required this.arrow,
    required this.cellSize,
    required this.gridRows,
    required this.gridCols,
  });

  @override
  State<_FlyingArrowWidget> createState() => _FlyingArrowWidgetState();
}

class _FlyingArrowWidgetState extends State<_FlyingArrowWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flyAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // Fly distance: enough to go off screen
    final maxDist = math.max(
          widget.gridRows * widget.cellSize,
          widget.gridCols * widget.cellSize,
        ) *
        1.5;

    _flyAnimation = Tween<double>(begin: 0, end: maxDist).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
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
        final offset = _flyAnimation.value;
        final dx = widget.arrow.direction.dc * offset;
        final dy = widget.arrow.direction.dr * offset;

        return CustomPaint(
          size: Size(
            widget.gridCols * widget.cellSize,
            widget.gridRows * widget.cellSize,
          ),
          painter: _FlyingArrowPainter(
            arrow: widget.arrow,
            cellSize: widget.cellSize,
            offsetDx: dx,
            offsetDy: dy,
            opacity: (1.0 - _controller.value).clamp(0.0, 1.0),
          ),
        );
      },
    );
  }
}

/// Paints the flying arrow (head + tail) at an offset.
class _FlyingArrowPainter extends CustomPainter {
  final Arrow arrow;
  final double cellSize;
  final double offsetDx;
  final double offsetDy;
  final double opacity;

  _FlyingArrowPainter({
    required this.arrow,
    required this.cellSize,
    required this.offsetDx,
    required this.offsetDy,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = const Color(0xFF6C63FF).withOpacity(opacity);
    final strokeWidth = (cellSize * 0.08).clamp(2.0, 4.5);

    canvas.save();
    canvas.translate(offsetDx, offsetDy);

    // Draw tail
    if (arrow.hasTail) {
      final tailPaint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final headCenter = _cellCenter(arrow.row, arrow.col);
      final path = Path()..moveTo(headCenter.dx, headCenter.dy);

      var r = arrow.row;
      var c = arrow.col;
      for (final seg in arrow.tailSegments) {
        for (var i = 0; i < seg.length; i++) {
          r += seg.direction.dr;
          c += seg.direction.dc;
          final center = _cellCenter(r, c);
          path.lineTo(center.dx, center.dy);
        }
      }
      canvas.drawPath(path, tailPaint);
    }

    // Draw arrowhead
    final center = _cellCenter(arrow.row, arrow.col);
    final arrowSize = cellSize * 0.32;
    final headLen = arrowSize * 0.45;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    double angle;
    switch (arrow.direction) {
      case Direction.up:    angle = -math.pi / 2; break;
      case Direction.down:  angle = math.pi / 2; break;
      case Direction.left:  angle = math.pi; break;
      case Direction.right: angle = 0; break;
    }

    final tail = Offset(
      center.dx - arrowSize * math.cos(angle),
      center.dy - arrowSize * math.sin(angle),
    );
    final tip = Offset(
      center.dx + arrowSize * math.cos(angle),
      center.dy + arrowSize * math.sin(angle),
    );
    canvas.drawLine(tail, tip, paint);

    final h1 = Offset(
      tip.dx + headLen * math.cos(angle + math.pi * 0.8),
      tip.dy + headLen * math.sin(angle + math.pi * 0.8),
    );
    final h2 = Offset(
      tip.dx + headLen * math.cos(angle - math.pi * 0.8),
      tip.dy + headLen * math.sin(angle - math.pi * 0.8),
    );
    canvas.drawLine(tip, h1, paint);
    canvas.drawLine(tip, h2, paint);

    canvas.restore();
  }

  Offset _cellCenter(int row, int col) {
    return Offset(
      col * cellSize + cellSize / 2,
      row * cellSize + cellSize / 2,
    );
  }

  @override
  bool shouldRepaint(covariant _FlyingArrowPainter oldDelegate) => true;
}
