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

  /// IDs of arrows successfully removed (in order).
  final List<int> removedOrder;

  /// ID of the arrow that just collided (for animation), or null.
  final int? lastCollisionId;

  /// ID of the arrow that was hit during collision, or null.
  final int? hitArrowId;

  final bool isComplete;
  final bool isGameOver;

  const GameState({
    required this.lives,
    this.maxLives = 5,
    required this.remainingArrows,
    this.removedOrder = const [],
    this.lastCollisionId,
    this.hitArrowId,
    this.isComplete = false,
    this.isGameOver = false,
  });

  GameState copyWith({
    int? lives,
    List<Arrow>? remainingArrows,
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
      removedOrder: removedOrder ?? this.removedOrder,
      lastCollisionId: clearCollision ? null : (lastCollisionId ?? this.lastCollisionId),
      hitArrowId: clearCollision ? null : (hitArrowId ?? this.hitArrowId),
      isComplete: isComplete ?? this.isComplete,
      isGameOver: isGameOver ?? this.isGameOver,
    );
  }

  /// Check if a cell is occupied by a remaining arrow.
  Arrow? arrowAt(int row, int col) {
    for (final a in remainingArrows) {
      if (a.row == row && a.col == col) return a;
    }
    return null;
  }

  /// Set of occupied cells for quick lookup.
  Set<(int, int)> get occupiedCells =>
      remainingArrows.map((a) => (a.row, a.col)).toSet();
}
