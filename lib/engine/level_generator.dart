import 'dart:math';
import '../models/arrow.dart';

/// Generates challenging arrow-removal puzzle levels.
///
/// Uses a wave-based placement strategy to create deep dependency chains:
/// - Wave 0: Place arrows that must be removed LAST (they block nothing)
/// - Wave 1: Place arrows blocked by Wave 0 (must remove Wave 0 first)
/// - Wave 2: Place arrows blocked by Wave 1 ...
/// - Wave N: Only these arrows are initially free to remove
///
/// More waves = deeper chains = harder puzzle.
/// Only the final wave arrows can be tapped first.
class LevelGenerator {
  final Random _random;

  LevelGenerator({int? seed}) : _random = Random(seed);

  static ({
    int rows,
    int cols,
    int count,
    int maxTail,
    bool lTails,
    int waves,
    double density,
  }) configForLevel(int level) {
    if (level <= 2) {
      return (rows: 5, cols: 4, count: 5, maxTail: 0, lTails: false, waves: 2, density: 0.25);
    }
    if (level <= 4) {
      return (rows: 6, cols: 5, count: 8, maxTail: 1, lTails: false, waves: 3, density: 0.27);
    }
    if (level <= 6) {
      return (rows: 7, cols: 5, count: 11, maxTail: 2, lTails: false, waves: 3, density: 0.31);
    }
    if (level <= 8) {
      return (rows: 7, cols: 6, count: 14, maxTail: 2, lTails: false, waves: 4, density: 0.33);
    }
    if (level <= 10) {
      return (rows: 8, cols: 7, count: 20, maxTail: 3, lTails: true, waves: 5, density: 0.36);
    }
    if (level <= 13) {
      return (rows: 9, cols: 7, count: 24, maxTail: 3, lTails: true, waves: 6, density: 0.38);
    }
    if (level <= 16) {
      return (rows: 10, cols: 8, count: 30, maxTail: 4, lTails: true, waves: 7, density: 0.38);
    }
    if (level <= 20) {
      return (rows: 11, cols: 9, count: 38, maxTail: 5, lTails: true, waves: 8, density: 0.38);
    }
    if (level <= 25) {
      return (rows: 12, cols: 9, count: 44, maxTail: 5, lTails: true, waves: 9, density: 0.41);
    }
    if (level <= 30) {
      return (rows: 13, cols: 10, count: 52, maxTail: 6, lTails: true, waves: 10, density: 0.40);
    }
    if (level <= 40) {
      return (rows: 14, cols: 11, count: 60, maxTail: 6, lTails: true, waves: 11, density: 0.39);
    }
    return (rows: 15, cols: 12, count: 70, maxTail: 7, lTails: true, waves: 12, density: 0.39);
  }

  ({List<Arrow> arrows, int rows, int cols}) generate(int levelNumber) {
    final config = configForLevel(levelNumber);
    // Retry a few times if generation fails to reach target count
    for (var attempt = 0; attempt < 5; attempt++) {
      final result = _generateWaveBased(
        config.rows,
        config.cols,
        config.count,
        config.maxTail,
        config.lTails,
        config.waves,
      );
      if (result.arrows.length >= config.count * 0.7) return result;
    }
    return _generateWaveBased(
      config.rows, config.cols, config.count,
      config.maxTail, config.lTails, config.waves,
    );
  }

  ({List<Arrow> arrows, int rows, int cols}) _generateWaveBased(
    int rows, int cols, int targetCount,
    int maxTail, bool allowLTails, int totalWaves,
  ) {
    final allArrows = <Arrow>[];
    final occupied = <(int, int)>{};
    var nextId = 0;

    // Distribute arrows across waves.
    // Earlier waves (removed last) get more arrows.
    // Later waves (removed first) get fewer → fewer initial choices.
    final waveCounts = _distributeAcrossWaves(targetCount, totalWaves);

    for (var wave = 0; wave < totalWaves; wave++) {
      final waveTarget = waveCounts[wave];
      final arrowsThisWave = <Arrow>[];

      // Arrows in this wave must have their flight path BLOCKED by
      // at least one arrow from a PREVIOUS wave (wave-1, wave-2, etc.)
      // Exception: wave 0 arrows just need clear flight paths (removed last).
      final isFirstWave = wave == 0;

      for (var i = 0; i < waveTarget; i++) {
        // Higher waves get longer tails (more blocking)
        final tailBudget = maxTail > 0
            ? min(maxTail, 1 + (wave * maxTail ~/ totalWaves))
            : 0;
        final tailLen = tailBudget > 0 ? _random.nextInt(tailBudget + 1) : 0;
        final useLTail = allowLTails && tailLen >= 2 && _random.nextBool();

        final arrow = isFirstWave
            ? _placeArrowClearPath(rows, cols, occupied, nextId, tailLen, useLTail)
            : _placeArrowBlockedBy(rows, cols, occupied, allArrows, nextId, tailLen, useLTail);

        if (arrow == null) continue;

        arrowsThisWave.add(arrow);
        allArrows.add(arrow);
        occupied.addAll(arrow.occupiedCells);
        nextId++;
      }
    }

    // Shuffle so wave order isn't visible to the player
    allArrows.shuffle(_random);
    return (arrows: allArrows, rows: rows, cols: cols);
  }

