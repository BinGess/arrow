import 'dart:math';
import '../models/arrow.dart';
import 'level_validator.dart';

/// Generates solvable arrow-removal puzzle levels with guaranteed solutions.
///
/// Core algorithm: **Reverse-order placement**.
///
/// Arrows are placed one at a time. Each new arrow MUST have a clear
/// flight path (no collision with any already-placed arrow). This means
/// the reverse of placement order is always a valid removal sequence:
/// the last-placed arrow can always fly out first, then the second-to-last, etc.
///
/// To maximize difficulty, we SCORE each candidate placement by how many
/// already-placed arrows it BLOCKS (its body occupies cells in their flight
/// paths). More blocking = harder puzzle = deeper dependency chains.
class LevelGenerator {
  final Random _random;

  LevelGenerator({int? seed}) : _random = Random(seed);

  static ({
    int rows,
    int cols,
    int count,
    int maxTail,
    bool lTails,
    double lTailChance, // probability of L-shaped tail when eligible
    int minDepth,
  }) configForLevel(int level) {
    // More arrows, more tails, more L-shapes at every tier
    if (level <= 2) {
      return (rows: 6, cols: 5, count: 8, maxTail: 1, lTails: false, lTailChance: 0.0, minDepth: 2);
    }
    if (level <= 4) {
      return (rows: 7, cols: 6, count: 14, maxTail: 2, lTails: true, lTailChance: 0.3, minDepth: 3);
    }
    if (level <= 6) {
      return (rows: 8, cols: 6, count: 18, maxTail: 3, lTails: true, lTailChance: 0.4, minDepth: 4);
    }
    if (level <= 8) {
      return (rows: 9, cols: 7, count: 24, maxTail: 3, lTails: true, lTailChance: 0.45, minDepth: 5);
    }
    if (level <= 10) {
      return (rows: 10, cols: 8, count: 30, maxTail: 4, lTails: true, lTailChance: 0.5, minDepth: 6);
    }
    if (level <= 13) {
      return (rows: 11, cols: 8, count: 36, maxTail: 4, lTails: true, lTailChance: 0.55, minDepth: 7);
    }
    if (level <= 16) {
      return (rows: 12, cols: 9, count: 44, maxTail: 5, lTails: true, lTailChance: 0.55, minDepth: 8);
    }
    if (level <= 20) {
      return (rows: 13, cols: 10, count: 52, maxTail: 5, lTails: true, lTailChance: 0.6, minDepth: 9);
    }
    if (level <= 25) {
      return (rows: 14, cols: 10, count: 60, maxTail: 6, lTails: true, lTailChance: 0.6, minDepth: 10);
    }
    if (level <= 30) {
      return (rows: 14, cols: 11, count: 68, maxTail: 6, lTails: true, lTailChance: 0.65, minDepth: 11);
    }
    if (level <= 40) {
      return (rows: 15, cols: 12, count: 78, maxTail: 7, lTails: true, lTailChance: 0.65, minDepth: 12);
    }
    return (rows: 16, cols: 13, count: 90, maxTail: 8, lTails: true, lTailChance: 0.7, minDepth: 13);
  }

  /// Generate a validated, solvable level.
  ({List<Arrow> arrows, int rows, int cols}) generate(int levelNumber) {
    final config = configForLevel(levelNumber);

    for (var attempt = 0; attempt < 10; attempt++) {
      final result = _generateLevel(
        config.rows, config.cols, config.count,
        config.maxTail, config.lTails, config.lTailChance, config.minDepth,
      );

      // Validate solvability
      if (LevelValidator.isSolvable(result.arrows, result.rows, result.cols)) {
        final metrics = LevelValidator.analyzeMetrics(
          result.arrows, result.rows, result.cols,
        );

        // Check difficulty meets minimum requirements
        if (metrics.maxChainDepth >= config.minDepth ||
            attempt >= 7) {
          return result;
        }
        // Not challenging enough, regenerate
        continue;
      }
      // Not solvable (shouldn't happen with reverse-order, but safety net)
    }

    // Fallback: generate a simple guaranteed-solvable level
    return _generateSimple(config.rows, config.cols, config.count);
  }

  ({List<Arrow> arrows, int rows, int cols}) _generateLevel(
    int rows, int cols, int targetCount,
    int maxTail, bool allowLTails, double lTailChance, int minDepth,
  ) {
    final placed = <Arrow>[]; // Placement order (reverse of solution)
    final occupied = <(int, int)>{};
    var nextId = 0;

    for (var i = 0; i < targetCount; i++) {
      // Earlier placements (removed last) get longer tails to block more.
      final progress = i / targetCount;
      // Guarantee a minimum tail length for most arrows
      final tailBudget = maxTail > 0
          ? max(1, (maxTail * (1.0 - progress * 0.5)).round())
          : 0;
      // Higher minimum tail: at least 1 for early arrows, scaling down
      final minTail = maxTail > 0 ? max(0, (tailBudget * 0.5).round()) : 0;
      final tailLen = tailBudget > 0
          ? minTail + _random.nextInt(tailBudget - minTail + 1)
          : 0;
      final useLTail = allowLTails && tailLen >= 2 &&
          _random.nextDouble() < lTailChance;

      final arrow = _placeBestArrow(
        rows, cols, occupied, placed, nextId, tailLen, useLTail,
      );

      if (arrow == null) {
        // Try without tail
        if (tailLen > 0) {
          final fallback = _placeBestArrow(
            rows, cols, occupied, placed, nextId, 0, false,
          );
          if (fallback != null) {
            placed.add(fallback);
            occupied.addAll(fallback.occupiedCells);
            nextId++;
            continue;
          }
        }
        break; // Board is full
      }

      placed.add(arrow);
      occupied.addAll(arrow.occupiedCells);
      nextId++;
    }

    // Shuffle so the player can't guess the solution from list order
    final arrows = List.of(placed)..shuffle(_random);
    return (arrows: arrows, rows: rows, cols: cols);
  }

