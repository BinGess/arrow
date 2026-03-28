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
///
/// Each level uses a deterministic seed (based on level number) so the
/// same level always produces the same puzzle layout.
class LevelGenerator {
  final int? _baseSeed;

  LevelGenerator({int? seed}) : _baseSeed = seed;

  /// Continuous difficulty interpolation.
  ///
  /// Every single level is unique — no two adjacent levels share the same
  /// config. Parameters are linearly interpolated from Level 1 → Level 50.
  ///
  /// Key insight: maxTail is kept moderate (3→7) so arrows don't hog too
  /// many cells. Instead, difficulty comes from:
  ///   - More arrows (denser board)
  ///   - Higher tailChance (% of arrows that have tails at all)
  ///   - Higher lTailChance (% of tailed arrows that are L-shaped)
  ///   - Deeper required chain depth
  ///   - Fewer lives
  static ({
    int rows,
    int cols,
    int count,
    int maxTail,
    double tailChance,  // probability an arrow gets a tail (vs head-only)
    double lTailChance, // probability a tailed arrow is L-shaped
    int minDepth,
    int lives,
  }) configForLevel(int level) {
    final t = ((level - 1) / 49.0).clamp(0.0, 1.0);

    // Grid size: 14x11 → 24x18
    final rows = (14 + t * 10).round();
    final cols = (11 + t * 7).round();

    // Arrow count: 50 → 180
    // With moderate tails + head-only mix, the board can actually fit these.
    // Head-only arrows occupy 1 cell; avg tailed arrow ~3-4 cells.
    // At t=1: 432 cells, ~60% tailed with avg 4 cells + ~40% head-only:
    //   180 * 0.6 * 4 + 180 * 0.4 * 1 = 432 + 72 = 504 → generator stops
    //   when board is full, so actual count will be ~130-150. That's fine.
    final count = (50 + t * 130).round();

    // Max tail length: 3 → 7 (moderate — don't hog too many cells)
    final maxTail = (3 + t * 4).round();

    // Tail chance: 0.45 → 0.92 (early levels have many head-only arrows)
    final tailChance = 0.45 + t * 0.47;

    // L-tail chance: 0.35 → 0.88
    final lTailChance = 0.35 + t * 0.53;

    // Min chain depth: 3 → 15
    final minDepth = (3 + t * 12).round();

    // Lives: 5 → 1
    final lives = (5 - t * 4).round().clamp(1, 5);

    return (
      rows: rows,
      cols: cols,
      count: count,
      maxTail: maxTail,
      tailChance: tailChance,
      lTailChance: lTailChance,
      minDepth: minDepth,
      lives: lives,
    );
  }

  /// Generate a validated, solvable level.
  ///
  /// Uses a deterministic seed per level so the same level number
  /// always produces the same puzzle layout.
  ({List<Arrow> arrows, int rows, int cols, int lives}) generate(int levelNumber) {
    final config = configForLevel(levelNumber);

    for (var attempt = 0; attempt < 10; attempt++) {
      // Deterministic seed: same level + attempt always gives same puzzle
      final seed = _baseSeed ?? (levelNumber * 1000 + attempt * 7 + 42);
      final random = Random(seed + attempt);
      final result = _generateLevel(
        rows: config.rows,
        cols: config.cols,
        targetCount: config.count,
        maxTail: config.maxTail,
        tailChance: config.tailChance,
        lTailChance: config.lTailChance,
        random: random,
      );

      // Validate solvability
      if (LevelValidator.isSolvable(result.arrows, result.rows, result.cols)) {
        final metrics = LevelValidator.analyzeMetrics(
          result.arrows, result.rows, result.cols,
        );

        // Check difficulty meets minimum requirements
        if (metrics.maxChainDepth >= config.minDepth ||
            attempt >= 7) {
          return (arrows: result.arrows, rows: result.rows, cols: result.cols, lives: config.lives);
        }
        // Not challenging enough, regenerate
        continue;
      }
      // Not solvable (shouldn't happen with reverse-order, but safety net)
    }

    // Fallback: generate a simple guaranteed-solvable level
    final fallbackRandom = Random(_baseSeed ?? (levelNumber * 1000 + 99));
    final fallback = _generateSimple(config.rows, config.cols, config.count, fallbackRandom);
    return (arrows: fallback.arrows, rows: fallback.rows, cols: fallback.cols, lives: config.lives);
  }

  ({List<Arrow> arrows, int rows, int cols}) _generateLevel({
    required int rows,
    required int cols,
    required int targetCount,
    required int maxTail,
    required double tailChance,
    required double lTailChance,
    required Random random,
  }) {
    final placed = <Arrow>[]; // Placement order (reverse of solution)
    final occupied = <(int, int)>{};
    var nextId = 0;

    for (var i = 0; i < targetCount; i++) {
      final progress = i / targetCount;

      // Decide: does this arrow get a tail?
      // Early-placed arrows (removed last) are more likely to have tails
      // because they serve as blockers. Late-placed arrows can be head-only.
      final hasTail = random.nextDouble() < tailChance * (1.0 - progress * 0.3);

      int tailLen;
      if (!hasTail || maxTail == 0) {
        tailLen = 0;
      } else {
        // Tail length: 1 to maxTail, biased longer for early placements
        final budget = max(1, (maxTail * (1.0 - progress * 0.4)).round());
        tailLen = 1 + random.nextInt(budget);
      }

      final useLTail = tailLen >= 2 && random.nextDouble() < lTailChance;

      final arrow = _placeBestArrow(
        rows, cols, occupied, placed, nextId, tailLen, useLTail, random,
      );

      if (arrow == null) {
        // Try shorter tail
        if (tailLen > 1) {
          final shorter = _placeBestArrow(
            rows, cols, occupied, placed, nextId, 1, false, random,
          );
          if (shorter != null) {
            placed.add(shorter);
            occupied.addAll(shorter.occupiedCells);
            nextId++;
            continue;
          }
        }
        // Try head-only
        if (tailLen > 0) {
          final headOnly = _placeBestArrow(
            rows, cols, occupied, placed, nextId, 0, false, random,
          );
          if (headOnly != null) {
            placed.add(headOnly);
            occupied.addAll(headOnly.occupiedCells);
            nextId++;
            continue;
          }
        }
        break; // Board is truly full
      }

      placed.add(arrow);
      occupied.addAll(arrow.occupiedCells);
      nextId++;
    }

    // Shuffle so the player can't guess the solution from list order
    final arrows = List.of(placed)..shuffle(random);
    return (arrows: arrows, rows: rows, cols: cols);
  }

  /// Find the best arrow placement that:
  /// 1. Has a clear flight path (REQUIRED for solvability)
  /// 2. Maximizes blocking of already-placed arrows (for difficulty)
  Arrow? _placeBestArrow(
    int rows, int cols, Set<(int, int)> occupied,
    List<Arrow> placed, int id, int tailLen, bool useLTail, Random random,
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
            score = score * 10 + random.nextInt(5);

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
    return bestArrow[random.nextInt(bestArrow.length)];
  }

  /// Simple fallback generator (always solvable, easier).
  ({List<Arrow> arrows, int rows, int cols}) _generateSimple(
    int rows, int cols, int targetCount, Random random,
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
      final arrow = candidates[random.nextInt(candidates.length)];
      arrows.add(arrow);
      occupied.add((arrow.row, arrow.col));
      nextId++;
    }

    arrows.shuffle(random);
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
