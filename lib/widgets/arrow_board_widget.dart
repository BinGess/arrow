import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/arrow.dart';
import '../providers/game_provider.dart';

/// Renders the puzzle board with arrows, tails, and snake fly-out animations.
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
                    // Static arrows layer
                    CustomPaint(
                      size: Size(gridW, gridH),
                      painter: _ArrowsPainter(
                        arrows: state.remainingArrows,
                        cellSize: cellSize,
                        collisionId: state.lastCollisionId,
                        hitId: state.hitArrowId,
                      ),
                    ),
                    // Single GestureDetector for the entire board
                    // — no per-cell hit-test issues, always responsive
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final dx = details.localPosition.dx;
                          final dy = details.localPosition.dy;
                          final col = (dx / cellSize).floor();
                          final row = (dy / cellSize).floor();
                          if (row < 0 || row >= rows || col < 0 || col >= cols) return;

                          // First try exact cell
                          var arrow = state.arrowOccupyingCell(row, col);

                          // If missed, search neighboring cells (forgiving tap)
                          if (arrow == null) {
                            // Find the closest arrow within ~1.2 cell radius
                            final tapX = dx;
                            final tapY = dy;
                            double bestDist = cellSize * 1.2;
                            for (var dr = -1; dr <= 1; dr++) {
                              for (var dc = -1; dc <= 1; dc++) {
                                final nr = row + dr, nc = col + dc;
                                if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
                                final candidate = state.arrowOccupyingCell(nr, nc);
                                if (candidate == null) continue;
                                // Distance from tap to cell center
                                final cx = nc * cellSize + cellSize / 2;
                                final cy = nr * cellSize + cellSize / 2;
                                final dist = math.sqrt((tapX - cx) * (tapX - cx) + (tapY - cy) * (tapY - cy));
                                if (dist < bestDist) {
                                  bestDist = dist;
                                  arrow = candidate;
                                }
                              }
                            }
                          }

                          if (arrow != null) {
                            provider.tapArrow(arrow.id);
                          }
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // Flying arrow animations (multiple can play at once)
                    ...provider.flyingArrows.map((arrow) {
                      return _SnakeFlyWidget(
                        key: ValueKey('fly_${arrow.id}'),
                        arrow: arrow,
                        cellSize: cellSize,
                        gridRows: rows,
                        gridCols: cols,
                      );
                    }),
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

