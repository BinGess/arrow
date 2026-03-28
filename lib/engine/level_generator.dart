import 'dart:math';
import '../models/arrow.dart';
import 'level_validator.dart';

/// Generates solvable arrow-removal puzzle levels with guaranteed solutions.
///
/// Core algorithm: **Reverse-order placement**.
///
/// Arrows are placed one at a time. Each new arrow MUST have a clear
/// flight path (no collision with any already-placed arrow). This means
/// the reverse of placement order is always a valid removal sequence.
///
/// Difficulty levers:
///   1. **Minimum flight path**: arrows must have ≥ N cells ahead before
///      exiting the board. Prevents trivial edge-hugging free arrows.
///   2. **Blocking score**: prefer placements that block existing arrows.
///   3. **Flight path length bonus**: longer paths = more likely to be
///      blocked by future arrows = fewer "free at start" arrows.
///   4. **Direction diversity**: balanced distribution across 4 directions.
///   5. **Quality gates**: reject levels with too many free/head-only arrows.
class LevelGenerator {
  final int? _baseSeed;

  LevelGenerator({int? seed}) : _baseSeed = seed;

  /// Continuous difficulty interpolation — every level is unique.
  static ({
    int rows,
    int cols,
    int count,
    int maxTail,
    double lTailChance,
    int minFlightPath,  // arrows must have ≥ this many cells in flight path
    int minDepth,
    double maxFreeRatio, // max fraction of arrows free at start
    int lives,
  }) configForLevel(int level) {
    final t = ((level - 1) / 49.0).clamp(0.0, 1.0);

    final rows = (14 + t * 10).round();
    final cols = (11 + t * 7).round();
    final count = (50 + t * 130).round();
    final maxTail = (3 + t * 4).round();
    final lTailChance = 0.40 + t * 0.48;
    final minDepth = (3 + t * 12).round();
    final lives = (5 - t * 4).round().clamp(1, 5);

    // Minimum flight path length: 3 → 5
    // Prevents arrows from hugging edges and being trivially free.
    // On a 14x11 grid, min=3 means arrows can't point at an edge < 3 cells away.
    // On a 24x18 grid, min=5 is stricter — all arrows are deep inside.
    final minFlightPath = (3 + t * 2).round();

    // Max free arrows at start: 15% → 5%
    // Level 1: up to 15% can be free (some easy picks to get started)
    // Level 50: only 5% free (must search hard for valid first moves)
    final maxFreeRatio = 0.15 - t * 0.10;

    return (
      rows: rows,
      cols: cols,
      count: count,
      maxTail: maxTail,
      lTailChance: lTailChance,
      minFlightPath: minFlightPath,
      minDepth: minDepth,
      maxFreeRatio: maxFreeRatio,
      lives: lives,
    );
  }

  ({List<Arrow> arrows, int rows, int cols, int lives}) generate(int levelNumber) {
    final config = configForLevel(levelNumber);

    for (var attempt = 0; attempt < 20; attempt++) {
      final seed = _baseSeed ?? (levelNumber * 1000 + attempt * 7 + 42);
      final random = Random(seed + attempt);

      // Relax minFlightPath slightly on later attempts to avoid infinite loops
      final effectiveMinFlight = attempt < 10
          ? config.minFlightPath
          : max(2, config.minFlightPath - 1);

      final result = _generateLevel(
        rows: config.rows,
        cols: config.cols,
        targetCount: config.count,
        maxTail: config.maxTail,
        lTailChance: config.lTailChance,
        minFlightPath: effectiveMinFlight,
        random: random,
      );

      final arrows = result.arrows;
      if (arrows.length < 10) continue;

      // ── Quality gates ──
      final relaxed = attempt >= 15; // relax on late attempts

      // 1. Head-only ≤ 15%
      final headOnlyCount = arrows.where((a) => !a.hasTail).length;
      if (headOnlyCount / arrows.length > 0.15 && !relaxed) continue;

      // 2. Direction balance: no direction > 35%
      final dirCounts = <Direction, int>{};
      for (final a in arrows) {
        dirCounts[a.direction] = (dirCounts[a.direction] ?? 0) + 1;
      }
      final maxDirRatio = dirCounts.values.fold(0, max) / arrows.length;
      if (maxDirRatio > 0.35 && !relaxed) continue;

      // 3. Solvability
      if (!LevelValidator.isSolvable(arrows, result.rows, result.cols)) continue;

      final metrics = LevelValidator.analyzeMetrics(arrows, result.rows, result.cols);

      // 4. Free arrows at start ≤ maxFreeRatio
      final freeRatio = metrics.freeAtStart / arrows.length;
      if (freeRatio > config.maxFreeRatio && !relaxed) continue;

      // 5. Chain depth
      if (metrics.maxChainDepth < config.minDepth && attempt < 10) continue;

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
    required int minFlightPath,
    required Random random,
  }) {
    final placed = <Arrow>[];
    final occupied = <(int, int)>{};
    var nextId = 0;
    var headOnlyCount = 0;

    int headOnlyBudget(int total) => max(1, (total * 0.12).floor());

    for (var i = 0; i < targetCount; i++) {
      final progress = i / targetCount;

      // Every arrow attempts a tail.
      final budget = max(1, (maxTail * (1.0 - progress * 0.3)).round());
      final tailLen = 1 + random.nextInt(budget);
      final useLTail = tailLen >= 2 && random.nextDouble() < lTailChance;

      var arrow = _placeBestArrow(
        rows, cols, occupied, placed, nextId,
        tailLen, useLTail, minFlightPath, random,
      );

      // Progressive shortening — keep at least tail=1
      if (arrow == null && tailLen > 2) {
        for (var shorter = tailLen - 1; shorter >= 2; shorter--) {
          arrow = _placeBestArrow(
            rows, cols, occupied, placed, nextId,
            shorter, useLTail, minFlightPath, random,
          );
          if (arrow != null) break;
        }
      }
      if (arrow == null && tailLen > 1) {
        arrow = _placeBestArrow(
          rows, cols, occupied, placed, nextId,
          1, false, minFlightPath, random,
        );
      }

      // Head-only only if under budget
      if (arrow == null && headOnlyCount < headOnlyBudget(placed.length + 1)) {
        arrow = _placeBestArrow(
          rows, cols, occupied, placed, nextId,
          0, false, minFlightPath, random,
        );
        if (arrow != null) headOnlyCount++;
      }

      if (arrow == null) break;

      placed.add(arrow);
      occupied.addAll(arrow.occupiedCells);
      nextId++;
    }

    final arrows = List.of(placed)..shuffle(random);
    return (arrows: arrows, rows: rows, cols: cols);
  }

