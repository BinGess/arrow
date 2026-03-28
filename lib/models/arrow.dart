/// Direction an arrow points and will fly toward.
enum Direction {
  up,
  down,
  left,
  right;

  int get dr {
    switch (this) {
      case Direction.up:    return -1;
      case Direction.down:  return 1;
      case Direction.left:  return 0;
      case Direction.right: return 0;
    }
  }

  int get dc {
    switch (this) {
      case Direction.up:    return 0;
      case Direction.down:  return 0;
      case Direction.left:  return -1;
      case Direction.right: return 1;
    }
  }
}

/// A single arrow on the game board.
class Arrow {
  final int id;
  final int row;
  final int col;
  final Direction direction;

  const Arrow({
    required this.id,
    required this.row,
    required this.col,
    required this.direction,
  });

  /// All cells this arrow will pass through when it flies out,
  /// given grid dimensions [rows] x [cols].
  /// Does NOT include the arrow's own cell.
  List<(int, int)> flightPath(int rows, int cols) {
    final path = <(int, int)>[];
    var r = row + direction.dr;
    var c = col + direction.dc;
    while (r >= 0 && r < rows && c >= 0 && c < cols) {
      path.add((r, c));
      r += direction.dr;
      c += direction.dc;
    }
    return path;
  }
}
