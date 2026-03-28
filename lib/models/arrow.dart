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

  Direction get opposite {
    switch (this) {
      case Direction.up:    return Direction.down;
      case Direction.down:  return Direction.up;
      case Direction.left:  return Direction.right;
      case Direction.right: return Direction.left;
    }
  }

  /// The two directions perpendicular to this one.
  List<Direction> get perpendicular {
    switch (this) {
      case Direction.up:
      case Direction.down:
        return [Direction.left, Direction.right];
      case Direction.left:
      case Direction.right:
        return [Direction.up, Direction.down];
    }
  }
}

/// A segment of an arrow's tail.
class TailSegment {
  /// Direction this segment extends (away from head).
  final Direction direction;

  /// Number of cells this segment spans.
  final int length;

  const TailSegment({required this.direction, required this.length});
}

/// A single arrow on the game board.
///
/// An arrow has a head cell at (row, col) pointing in [direction],
/// and an optional tail made of [TailSegment]s extending behind it.
/// The tail can be straight (one segment) or L-shaped (two segments).
class Arrow {
  final int id;
  final int row;
  final int col;
  final Direction direction;

  /// Tail segments starting from the head position.
  /// A straight tail has 1 segment (opposite to direction).
  /// An L-shaped tail has 2 segments (opposite + perpendicular turn).
  final List<TailSegment> tailSegments;

  const Arrow({
    required this.id,
    required this.row,
    required this.col,
    required this.direction,
    this.tailSegments = const [],
  });

  /// All cells occupied by this arrow (head + tail cells).
  List<(int, int)> get occupiedCells {
    final cells = <(int, int)>[(row, col)];

    var r = row;
    var c = col;
    for (final seg in tailSegments) {
      for (var i = 0; i < seg.length; i++) {
        r += seg.direction.dr;
        c += seg.direction.dc;
        cells.add((r, c));
      }
    }

    return cells;
  }

  /// Ordered list of tail cell positions (for rendering the line).
  /// Starts from the cell adjacent to the head, ends at the tail tip.
  List<(int, int)> get tailCells {
    final cells = <(int, int)>[];
    var r = row;
    var c = col;
    for (final seg in tailSegments) {
      for (var i = 0; i < seg.length; i++) {
        r += seg.direction.dr;
        c += seg.direction.dc;
        cells.add((r, c));
      }
    }
    return cells;
  }

  /// Total tail length in cells.
  int get tailLength =>
      tailSegments.fold(0, (sum, seg) => sum + seg.length);

  /// Whether this arrow has any tail.
  bool get hasTail => tailSegments.isNotEmpty;

  /// All cells the arrowhead flies through when launched.
  /// Only includes cells AHEAD of the head (not the head itself).
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
