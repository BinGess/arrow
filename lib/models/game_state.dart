import 'arrow.dart';

/// The result of tapping an arrow.
enum TapResult {
  /// Arrow flew out safely - no collision.
  success,
  /// Arrow collided with another arrow during flight.
  collision,
}

/// Tracks the state of a game in progress.
class GameState {
  final int lives;
  final int maxLives;

  /// Arrows still on the board.
  final List<Arrow> remainingArrows;

  /// Static obstacle cells (immovable walls).
  final Set<(int, int)> obstacles;

  /// IDs of arrows successfully removed (in order).
  final List<int> removedOrder;

  /// ID of the arrow that just had a collision (for animation), or null.
  final int? lastCollisionId;

  /// ID of the arrow that was hit during collision, or null.
  final int? hitArrowId;

  final bool isComplete;
  final bool isGameOver;

  const GameState({
    required this.lives,
    this.maxLives = 5,
    required this.remainingArrows,
    this.obstacles = const {},
    this.removedOrder = const [],
    this.lastCollisionId,
    this.hitArrowId,
    this.isComplete = false,
    this.isGameOver = false,
  });

  GameState copyWith({
    int? lives,
    List<Arrow>? remainingArrows,
    Set<(int, int)>? obstacles,
    List<int>? removedOrder,
    int? lastCollisionId,
    int? hitArrowId,
    bool? isComplete,
    bool? isGameOver,
    bool clearCollision = false,
  }) {
    return GameState(
      lives: lives ?? this.lives,
      maxLives: maxLives,
      remainingArrows: remainingArrows ?? this.remainingArrows,
      obstacles: obstacles ?? this.obstacles,
      removedOrder: removedOrder ?? this.removedOrder,
      lastCollisionId:
          clearCollision ? null : (lastCollisionId ?? this.lastCollisionId),
      hitArrowId: clearCollision ? null : (hitArrowId ?? this.hitArrowId),
      isComplete: isComplete ?? this.isComplete,
      isGameOver: isGameOver ?? this.isGameOver,
    );
  }

  /// Set of all cells occupied by remaining arrows (heads + tails).
  Set<(int, int)> get occupiedCells {
    final cells = <(int, int)>{};
    for (final a in remainingArrows) {
      cells.addAll(a.occupiedCells);
    }
    return cells;
  }

  /// Find which arrow occupies a given cell (head or tail).
  Arrow? arrowOccupyingCell(int row, int col) {
    for (final a in remainingArrows) {
      if (a.occupiedCells.contains((row, col))) return a;
    }
    return null;
  }
}