  /// Score-based placement:
  ///   blocking × 10  — how many existing arrows this placement blocks
  ///   flightLen × 3  — longer flight path = more likely blocked by future arrows
  ///   dirBonus × 8   — prefer underrepresented directions
  ///   randomness      — tie-breaker
  Arrow? _placeBestArrow(
    int rows, int cols, Set<(int, int)> occupied,
    List<Arrow> placed, int id, int tailLen, bool useLTail,
    int minFlightPath, Random random,
  ) {
    // Pre-compute
    final placedPaths = <int, Set<(int, int)>>{};
    for (final a in placed) {
      placedPaths[a.id] = a.flightPath(rows, cols).toSet();
    }

    final dirCount = <Direction, int>{
      for (final d in Direction.values) d: 0,
    };
    for (final a in placed) {
      dirCount[a.direction] = dirCount[a.direction]! + 1;
    }
    final maxDirCount = dirCount.values.fold(0, max);

    var bestArrow = <Arrow>[];
    var bestScore = -1;

    // Randomized cell order
    final cells = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (!occupied.contains((r, c))) cells.add((r, c));
      }
    }
    cells.shuffle(random);
    final maxCells = min(cells.length, 250);

    for (var ci = 0; ci < maxCells; ci++) {
      final (r, c) = cells[ci];

      for (final dir in Direction.values) {
        // ── Quick flight path length check BEFORE building tail options ──
        // Count how many cells from (r,c) in direction dir before hitting
        // the board edge. If < minFlightPath, skip this direction entirely.
        final flightLen = _flightPathLength(r, c, dir, rows, cols);
        if (flightLen < minFlightPath) continue;

        final tailOptions = _buildTailOptions(
          r, c, dir, tailLen, useLTail, rows, cols,
        );

        for (final segments in tailOptions) {
          final arrow = Arrow(
            id: id, row: r, col: c, direction: dir,
            tailSegments: segments,
          );

          final arrowCells = arrow.occupiedCells;

          if (!_allInBounds(arrowCells, rows, cols)) continue;
          if (arrowCells.any(occupied.contains)) continue;
          if (arrowCells.toSet().length != arrowCells.length) continue;

          // Flight path must be clear at placement time
          final path = arrow.flightPath(rows, cols);
          if (path.any(occupied.contains)) continue;

          // ── Scoring ──
          // 1. Blocking: body cells in existing arrows' flight paths
          final bodyCells = arrowCells.toSet();
          var blockCount = 0;
          for (final entry in placedPaths.entries) {
            if (bodyCells.any(entry.value.contains)) {
              blockCount++;
            }
          }

          // 2. Flight path length: longer = more likely to be blocked later
          //    This is the KEY fix — incentivizes interior placements with
          //    long paths that future arrows can cross.
          final flightBonus = path.length;

          // 3. Direction diversity
          final dirBonus = maxDirCount - dirCount[dir]!;

          final score = blockCount * 10 + flightBonus * 3 + dirBonus * 8 + random.nextInt(5);

          if (score > bestScore) {
            bestScore = score;
            bestArrow = [arrow];
          } else if (score == bestScore) {
            bestArrow.add(arrow);
          }
        }
      }
    }

    // Overflow search for head-only if sampling missed
    if (bestArrow.isEmpty && maxCells < cells.length && tailLen == 0) {
      for (var ci = maxCells; ci < cells.length; ci++) {
        final (r, c) = cells[ci];
        for (final dir in Direction.values) {
          if (_flightPathLength(r, c, dir, rows, cols) < minFlightPath) continue;
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

  /// Count cells in flight path (from head in direction to edge).
  int _flightPathLength(int row, int col, Direction dir, int rows, int cols) {
    switch (dir) {
      case Direction.up:    return row;
      case Direction.down:  return rows - 1 - row;
      case Direction.left:  return col;
      case Direction.right: return cols - 1 - col;
    }
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
            if (_flightPathLength(r, c, dir, rows, cols) < 3) continue;
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
