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
  static ({
    int rows,
    int cols,
    int count,
    int maxTail,
    double lTailChance,
    int minDepth,
    int lives,
  }) configForLevel(int level) {
    final t = ((level - 1) / 49.0).clamp(0.0, 1.0);

    // Grid size: 14x11 → 24x18
    final rows = (14 + t * 10).round();
    final cols = (11 + t * 7).round();

    // Arrow count: 50 → 180
    final count = (50 + t * 130).round();

    // Max tail length: 3 → 7
    final maxTail = (3 + t * 4).round();

    // L-tail chance among tailed arrows: 0.40 → 0.88
    final lTailChance = 0.40 + t * 0.48;

    // Min chain depth: 3 → 15
    final minDepth = (3 + t * 12).round();

    // Lives: 5 → 1
    final lives = (5 - t * 4).round().clamp(1, 5);

    return (
      rows: rows,
      cols: cols,
      count: count,
      maxTail: maxTail,
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

    for (var attempt = 0; attempt < 15; attempt++) {
      final seed = _baseSeed ?? (levelNumber * 1000 + attempt * 7 + 42);
      final random = Random(seed + attempt);
      final result = _generateLevel(
        rows: config.rows,
        cols: config.cols,
        targetCount: config.count,
        maxTail: config.maxTail,
        lTailChance: config.lTailChance,
        random: random,
      );

      final arrows = result.arrows;
      if (arrows.isEmpty) continue;

      // ── Quality gates ──
      // 1. Head-only arrows must be ≤ 15% of total
      final headOnlyCount = arrows.where((a) => !a.hasTail).length;
      final headOnlyRatio = headOnlyCount / arrows.length;
      if (headOnlyRatio > 0.15 && attempt < 12) continue;

      // 2. No single direction may exceed 35% of total
      final dirCounts = <Direction, int>{};
      for (final a in arrows) {
        dirCounts[a.direction] = (dirCounts[a.direction] ?? 0) + 1;
      }
      final maxDirRatio = dirCounts.values.fold(0, max) / arrows.length;
      if (maxDirRatio > 0.35 && attempt < 12) continue;

      // 3. Solvability
      if (!LevelValidator.isSolvable(arrows, result.rows, result.cols)) continue;

      // 4. Chain depth (soft: relax after enough attempts)
      if (attempt < 7) {
        final metrics = LevelValidator.analyzeMetrics(arrows, result.rows, result.cols);
        if (metrics.maxChainDepth < config.minDepth) continue;
      }

      return (arrows: arrows, rows: result.rows, cols: result.cols, lives: config.lives);
    }

    // Fallback
    final fallbackRandom = Random(_baseSeed ?? (levelNumber * 1000 + 99));
    final fallback = _generateSimple(config.rows, config.cols, config.count, fallbackRandom);
    return (arrows: fallback.arrows, rows: fallback.rows, cols: fallback.cols, lives: config.lives);
  }

  ({List<Arrow> arrows, int rows, int cols}) _generateLevel({
    required int rows,
    required int cols,
    required int targetCount,
    required int maxTail,
    required double lTailChance,
    required Random random,
  }) {
    final placed = <Arrow>[];
    final occupied = <(int, int)>{};
    var nextId = 0;
    var headOnlyCount = 0;

    // Hard cap: at most 15% of placed arrows can be head-only.
    int headOnlyBudget(int total) => max(1, (total * 0.15).floor());

    for (var i = 0; i < targetCount; i++) {
      final progress = i / targetCount;

      // Every arrow attempts a tail. No random tailChance —
      // head-only is ONLY allowed as a last resort when nothing else fits.
      final budget = max(1, (maxTail * (1.0 - progress * 0.3)).round());
      final tailLen = 1 + random.nextInt(budget);
      final useLTail = tailLen >= 2 && random.nextDouble() < lTailChance;

      var arrow = _placeBestArrow(
        rows, cols, occupied, placed, nextId, tailLen, useLTail, random,
      );

      // Progressive shortening — try to keep at least tail=1
      if (arrow == null && tailLen > 2) {
        for (var shorter = tailLen - 1; shorter >= 2; shorter--) {
          arrow = _placeBestArrow(
            rows, cols, occupied, placed, nextId, shorter, useLTail, random,
          );
          if (arrow != null) break;
        }
      }
      if (arrow == null && tailLen > 1) {
        arrow = _placeBestArrow(
          rows, cols, occupied, placed, nextId, 1, false, random,
        );
      }

      // Head-only only if under budget
      if (arrow == null && headOnlyCount < headOnlyBudget(placed.length + 1)) {
        arrow = _placeBestArrow(
          rows, cols, occupied, placed, nextId, 0, false, random,
        );
        if (arrow != null) headOnlyCount++;
      }

      if (arrow == null) break; // Board full

      if (!arrow.hasTail && arrow.tailSegments.isEmpty) {
        // Track (redundant with above but defensive)
      }

      placed.add(arrow);
      occupied.addAll(arrow.occupiedCells);
      nextId++;
    }

    final arrows = List.of(placed)..shuffle(random);
    return (arrows: arrows, rows: rows, cols: cols);
  }

  /// Find the best arrow placement.
  /// Scoring: blocking × 10 + direction_diversity × 8 + randomness
  Arrow? _placeBestArrow(
    int rows, int cols, Set<(int, int)> occupied,
    List<Arrow> placed, int id, int tailLen, bool useLTail, Random random,
  ) {
    // Pre-compute flight paths of all placed arrows for blocking score
    final placedPaths = <int, Set<(int, int)>>{};
    for (final a in placed) {
      placedPaths[a.id] = a.flightPath(rows, cols).toSet();
    }

    // Direction balance
    final dirCount = <Direction, int>{
      for (final d in Direction.values) d: 0,
    };
    for (final a in placed) {
      dirCount[a.direction] = dirCount[a.direction]! + 1;
    }
    final maxDirCount = dirCount.values.fold(0, max);

    var bestArrow = <Arrow>[];
    var bestScore = -1;

    // Randomized cell order to avoid spatial bias
    final cells = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (!occupied.contains((r, c))) cells.add((r, c));
      }
    }
    cells.shuffle(random);

    // For large boards, sample a subset of cells to keep generation fast
    final maxCells = min(cells.length, 200);

    for (var ci = 0; ci < maxCells; ci++) {
      final (r, c) = cells[ci];

      for (final dir in Direction.values) {
        final tailOptions = _buildTailOptions(
          r, c, dir, tailLen, useLTail, rows, cols,
        );

        for (final segments in tailOptions) {
          final arrow = Arrow(
            id: id, row: r, col: c, direction: dir,
            tailSegments: segments,
          );

          final arrowCells = arrow.occupiedCells;

          // Bounds check
          if (!_allInBounds(arrowCells, rows, cols)) continue;
          // No overlap with existing arrows
          if (arrowCells.any(occupied.contains)) continue;
          // No self-overlap
          if (arrowCells.toSet().length != arrowCells.length) continue;

          // Flight path must be clear
          final path = arrow.flightPath(rows, cols);
          if (path.any(occupied.contains)) continue;

          // Blocking score
          final bodyCells = arrowCells.toSet();
          var blockCount = 0;
          for (final entry in placedPaths.entries) {
            if (bodyCells.any(entry.value.contains)) {
              blockCount++;
            }
          }

          // Direction diversity bonus (strong weight)
          final dirBonus = maxDirCount - dirCount[dir]!;

          // Combined score: blocking and direction diversity are equally important
          final score = blockCount * 10 + dirBonus * 8 + random.nextInt(5);

          if (score > bestScore) {
            bestScore = score;
            bestArrow = [arrow];
          } else if (score == bestScore) {
            bestArrow.add(arrow);
          }
        }
      }
    }

    // If sampling missed valid placements, try remaining cells with tail=0 check
    if (bestArrow.isEmpty && maxCells < cells.length && tailLen == 0) {
      for (var ci = maxCells; ci < cells.length; ci++) {
        final (r, c) = cells[ci];
        for (final dir in Direction.values) {
          final arrow = Arrow(id: id, row: r, col: c, direction: dir);
          final path = arrow.flightPath(rows, cols);
          if (!path.any(occupied.contains)) {
            bestArrow.add(arrow);
          }
        }
      }
    }

    if (bestArrow.isEmpty) return null;
    return bestArrow[random.nextInt(bestArrow.length)];
  }

  /// Simple fallback generator.
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