  /// Find the best arrow placement that:
  /// 1. Has a clear flight path (REQUIRED for solvability)
  /// 2. Maximizes blocking of already-placed arrows (for difficulty)
  Arrow? _placeBestArrow(
    int rows, int cols, Set<(int, int)> occupied,
    List<Arrow> placed, int id, int tailLen, bool useLTail,
  ) {
    // Pre-compute flight paths of all placed arrows for scoring
    final placedPaths = <int, Set<(int, int)>>{};
    for (final a in placed) {
      placedPaths[a.id] = a.flightPath(rows, cols).toSet();
    }

    var bestArrow = <Arrow>[];
    var bestScore = -1;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (occupied.contains((r, c))) continue;

        for (final dir in Direction.values) {
          final tailOptions = _buildTailOptions(
            r, c, dir, tailLen, useLTail, rows, cols,
          );

          for (final segments in tailOptions) {
            final arrow = Arrow(
              id: id, row: r, col: c, direction: dir,
              tailSegments: segments,
            );

            final cells = arrow.occupiedCells;

            // Bounds check
            if (!_allInBounds(cells, rows, cols)) continue;
            // No overlap with existing arrows
            if (cells.any(occupied.contains)) continue;
            // No self-overlap
            if (cells.toSet().length != cells.length) continue;

            // CRITICAL: Flight path must be clear of ALL placed arrows.
            // This guarantees this arrow can be removed after all
            // subsequently-placed arrows are gone.
            final path = arrow.flightPath(rows, cols);
            if (path.any(occupied.contains)) continue;

            // Score: how many placed arrows does this new arrow BLOCK?
            // (its body cells appear in their flight paths)
            final bodyCells = cells.toSet();
            var score = 0;
            for (final entry in placedPaths.entries) {
              if (bodyCells.any(entry.value.contains)) {
                score++;
              }
            }

            // Add randomness to avoid identical puzzles
            score = score * 10 + _random.nextInt(5);

            if (score > bestScore) {
              bestScore = score;
              bestArrow = [arrow];
            } else if (score == bestScore) {
              bestArrow.add(arrow);
            }
          }
        }
      }
    }

    if (bestArrow.isEmpty) return null;

    // Pick randomly among the best candidates
    return bestArrow[_random.nextInt(bestArrow.length)];
  }

  /// Simple fallback generator (always solvable, easier).
  ({List<Arrow> arrows, int rows, int cols}) _generateSimple(
    int rows, int cols, int targetCount,
  ) {
    final arrows = <Arrow>[];
    final occupied = <(int, int)>{};
    var nextId = 0;

    for (var i = 0; i < targetCount; i++) {
      final candidates = <Arrow>[];
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (occupied.contains((r, c))) continue;
          for (final dir in Direction.values) {
            final arrow = Arrow(id: nextId, row: r, col: c, direction: dir);
            final path = arrow.flightPath(rows, cols);
            if (!path.any(occupied.contains)) {
              candidates.add(arrow);
            }
          }
        }
      }
      if (candidates.isEmpty) break;
      final arrow = candidates[_random.nextInt(candidates.length)];
      arrows.add(arrow);
      occupied.add((arrow.row, arrow.col));
      nextId++;
    }

    arrows.shuffle(_random);
    return (arrows: arrows, rows: rows, cols: cols);
  }

  List<List<TailSegment>> _buildTailOptions(
    int headRow, int headCol, Direction arrowDir,
    int tailLen, bool useLTail, int rows, int cols,
  ) {
    if (tailLen == 0) return [[]];

    final options = <List<TailSegment>>[];
    final straightDir = arrowDir.opposite;

    // Straight tail
    options.add([TailSegment(direction: straightDir, length: tailLen)]);

    // L-shaped tails
    if (useLTail && tailLen >= 2) {
      for (final perpDir in arrowDir.perpendicular) {
        for (var firstLen = 1; firstLen < tailLen; firstLen++) {
          final secondLen = tailLen - firstLen;
          options.add([
            TailSegment(direction: straightDir, length: firstLen),
            TailSegment(direction: perpDir, length: secondLen),
          ]);
        }
      }
    }

    return options;
  }

  bool _allInBounds(List<(int, int)> cells, int rows, int cols) {
    return cells.every(
        (c) => c.$1 >= 0 && c.$1 < rows && c.$2 >= 0 && c.$2 < cols);
  }
}
