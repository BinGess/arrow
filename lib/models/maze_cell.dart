import 'direction.dart';

/// Represents a single cell in the maze grid.
class MazeCell {
  /// The direction the arrow in this cell points.
  final Direction direction;

  /// Which sides of this cell have walls.
  final bool wallTop;
  final bool wallRight;
  final bool wallBottom;
  final bool wallLeft;

  /// Row and column position in the grid.
  final int row;
  final int col;

  const MazeCell({
    required this.direction,
    required this.row,
    required this.col,
    this.wallTop = false,
    this.wallRight = false,
    this.wallBottom = false,
    this.wallLeft = false,
  });

  /// Check if this cell has a wall in the given direction.
  bool hasWall(Direction dir) {
    switch (dir) {
      case Direction.up:
        return wallTop;
      case Direction.down:
        return wallBottom;
      case Direction.left:
        return wallLeft;
      case Direction.right:
        return wallRight;
    }
  }

  MazeCell copyWith({
    Direction? direction,
    bool? wallTop,
    bool? wallRight,
    bool? wallBottom,
    bool? wallLeft,
  }) {
    return MazeCell(
      direction: direction ?? this.direction,
      row: row,
      col: col,
      wallTop: wallTop ?? this.wallTop,
      wallRight: wallRight ?? this.wallRight,
      wallBottom: wallBottom ?? this.wallBottom,
      wallLeft: wallLeft ?? this.wallLeft,
    );
  }
}
