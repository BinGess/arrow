import 'maze_cell.dart';

/// Represents a complete maze level.
class MazeLevel {
  final int levelNumber;
  final int rows;
  final int cols;
  final List<List<MazeCell>> grid;
  final int startRow;
  final int startCol;
  final int endRow;
  final int endCol;

  const MazeLevel({
    required this.levelNumber,
    required this.rows,
    required this.cols,
    required this.grid,
    required this.startRow,
    required this.startCol,
    required this.endRow,
    required this.endCol,
  });

  MazeCell cellAt(int row, int col) => grid[row][col];

  bool isStart(int row, int col) => row == startRow && col == startCol;
  bool isEnd(int row, int col) => row == endRow && col == endCol;

  bool isInBounds(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < cols;
}
