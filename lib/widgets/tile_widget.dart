import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/puzzle_tile.dart';

/// Renders a single puzzle tile with its pipe connections and optional arrow.
class TileWidget extends StatefulWidget {
  final PuzzleTile tile;
  final bool isActive;
  final VoidCallback? onTap;
  final double size;

  const TileWidget({
    super.key,
    required this.tile,
    required this.isActive,
    this.onTap,
    required this.size,
  });

  @override
  State<TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnim;
  int _previousRotation = 0;

  @override
  void initState() {
    super.initState();
    _previousRotation = widget.tile.rotation;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _rotationAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(TileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tile.rotation != widget.tile.rotation) {
      final from = _previousRotation * math.pi / 2;
      final to = widget.tile.rotation * math.pi / 2;
      _rotationAnim = Tween<double>(begin: from, end: to).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
      _previousRotation = widget.tile.rotation;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _TilePainter(
              tile: widget.tile,
              isActive: widget.isActive,
              rotationAngle: _rotationAnim.value,
            ),
          );
        },
      ),
    );
  }
}

class _TilePainter extends CustomPainter {
  final PuzzleTile tile;
  final bool isActive;
  final double rotationAngle;

  _TilePainter({
    required this.tile,
    required this.isActive,
    required this.rotationAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final cellSize = size.width;

    // Background
    final bgColor = tile.isSource
        ? const Color(0xFFE8F5E9)
        : tile.isTarget
            ? const Color(0xFFFFF3E0)
            : isActive
                ? const Color(0xFFF0EEFF)
                : const Color(0xFFF5F5F5);
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, cellSize - 2, cellSize - 2),
        const Radius.circular(4),
      ),
      bgPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = isActive
          ? const Color(0xFF6C63FF).withOpacity(0.3)
          : const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, cellSize - 2, cellSize - 2),
        const Radius.circular(4),
      ),
      borderPaint,
    );

    // Draw pipe connections with rotation
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);
    canvas.translate(-center.dx, -center.dy);

    _drawPipe(canvas, size);

    canvas.restore();

    // Draw arrow indicator (not rotated with the pipe)
    if (tile.hasArrow && tile.arrowDirection != null) {
      _drawArrowIndicator(canvas, size);
    }

    // Source/Target indicators
    if (tile.isSource) {
      _drawLabel(canvas, size, 'S', const Color(0xFF4CAF50));
    } else if (tile.isTarget) {
      _drawLabel(canvas, size, 'E', const Color(0xFFFF9800));
    }

    // Fixed indicator (lock icon area)
    if (tile.isFixed && !tile.isSource && !tile.isTarget) {
      final lockPaint = Paint()
        ..color = const Color(0xFF9E9E9E).withOpacity(0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(cellSize - 8, 8),
        3,
        lockPaint,
      );
    }
  }

  void _drawPipe(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pipeWidth = size.width * 0.22;
    final halfPipe = pipeWidth / 2;

    final pipeColor = isActive
        ? const Color(0xFF6C63FF)
        : const Color(0xFF2D2D3A).withOpacity(0.7);

    final pipePaint = Paint()
      ..color = pipeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = pipeWidth
      ..strokeCap = StrokeCap.butt;

    final fillPaint = Paint()
      ..color = pipeColor
      ..style = PaintingStyle.fill;

    // Get base sides (at rotation 0) since we're rotating the canvas
    final baseSides = PuzzleTile.baseSidesFor(tile.type);

    // Draw pipe segments from center to each open side
    for (final dir in baseSides) {
      Offset edgeMid;
      switch (dir) {
        case CardinalDirection.north:
          edgeMid = Offset(center.dx, 0);
          break;
        case CardinalDirection.south:
          edgeMid = Offset(center.dx, size.height);
          break;
        case CardinalDirection.east:
          edgeMid = Offset(size.width, center.dy);
          break;
        case CardinalDirection.west:
          edgeMid = Offset(0, center.dy);
          break;
      }
      canvas.drawLine(center, edgeMid, pipePaint);
    }

    // Draw center joint circle
    if (baseSides.length > 1) {
      canvas.drawCircle(center, halfPipe, fillPaint);
    }

    // Draw end cap circle for dead-end tiles
    if (tile.type == TileType.endCap) {
      canvas.drawCircle(center, halfPipe + 2, fillPaint);
      // Draw a small dot
      final dotPaint = Paint()
        ..color = isActive ? Colors.white : const Color(0xFFF5F5F5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, halfPipe - 3, dotPaint);
    }
  }

  void _drawArrowIndicator(Canvas canvas, Size size) {
    if (tile.arrowDirection == null) return;

    final center = Offset(size.width / 2, size.height / 2);
    final arrowSize = size.width * 0.15;

    double angle;
    switch (tile.arrowDirection!) {
      case CardinalDirection.north:
        angle = -math.pi / 2;
        break;
      case CardinalDirection.south:
        angle = math.pi / 2;
        break;
      case CardinalDirection.east:
        angle = 0;
        break;
      case CardinalDirection.west:
        angle = math.pi;
        break;
    }

    final arrowPaint = Paint()
      ..color = const Color(0xFFFF6B8A)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Small arrow near center
    final tipX = center.dx + arrowSize * math.cos(angle);
    final tipY = center.dy + arrowSize * math.sin(angle);
    final tip = Offset(tipX, tipY);

    final headLen = arrowSize * 0.6;
    final h1 = Offset(
      tipX + headLen * math.cos(angle + math.pi * 0.75),
      tipY + headLen * math.sin(angle + math.pi * 0.75),
    );
    final h2 = Offset(
      tipX + headLen * math.cos(angle - math.pi * 0.75),
      tipY + headLen * math.sin(angle - math.pi * 0.75),
    );

    canvas.drawLine(tip, h1, arrowPaint);
    canvas.drawLine(tip, h2, arrowPaint);
  }

  void _drawLabel(Canvas canvas, Size size, String label, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(4, 2));
  }

  @override
  bool shouldRepaint(covariant _TilePainter oldDelegate) {
    return oldDelegate.isActive != isActive ||
        oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.tile.rotation != tile.rotation;
  }
}
