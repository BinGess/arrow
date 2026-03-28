import 'dart:collection';
import '../models/puzzle_tile.dart';
import '../models/puzzle_level.dart';

/// Evaluates connectivity in the puzzle grid.
/// Determines which tiles are "active" (connected to the source).
class PuzzleSolver {
  /// Compute the set of connected tile positions starting from source tiles.
  /// Two adjacent tiles are connected if both have their open side facing
  /// each other at their current rotation.
  static Set<(int, int)> findConnectedTiles(PuzzleLevel level) {
    final connected = <(int, int)>{};
    final queue = Queue<(int, int)>();

    // Find all source tiles
    for (var r = 0; r < level.rows; r++) {
      for (var c = 0; c < level.cols; c++) {
        if (level.tileAt(r, c).isSource) {
          connected.add((r, c));
          queue.add((r, c));
        }
      }
    }

    // BFS flood fill
    while (queue.isNotEmpty) {
      final (cr, cc) = queue.removeFirst();
      final tile = level.tileAt(cr, cc);
      final openSides = tile.openSides;

      for (final dir in openSides) {
        final nr = cr + dir.dr;
        final nc = cc + dir.dc;

        if (!level.isInBounds(nr, nc)) continue;
        if (connected.contains((nr, nc))) continue;

        final neighbor = level.tileAt(nr, nc);
        final neighborOpen = neighbor.openSides;

        // Check if neighbor has an open side facing back toward us
        if (neighborOpen.contains(dir.opposite)) {
          // Check arrow constraints
          if (_arrowConstraintSatisfied(tile, dir) &&
              _arrowConstraintSatisfied(neighbor, dir.opposite)) {
            connected.add((nr, nc));
            queue.add((nr, nc));
          }
        }
      }
    }

    return connected;
  }

  /// Check if a tile's arrow constraint is satisfied for a given connection direction.
  static bool _arrowConstraintSatisfied(
      PuzzleTile tile, CardinalDirection connectionDir) {
    if (!tile.hasArrow || tile.arrowDirection == null) return true;
    // The arrow indicates a required flow direction on this tile.
    // The tile must have the arrow direction as one of its open sides.
    return tile.openSides.contains(tile.arrowDirection);
  }

  /// Check if the puzzle is solved:
  /// All tiles are connected (no loose ends in the current design).
  static bool isSolved(PuzzleLevel level) {
    final connected = findConnectedTiles(level);

    // Check all non-empty tiles are connected
    for (var r = 0; r < level.rows; r++) {
      for (var c = 0; c < level.cols; c++) {
        if (!connected.contains((r, c))) return false;
      }
    }

    return true;
  }

  /// Check if all tiles have matching connections (no dangling open sides
  /// that face out of bounds or toward a tile without a reciprocal opening).
  static bool hasNoLooseEnds(PuzzleLevel level) {
    for (var r = 0; r < level.rows; r++) {
      for (var c = 0; c < level.cols; c++) {
        final tile = level.tileAt(r, c);
        for (final dir in tile.openSides) {
          final nr = r + dir.dr;
          final nc = c + dir.dc;
          if (!level.isInBounds(nr, nc)) return false;
          final neighbor = level.tileAt(nr, nc);
          if (!neighbor.openSides.contains(dir.opposite)) return false;
        }
      }
    }
    return true;
  }
}