// ─── Grid Background ───────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final int rows, cols;
  _GridPainter({required this.rows, required this.cols});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF0F0F0)
      ..strokeWidth = 0.5;
    final cw = size.width / cols, ch = size.height / rows;
    for (var i = 0; i <= cols; i++) {
      canvas.drawLine(Offset(i * cw, 0), Offset(i * cw, size.height), paint);
    }
    for (var i = 0; i <= rows; i++) {
      canvas.drawLine(Offset(0, i * ch), Offset(size.width, i * ch), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Static Arrows Painter ─────────────────────────────────────────

class _ArrowsPainter extends CustomPainter {
  final List<Arrow> arrows;
  final double cellSize;
  final int? collisionId, hitId;

  _ArrowsPainter({
    required this.arrows,
    required this.cellSize,
    this.collisionId,
    this.hitId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final arrow in arrows) {
      final highlight = arrow.id == collisionId || arrow.id == hitId;
      final color = highlight
          ? const Color(0xFFFF6B8A)
          : const Color(0xFF2D2D3A);
      if (arrow.hasTail) _drawTail(canvas, arrow, color);
      _drawArrowHead(canvas, arrow, color);
    }
  }

  void _drawTail(Canvas canvas, Arrow arrow, Color color) {
    final sw = (cellSize * 0.08).clamp(2.0, 5.0);
    final paint = Paint()
      ..color = color..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(
      arrow.col * cellSize + cellSize / 2,
      arrow.row * cellSize + cellSize / 2,
    );
    var r = arrow.row, c = arrow.col;
    for (final seg in arrow.tailSegments) {
      for (var i = 0; i < seg.length; i++) {
        r += seg.direction.dr;
        c += seg.direction.dc;
        path.lineTo(c * cellSize + cellSize / 2, r * cellSize + cellSize / 2);
      }
    }
    canvas.drawPath(path, paint);

    // End cap
    canvas.drawCircle(
      Offset(c * cellSize + cellSize / 2, r * cellSize + cellSize / 2),
      sw * 0.8,
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  void _drawArrowHead(Canvas canvas, Arrow arrow, Color color) {
    final cx = arrow.col * cellSize + cellSize / 2;
    final cy = arrow.row * cellSize + cellSize / 2;
    final len = cellSize * 0.32;
    final hl = len * 0.45;
    final sw = (cellSize * 0.08).clamp(2.0, 4.5);

    final paint = Paint()
      ..color = color..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;

    final angle = _dirAngle(arrow.direction);
    final tail = Offset(cx - len * math.cos(angle), cy - len * math.sin(angle));
    final tip = Offset(cx + len * math.cos(angle), cy + len * math.sin(angle));
    canvas.drawLine(tail, tip, paint);

    canvas.drawLine(tip, Offset(
      tip.dx + hl * math.cos(angle + math.pi * 0.8),
      tip.dy + hl * math.sin(angle + math.pi * 0.8),
    ), paint);
    canvas.drawLine(tip, Offset(
      tip.dx + hl * math.cos(angle - math.pi * 0.8),
      tip.dy + hl * math.sin(angle - math.pi * 0.8),
    ), paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowsPainter oldDelegate) => true;
}

// ─── Snake Fly-Out Animation ───────────────────────────────────────

/// Animates an arrow flying off the board with proper snake/caterpillar motion.
///
/// How it works:
/// 1. Build a "track" — a polyline of waypoints along grid axes:
///    [tail_tip, ..., tail_cells, head, head+dir, head+2*dir, ...]
/// 2. Each body segment sits on this track at a fixed spacing.
/// 3. As animation progresses, all segments advance along the track together.
/// 4. Because the track follows grid axes (with corners), the body naturally
///    "unpeels" around corners — exactly like a snake/caterpillar.
class _SnakeFlyWidget extends StatefulWidget {
  final Arrow arrow;
  final double cellSize;
  final int gridRows, gridCols;

  const _SnakeFlyWidget({
    super.key,
    required this.arrow,
    required this.cellSize,
    required this.gridRows,
    required this.gridCols,
  });

  @override
  State<_SnakeFlyWidget> createState() => _SnakeFlyWidgetState();
}

class _SnakeFlyWidgetState extends State<_SnakeFlyWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// The track: a list of waypoints the snake body slides along.
  /// Goes from tail tip → through body → head → off screen.
  late List<Offset> _track;

  /// Number of body segments (head + tail cells).
  late int _bodyLen;

  /// Cumulative distances along the track at each waypoint.
  late List<double> _trackDistances;
  late double _totalTrackLength;

  @override
  void initState() {
    super.initState();
    _bodyLen = widget.arrow.occupiedCells.length;

    // Build the track waypoints.
    // Body positions: [head, tail1, tail2, ..., tail_tip]
    // We reverse to get: [tail_tip, ..., tail1, head]
    // Then extend with the flight path off-screen.
    final bodyPositions = widget.arrow.occupiedCells
        .map((c) => _cellCenter(c.$1, c.$2))
        .toList();
    final bodyReversed = bodyPositions.reversed.toList();

    // Flight path: head continues in its direction off screen
    final exitCells = math.max(widget.gridRows, widget.gridCols) + 3;
    final headCenter = bodyPositions[0];
    final flightPath = <Offset>[];
    for (var i = 1; i <= exitCells; i++) {
      flightPath.add(Offset(
        headCenter.dx + widget.arrow.direction.dc * widget.cellSize * i,
        headCenter.dy + widget.arrow.direction.dr * widget.cellSize * i,
      ));
    }

    _track = [...bodyReversed, ...flightPath];

    // Pre-compute cumulative distances along the track
    _trackDistances = [0.0];
    for (var i = 1; i < _track.length; i++) {
      final dx = _track[i].dx - _track[i - 1].dx;
      final dy = _track[i].dy - _track[i - 1].dy;
      _trackDistances.add(_trackDistances.last + math.sqrt(dx * dx + dy * dy));
    }
    _totalTrackLength = _trackDistances.last;

    // Duration
    final durationMs = (120 + _bodyLen * 40 + exitCells * 25).clamp(200, 700);
    _controller = AnimationController(
      duration: Duration(milliseconds: durationMs),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Get position along the track at a given distance from the start.
  Offset _positionAtDistance(double dist) {
    if (dist <= 0) return _track.first;
    if (dist >= _totalTrackLength) return _track.last;

    // Binary search for the segment
    var lo = 0, hi = _trackDistances.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) ~/ 2;
      if (_trackDistances[mid] <= dist) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final segStart = _trackDistances[lo];
    final segEnd = _trackDistances[hi];
    final segLen = segEnd - segStart;
    final t = segLen > 0 ? (dist - segStart) / segLen : 0.0;

    return Offset(
      _track[lo].dx + (_track[hi].dx - _track[lo].dx) * t,
      _track[lo].dy + (_track[hi].dy - _track[lo].dy) * t,
    );
  }

  /// Extract all waypoints along the track between two distances.
  /// Returns a list of points that follows the track exactly (no diagonal cuts).
  List<Offset> _trackSubPath(double startDist, double endDist) {
    final points = <Offset>[];
    points.add(_positionAtDistance(startDist));

    // Add all track waypoints that fall between startDist and endDist
    for (var i = 0; i < _trackDistances.length; i++) {
      if (_trackDistances[i] > startDist && _trackDistances[i] < endDist) {
        points.add(_track[i]);
      }
    }

    points.add(_positionAtDistance(endDist));
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // How far has the snake advanced along the track?
        // At t=0: segments are at their original positions
        // At t=1: the tail tip has traveled enough to fully exit
        final advance = _controller.value * (_totalTrackLength);

        // Tail tip starts at distance 0, head starts at _trackDistances[_bodyLen - 1]
        final tailDist = advance; // tail tip's current distance
        final headDist = _trackDistances[_bodyLen - 1] + advance; // head's current distance

        // Extract the sub-path along the track (follows corners correctly)
        final pathPoints = _trackSubPath(tailDist, headDist);

        final opacity = (1.0 - _controller.value * 0.6).clamp(0.0, 1.0);

        return CustomPaint(
          size: Size(
            widget.gridCols * widget.cellSize,
            widget.gridRows * widget.cellSize,
          ),
          painter: _SnakePainter(
            bodyPositions: pathPoints,
            direction: widget.arrow.direction,
            cellSize: widget.cellSize,
            opacity: opacity,
          ),
        );
      },
    );
  }

  Offset _cellCenter(int row, int col) => Offset(
    col * widget.cellSize + widget.cellSize / 2,
    row * widget.cellSize + widget.cellSize / 2,
  );
}

/// Paints the flying snake body + arrowhead.
class _SnakePainter extends CustomPainter {
  final List<Offset> bodyPositions; // [tail_tip, ..., waypoints, ..., head]
  final Direction direction;
  final double cellSize;
  final double opacity;

  _SnakePainter({
    required this.bodyPositions,
    required this.direction,
    required this.cellSize,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bodyPositions.isEmpty) return;
    final color = const Color(0xFF6C63FF).withOpacity(opacity);
    final sw = (cellSize * 0.08).clamp(2.0, 4.5);

    // Body line (follows track waypoints exactly — no diagonal cuts)
    if (bodyPositions.length > 1) {
      final linePaint = Paint()
        ..color = color..strokeWidth = sw
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;

      final path = Path()..moveTo(bodyPositions[0].dx, bodyPositions[0].dy);
      for (var i = 1; i < bodyPositions.length; i++) {
        path.lineTo(bodyPositions[i].dx, bodyPositions[i].dy);
      }
      canvas.drawPath(path, linePaint);

      // Tail end cap (first point = tail tip)
      canvas.drawCircle(bodyPositions.first, sw * 0.8,
        Paint()..color = color..style = PaintingStyle.fill);
    }

    // Arrowhead at the last point (head)
    final head = bodyPositions.last;
    final len = cellSize * 0.32;
    final hl = len * 0.45;
    final paint = Paint()
      ..color = color..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;

    final angle = _dirAngle(direction);
    final tailPt = Offset(head.dx - len * math.cos(angle), head.dy - len * math.sin(angle));
    final tip = Offset(head.dx + len * math.cos(angle), head.dy + len * math.sin(angle));
    canvas.drawLine(tailPt, tip, paint);
    canvas.drawLine(tip, Offset(
      tip.dx + hl * math.cos(angle + math.pi * 0.8),
      tip.dy + hl * math.sin(angle + math.pi * 0.8),
    ), paint);
    canvas.drawLine(tip, Offset(
      tip.dx + hl * math.cos(angle - math.pi * 0.8),
      tip.dy + hl * math.sin(angle - math.pi * 0.8),
    ), paint);
  }

  @override
  bool shouldRepaint(covariant _SnakePainter oldDelegate) => true;
}

// ─── Helpers ───────────────────────────────────────────────────────

double _dirAngle(Direction d) {
  switch (d) {
    case Direction.up:    return -math.pi / 2;
    case Direction.down:  return math.pi / 2;
    case Direction.left:  return math.pi;
    case Direction.right: return 0;
  }
}
