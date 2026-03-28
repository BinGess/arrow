import '../models/arrow.dart';
import '../models/game_state.dart';

/// Handles the core game logic: tapping arrows, checking collisions.
class GameEngine {
  final int rows;
  final int cols;

  GameEngine({required this.rows, required this.cols});

  /// Create initial game state from a list of arrows.
  GameState createInitialState(List<Arrow> arrows) {
    return GameState(
      lives: 5,
      remainingArrows: List.unmodifiable(arrows),
    );
  }

  /// Handle the player tapping an arrow.
  ///
  /// Returns (newState, tapResult, hitArrow).
  /// - If the arrow's flight path is clear → remove it (success).
  /// - If the path hits another arrow → lose a life (collision).
  (GameState, TapResult, Arrow?) tapArrow(GameState state, int arrowId) {
    if (state.isComplete || state.isGameOver) return (state, TapResult.collision, null);

    // Find the tapped arrow
    final arrow = state.remainingArrows.where((a) => a.id == arrowId).firstOrNull;
    if (arrow == null) return (state, TapResult.collision, null);

    // Get its flight path
    final path = arrow.flightPath(rows, cols);

    // Check for collisions with remaining arrows (excluding self)
    final occupied = state.occupiedCells;
    Arrow? hitTarget;
    for (final cell in path) {
      if (cell == (arrow.row, arrow.col)) continue;
      if (occupied.contains(cell)) {
        hitTarget = state.arrowAt(cell.$1, cell.$2);
        break;
      }
    }

    if (hitTarget != null) {
      // Collision!
      final newLives = state.lives - 1;
      return (
        state.copyWith(
          lives: newLives,
          lastCollisionId: arrowId,
          hitArrowId: hitTarget.id,
          isGameOver: newLives <= 0,
        ),
        TapResult.collision,
        hitTarget,
      );
    }

    // Success - remove the arrow
    final newRemaining = state.remainingArrows
        .where((a) => a.id != arrowId)
        .toList();
    final newRemoved = [...state.removedOrder, arrowId];
    final isComplete = newRemaining.isEmpty;

    return (
      state.copyWith(
        remainingArrows: newRemaining,
        removedOrder: newRemoved,
        isComplete: isComplete,
        clearCollision: true,
      ),
      TapResult.success,
      null,
    );
  }
}
