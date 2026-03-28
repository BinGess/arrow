import 'dart:math';
import '../models/arrow.dart';

/// Generates solvable arrow-removal puzzle levels.
///
/// Strategy: Place arrows one by one in reverse-removal order.
/// The LAST arrow placed is the one that should be tapped FIRST
/// (because it has a clear path). This guarantees solvability.
class LevelGenerator {
  final Random _random;

  LevelGenerator({int? seed}) : _random = Random(seed);

  /// Grid dimensions and arrow count by level.
  static (int rows, int cols, int arrowCount) configForLevel(int level) {
    if (level <= 2)  return (5, 4, 4);
    if (level <= 4)  return (6, 5, 7);
    if (level <= 6)  return (7, 5, 10);
    if (level <= 8)  return (7, 6, 14);
    if (level <= 10) return (8, 7, 18);
    if (level <= 13) return (9, 7, 22);
    if (level <= 16) return (10, 8, 28);
    if (level <= 20) return (11, 9, 35);
    if (level <= 25) return (12, 9, 42);
    if (level <= 30) return (13, 10, 50);
    if (level <= 40) return (14, 11, 60);
    return (15, 12, 70);
  }

  /// Generate a level. Returns the list of arrows and grid dimensions.
  ({List<Arrow> arrows, int rows, int cols}) generate(int levelNumber) {
    final (rows, cols, targetCount) = configForLevel(levelNumber);
    return _generateLevel(rows, cols, targetCount);
  }

  ({List<Arrow> arrows, int rows, int cols}) _generateLevel(
    int rows, int cols, int targetCount,
  ) {
    // We build the puzzle in "solution order": place arrows such that
    // arrow placed LAST can be safely removed FIRST, etc.
    // This guarantees at least one valid removal order exists.

    final arrows = <Arrow>[];
    final occupied = <(int, int)>{};
    var nextId = 0;

    // Place arrows one at a time. Each new arrow must NOT be blocked
    // by previously placed arrows (since previously placed arrows
    // will be removed AFTER this one in the solution).
    // Equivalently: the new arrow's flight path should be clear of
    // all SUBSEQUENTLY placed arrows, but we build in reverse, so
    // the new arrow's flight path must be clear of already-placed arrows.

    // Actually, let's think more carefully:
    // Solution order = [a1, a2, a3, ...] where a1 is tapped first.
    // When a1 is tapped, a2..aN are still on board. a1's path must NOT
    // hit any of a2..aN.
    // When a2 is tapped, a3..aN are still on board. a2's path must NOT
    // hit any of a3..aN.
    //
    // So we BUILD in reverse: place aN first (it can go anywhere),
    // then a(N-1) (its path must not hit aN), etc.
    // Arrow a1 (placed last) must have a clear path with respect to
    // all a2..aN (all previously placed arrows).

    for (var i = 0; i < targetCount; i++) {
      final arrow = _placeArrow(rows, cols, occupied, nextId);
      if (arrow == null) break; // Can't place more arrows
      arrows.add(arrow);
      occupied.add((arrow.row, arrow.col));
      nextId++;
    }

    // The solution order is the REVERSE of placement order.
    // arrows[0] should be tapped LAST, arrows[last] should be tapped FIRST.
    // But we don't need to reorder - the player discovers the order themselves.

    // Shuffle the arrow list so the solution isn't obvious from ordering.
    arrows.shuffle(_random);

    return (arrows: arrows, rows: rows, cols: cols);
  }

  /// Try to place one arrow that has a clear flight path
  /// (doesn't pass through any occupied cell).
  Arrow? _placeArrow(
    int rows, int cols, Set<(int, int)> occupied, int id,
  ) {
    // Collect all valid placements
    final candidates = <Arrow>[];

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (occupied.contains((r, c))) continue;

        for (final dir in Direction.values) {
          final arrow = Arrow(id: id, row: r, col: c, direction: dir);
          final path = arrow.flightPath(rows, cols);

          // Check that no occupied cell is in the flight path
          final blocked = path.any((p) => occupied.contains(p));
          if (!blocked) {
            candidates.add(arrow);
          }
        }
      }
    }

    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }
}
