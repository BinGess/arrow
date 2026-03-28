import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/arrow.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';

/// Renders the entire arrow puzzle board with all arrows and animations.
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
                    // Grid background lines
                    CustomPaint(
                      size: Size(gridW, gridH),
                      painter: _GridPainter(rows: rows, cols: cols),
                    ),
                    // Remaining arrows
                    ...state.remainingArrows.map((arrow) {
                      final isCollision =
                          arrow.id == state.lastCollisionId;
                      final isHit = arrow.id == state.hitArrowId;

                      return Positioned(
                        left: arrow.col * cellSize,
                        top: arrow.row * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: _ArrowWidget(
                          arrow: arrow,
                          cellSize: cellSize,
                          isCollision: isCollision,
                          isHit: isHit,
                          onTap: provider.isAnimating
                              ? null
                              : () => provider.tapArrow(arrow.id),
                        ),
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

/// Draws subtle grid lines.
class _GridPainter extends CustomPainter {
  final int rows;
  final int cols;

  _GridPainter({required this.rows, required this.cols});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 0.5;

    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (var i = 0; i <= cols; i++) {
      canvas.drawLine(
        Offset(i * cellW, 0),
        Offset(i * cellW, size.height),
        paint,
      );
    }
    for (var i = 0; i <= rows; i++) {
      canvas.drawLine(
        Offset(0, i * cellH),
        Offset(size.width, i * cellH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A single arrow on the board.
class _ArrowWidget extends StatelessWidget {
  final Arrow arrow;
  final double cellSize;
  final bool isCollision;
  final bool isHit;
  final VoidCallback? onTap;

  const _ArrowWidget({
    required this.arrow,
    required this.cellSize,
    this.isCollision = false,
    this.isHit = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isCollision
              ? const Color(0xFFFF6B8A).withOpacity(0.2)
              : isHit
                  ? const Color(0xFFFF6B8A).withOpacity(0.15)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: CustomPaint(
          painter: _ArrowPainter(
            direction: arrow.direction,
            color: isCollision || isHit
                ? const Color(0xFFFF6B8A)
                : const Color(0xFF2D2D3A),
          ),
        ),
      ),
    );
  }
}

/// Paints a directional arrow.
class _ArrowPainter extends CustomPainter {
  final Direction direction;
  final Color color;

  _ArrowPainter({required this.direction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final length = math.min(size.width, size.height) * 0.32;
    final headLen = length * 0.45;
    final strokeWidth = math.min(size.width, size.height) * 0.07;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth.clamp(2.0, 4.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    double angle;
    switch (direction) {
      case Direction.up:    angle = -math.pi / 2; break;
      case Direction.down:  angle = math.pi / 2; break;
      case Direction.left:  angle = math.pi; break;
      case Direction.right: angle = 0; break;
    }

    // Shaft
    final tail = Offset(
      center.dx - length * math.cos(angle),
      center.dy - length * math.sin(angle),
    );
    final tip = Offset(
      center.dx + length * math.cos(angle),
      center.dy + length * math.sin(angle),
    );
    canvas.drawLine(tail, tip, paint);

    // Arrowhead
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

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.direction != direction;
}

/// Animated arrow that flies off the board.
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
  late Animation<Offset> _positionAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    final startX = widget.arrow.col * widget.cellSize;
    final startY = widget.arrow.row * widget.cellSize;

    // Calculate end position (off screen)
    double endX = startX;
    double endY = startY;
    final flyDist = math.max(
      widget.gridRows * widget.cellSize,
      widget.gridCols * widget.cellSize,
    ) * 1.5;

    switch (widget.arrow.direction) {
      case Direction.up:    endY = startY - flyDist; break;
      case Direction.down:  endY = startY + flyDist; break;
      case Direction.left:  endX = startX - flyDist; break;
      case Direction.right: endX = startX + flyDist; break;
    }

    _positionAnimation = Tween<Offset>(
      begin: Offset(startX, startY),
      end: Offset(endX, endY),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0),
      ),
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
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          width: widget.cellSize,
          height: widget.cellSize,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: CustomPaint(
              painter: _ArrowPainter(
                direction: widget.arrow.direction,
                color: const Color(0xFF6C63FF),
              ),
            ),
          ),
        );
      },
    );
  }
}