  /// Distribute [total] arrows across [waves].
  /// Later waves (removed first by player) get fewer arrows.
  List<int> _distributeAcrossWaves(int total, int waves) {
    if (waves <= 1) return [total];

    // Weight: earlier waves get more arrows
    // wave 0 weight = waves, wave 1 = waves-1, ..., wave N-1 = 1
    final weights = List.generate(waves, (i) => waves - i);
    final totalWeight = weights.fold(0, (s, w) => s + w);

    final counts = <int>[];
    var remaining = total;
    for (var i = 0; i < waves; i++) {
      if (i == waves - 1) {
        // Last wave gets whatever remains (at least 1)
        counts.add(max(1, remaining));
      } else {
        final count = max(1, (total * weights[i] / totalWeight).round());
        counts.add(min(count, remaining - (waves - i - 1)));
        remaining -= counts.last;
      }
    }
    return counts;
  }

  /// Place an arrow with a completely clear flight path.
  /// Used for wave 0 (these arrows are removed last).
  Arrow? _placeArrowClearPath(
    int rows, int cols, Set<(int, int)> occupied,
    int id, int tailLen, bool useLTail,
  ) {
    final candidates = _findCandidates(
      rows, cols, occupied, id, tailLen, useLTail,
      requireBlocked: false,
      existingArrows: const [],
    );
    if (candidates.isEmpty) {
      if (tailLen > 0) return _placeArrowClearPath(rows, cols, occupied, id, 0, false);
      return null;
    }
    return candidates[_random.nextInt(candidates.length)];
  }

  /// Place an arrow whose flight path is BLOCKED by at least one existing arrow.
  /// This creates a dependency: the blocking arrow must be removed first.
  Arrow? _placeArrowBlockedBy(
    int rows, int cols, Set<(int, int)> occupied,
    List<Arrow> existingArrows, int id, int tailLen, bool useLTail,
  ) {
    final candidates = _findCandidates(
      rows, cols, occupied, id, tailLen, useLTail,
      requireBlocked: true,
      existingArrows: existingArrows,
    );
    if (candidates.isEmpty) {
      // Try with shorter tail
      if (tailLen > 0) {
        return _placeArrowBlockedBy(rows, cols, occupied, existingArrows, id, 0, false);
      }
      // Fall back to clear path (still adds an arrow)
      return _placeArrowClearPath(rows, cols, occupied, id, 0, false);
    }
    return candidates[_random.nextInt(min(candidates.length, 8))];
  }

  /// Find valid arrow placements.
  List<Arrow> _findCandidates(
    int rows, int cols, Set<(int, int)> occupied,
    int id, int tailLen, bool useLTail, {
    required bool requireBlocked,
    required List<Arrow> existingArrows,
  }) {
    final candidates = <Arrow>[];
    final existingOccupied = <(int, int)>{};
    for (final a in existingArrows) {
      existingOccupied.addAll(a.occupiedCells);
    }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (occupied.contains((r, c))) continue;

        for (final dir in Direction.values) {
          final tailOptions = _buildTailOptions(r, c, dir, tailLen, useLTail, rows, cols);

          for (final segments in tailOptions) {
            final arrow = Arrow(
              id: id, row: r, col: c, direction: dir,
              tailSegments: segments,
            );

            final cells = arrow.occupiedCells;
            if (!_allInBounds(cells, rows, cols)) continue;
            if (cells.any(occupied.contains)) continue;
            if (cells.toSet().length != cells.length) continue;

            final path = arrow.flightPath(rows, cols);

            if (requireBlocked) {
              // Flight path must hit at least one existing arrow's cell
              final hitsExisting = path.any(existingOccupied.contains);
              if (!hitsExisting) continue;
            } else {
              // Flight path must be completely clear
              if (path.any(occupied.contains)) continue;
            }

            candidates.add(arrow);
          }
        }
      }
    }
    return candidates;
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
    return cells.every((c) => c.$1 >= 0 && c.$1 < rows && c.$2 >= 0 && c.$2 < cols);
  }
}
