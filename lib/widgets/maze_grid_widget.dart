import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/maze_level.dart';
import '../providers/game_provider.dart';
import 'arrow_cell_widget.dart';

/// Renders the entire maze grid with interactive cells.
class MazeGridWidget extends StatelessWidget {
  const MazeGridWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, _) {
        final level = provider.currentLevel;
        final state = provider.gameState;
        if (level == null || state == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = _calculateCellSize(
              constraints,
              level.rows,
              level.cols,
            );

            final gridWidth = cellSize * level.cols;
            final gridHeight = cellSize * level.rows;

            return Center(
              child: SizedBox(
                width: gridWidth,
                height: gridHeight,
                child: Stack(
                  children: [
                    // Draw path connections
                    CustomPaint(
                      size: Size(gridWidth, gridHeight),
                      painter: _PathPainter(
                        path: state.path,
                        cellSize: cellSize,
                        cellStates: state.cellStates,
                      ),
                    ),
                    // Grid of cells
                    ...List.generate(level.rows * level.cols, (index) {
                      final row = index ~/ level.cols;
                      final col = index % level.cols;
                      final cell = level.cellAt(row, col);
                      final pos = Position(row, col);
                      final cellState =
                          state.cellStates[pos] ?? CellState.unvisited;

                      return Positioned(
                        left: col * cellSize,
                        top: row * cellSize,
                        width: cellSize,
                        height: cellSize,
                        child: ArrowCellWidget(
                          cell: cell,
                          cellState: cellState,
                          isStart: level.isStart(row, col),
                          isEnd: level.isEnd(row, col),
                          onTap: () => provider.tapCell(row, col),
                        ),
                      );
                    }),
                    // Start label
                    Positioned(
                      left: level.startCol * cellSize,
                      top: level.startRow * cellSize - 20,
                      width: cellSize,
                      child: const Text(
                        'S',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // End label
                    Positioned(
                      left: level.endCol * cellSize,
                      top: level.endRow * cellSize + cellSize + 4,
                      width: cellSize,
                      child: const Text(
                        'E',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFF9800),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
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

  double _calculateCellSize(
      BoxConstraints constraints, int rows, int cols) {
    final maxWidth = constraints.maxWidth - 32; // padding
    final maxHeight = constraints.maxHeight - 60; // padding + labels
    final cellW = maxWidth / cols;
    final cellH = maxHeight / rows;
    return cellW < cellH ? cellW : cellH;
  }
}

/// Draws lines connecting the path the player has taken.
class _PathPainter extends CustomPainter {
  final List<Position> path;
  final double cellSize;
  final Map<Position, CellState> cellStates;

  _PathPainter({
    required this.path,
    required this.cellSize,
    required this.cellStates,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

    final correctPaint = Paint()
      ..color = const Color(0xFF6C63FF).withOpacity(0.4)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < path.length - 1; i++) {
      final from = path[i];
      final to = path[i + 1];
      final fromCenter = Offset(
        from.col * cellSize + cellSize / 2,
        from.row * cellSize + cellSize / 2,
      );
      final toCenter = Offset(
        to.col * cellSize + cellSize / 2,
        to.row * cellSize + cellSize / 2,
      );
      canvas.drawLine(fromCenter, toCenter, correctPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.path.length != path.length;
  }
}
