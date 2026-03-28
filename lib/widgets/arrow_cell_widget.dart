import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/direction.dart';
import '../models/game_state.dart';
import '../models/maze_cell.dart';

/// Renders a single maze cell with walls, arrow, and state coloring.
class ArrowCellWidget extends StatelessWidget {
  final MazeCell cell;
  final CellState cellState;
  final bool isStart;
  final bool isEnd;
  final VoidCallback? onTap;

  const ArrowCellWidget({
    super.key,
    required this.cell,
    required this.cellState,
    this.isStart = false,
    this.isEnd = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _CellPainter(
          cell: cell,
          cellState: cellState,
          isStart: isStart,
          isEnd: isEnd,
        ),
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  final MazeCell cell;
  final CellState cellState;
  final bool isStart;
  final bool isEnd;

  _CellPainter({
    required this.cell,
    required this.cellState,
    required this.isStart,
    required this.isEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final wallPaint = Paint()
      ..color = const Color(0xFF2D2D3A)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw cell background based on state
    final bgPaint = Paint()..style = PaintingStyle.fill;
    switch (cellState) {
      case CellState.current:
        bgPaint.color = const Color(0xFF6C63FF).withOpacity(0.2);
        break;
      case CellState.correct:
        bgPaint.color = const Color(0xFF4CAF50).withOpacity(0.1);
        break;
      case CellState.wrong:
        bgPaint.color = const Color(0xFFFF6B8A).withOpacity(0.15);
        break;
      case CellState.unvisited:
        bgPaint.color = Colors.transparent;
        break;
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Highlight start and end
    if (isStart) {
      final startPaint = Paint()
        ..color = const Color(0xFF4CAF50).withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height), startPaint);
    }
    if (isEnd) {
      final endPaint = Paint()
        ..color = const Color(0xFFFF9800).withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), endPaint);
    }

    // Draw walls
    if (cell.wallTop) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), wallPaint);
    }
    if (cell.wallRight) {
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), wallPaint);
    }
    if (cell.wallBottom) {
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), wallPaint);
    }
    if (cell.wallLeft) {
      canvas.drawLine(Offset.zero, Offset(0, size.height), wallPaint);
    }

    // Draw arrow
    _drawArrow(canvas, size);
  }

  void _drawArrow(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final arrowLength = math.min(size.width, size.height) * 0.3;
    final headLength = arrowLength * 0.4;

    Color arrowColor;
    switch (cellState) {
      case CellState.current:
        arrowColor = const Color(0xFF6C63FF);
        break;
      case CellState.correct:
        arrowColor = const Color(0xFF2D2D3A);
        break;
      case CellState.wrong:
        arrowColor = const Color(0xFFFF6B8A);
        break;
      case CellState.unvisited:
        arrowColor = const Color(0xFF2D2D3A);
        break;
    }

    final arrowPaint = Paint()
      ..color = arrowColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    double angle;
    switch (cell.direction) {
      case Direction.up:
        angle = -math.pi / 2;
        break;
      case Direction.down:
        angle = math.pi / 2;
        break;
      case Direction.left:
        angle = math.pi;
        break;
      case Direction.right:
        angle = 0;
        break;
    }

    // Arrow shaft
    final start = Offset(
      center.dx - arrowLength * math.cos(angle),
      center.dy - arrowLength * math.sin(angle),
    );
    final end = Offset(
      center.dx + arrowLength * math.cos(angle),
      center.dy + arrowLength * math.sin(angle),
    );
    canvas.drawLine(start, end, arrowPaint);

    // Arrow head
    final headAngle1 = angle + math.pi * 0.8;
    final headAngle2 = angle - math.pi * 0.8;
    canvas.drawLine(
      end,
      Offset(
        end.dx + headLength * math.cos(headAngle1),
        end.dy + headLength * math.sin(headAngle1),
      ),
      arrowPaint,
    );
    canvas.drawLine(
      end,
      Offset(
        end.dx + headLength * math.cos(headAngle2),
        end.dy + headLength * math.sin(headAngle2),
      ),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CellPainter oldDelegate) {
    return oldDelegate.cellState != cellState ||
        oldDelegate.cell.direction != cell.direction;
  }
}
