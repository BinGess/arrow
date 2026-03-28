/// Represents the player's position in the maze.
class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is Position && row == other.row && col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => 'Position($row, $col)';
}

/// The state of a cell during gameplay.
enum CellState {
  /// Not yet visited.
  unvisited,

  /// Part of the correct path.
  correct,

  /// Was visited but is a wrong move.
  wrong,

  /// Currently active/selected cell.
  current,
}

/// Tracks the state of a game in progress.
class GameState {
  final int lives;
  final int maxLives;
  final Position currentPosition;
  final List<Position> path;
  final Map<Position, CellState> cellStates;
  final bool isComplete;
  final bool isGameOver;

  const GameState({
    required this.lives,
    this.maxLives = 5,
    required this.currentPosition,
    required this.path,
    required this.cellStates,
    this.isComplete = false,
    this.isGameOver = false,
  });

  GameState copyWith({
    int? lives,
    Position? currentPosition,
    List<Position>? path,
    Map<Position, CellState>? cellStates,
    bool? isComplete,
    bool? isGameOver,
  }) {
    return GameState(
      lives: lives ?? this.lives,
      maxLives: maxLives,
      currentPosition: currentPosition ?? this.currentPosition,
      path: path ?? this.path,
      cellStates: cellStates ?? this.cellStates,
      isComplete: isComplete ?? this.isComplete,
      isGameOver: isGameOver ?? this.isGameOver,
    );
  }
}
