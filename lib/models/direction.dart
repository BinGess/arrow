/// Represents the four cardinal directions for arrows in the maze.
enum Direction {
  up,
  down,
  left,
  right;

  /// Returns the opposite direction.
  Direction get opposite {
    switch (this) {
      case Direction.up:
        return Direction.down;
      case Direction.down:
        return Direction.up;
      case Direction.left:
        return Direction.right;
      case Direction.right:
        return Direction.left;
    }
  }

  /// Returns the delta row for this direction.
  int get dr {
    switch (this) {
      case Direction.up:
        return -1;
      case Direction.down:
        return 1;
      case Direction.left:
        return 0;
      case Direction.right:
        return 0;
    }
  }

  /// Returns the delta column for this direction.
  int get dc {
    switch (this) {
      case Direction.up:
        return 0;
      case Direction.down:
        return 0;
      case Direction.left:
        return -1;
      case Direction.right:
        return 1;
    }
  }
}
