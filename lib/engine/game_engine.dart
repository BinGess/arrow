import '../models/arrow.dart';
import '../models/game_state.dart';

/// Handles the core game logic: tapping arrows, checking collisions.
class GameEngine {
  final int rows;
  final int cols;

  GameEngine({required this.rows, required this.cols});

  /// Create initial game state from a list of arrows.
  GameState createInitialState(List<Arrow> arrows, {int lives = 5}) {
    return GameState(
      lives: lives,
      maxLives: lives,
      remainingArrows: List.unmodifiable(arrows),
    );
  }

  /// Handle the player tapping an arrow.
  ///
  /// The arrow flies in its direction. Its flight path (cells ahead of head)
  /// is checked against ALL occupied cells of OTHER remaining arrows
  /// (including their tail cells). If any overlap → collision.
  (GameState, TapResult, Arrow?) tapArrow(GameState state, int arrowId) {
    if (state.isComplete || state.isGameOver) {
      return (state, TapResult.collision, null);
    }

    // Find the tapped arrow
    final arrow =
        state.remainingArrows.where((a) => a.id == arrowId).firstOrNull;
    if (arrow == null) return (state, TapResult.collision, null);

    // Get cells occupied by OTHER arrows (not the one being tapped)
    final otherOccupied = <(int, int)>{};
    for (final a in state.remainingArrows) {
      if (a.id == arrowId) continue;
      otherOccupied.addAll(a.occupiedCells);
    }

    // Check the flight path for collisions
    final path = arrow.flightPath(rows, cols);
    Arrow? hitTarget;
    for (final cell in path) {
      if (otherOccupied.contains(cell)) {
        // Find which arrow was hit
        hitTarget = state.arrowOccupyingCell(cell.$1, cell.$2);
        if (hitTarget != null && hitTarget.id != arrowId) break;
        hitTarget = null;
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
    final newRemaining =
        state.remainingArrows.where((a) => a.id != arrowId).toList();
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
