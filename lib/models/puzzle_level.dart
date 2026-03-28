import 'puzzle_tile.dart';

/// A complete puzzle level definition.
class PuzzleLevel {
  final int levelNumber;
  final int rows;
  final int cols;
  final List<List<PuzzleTile>> grid;

  /// The solution rotation for each tile (used for validation).
  final List<List<int>> solutionRotations;

  const PuzzleLevel({
    required this.levelNumber,
    required this.rows,
    required this.cols,
    required this.grid,
    required this.solutionRotations,
  });

  PuzzleTile tileAt(int row, int col) => grid[row][col];

  bool isInBounds(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < cols;
}
