import 'dart:math';
import '../models/arrow.dart';

/// Generates solvable arrow-removal puzzle levels with tails.
///
/// Strategy: Place arrows one by one in reverse-removal order.
/// Each new arrow must have a clear flight path over all previously
/// placed arrows. The player discovers the correct order by reversing
/// the placement sequence.
class LevelGenerator {
  final Random _random;

  LevelGenerator({int? seed}) : _random = Random(seed);

  /// Grid dimensions, arrow count, and tail config by level.
  static ({int rows, int cols, int count, int maxTail, bool lTails})
      configForLevel(int level) {
    // Early levels: no tails
    if (level <= 2)  return (rows: 5,  cols: 4,  count: 4,  maxTail: 0, lTails: false);
    if (level <= 4)  return (rows: 6,  cols: 5,  count: 7,  maxTail: 0, lTails: false);
    // Introduce short straight tails
    if (level <= 6)  return (rows: 7,  cols: 5,  count: 9,  maxTail: 1, lTails: false);
    if (level <= 8)  return (rows: 7,  cols: 6,  count: 12, maxTail: 2, lTails: false);
    // Longer tails
    if (level <= 10) return (rows: 8,  cols: 7,  count: 16, maxTail: 3, lTails: false);
    // Introduce L-shaped tails
    if (level <= 13) return (rows: 9,  cols: 7,  count: 18, maxTail: 3, lTails: true);
    if (level <= 16) return (rows: 10, cols: 8,  count: 22, maxTail: 4, lTails: true);
    if (level <= 20) return (rows: 11, cols: 9,  count: 28, maxTail: 5, lTails: true);
    if (level <= 25) return (rows: 12, cols: 9,  count: 32, maxTail: 5, lTails: true);
    if (level <= 30) return (rows: 13, cols: 10, count: 38, maxTail: 6, lTails: true);
    if (level <= 40) return (rows: 14, cols: 11, count: 45, maxTail: 6, lTails: true);
    return (rows: 15, cols: 12, count: 55, maxTail: 7, lTails: true);
  }

  /// Generate a level.
  ({List<Arrow> arrows, int rows, int cols}) generate(int levelNumber) {
    final config = configForLevel(levelNumber);
    return _generateLevel(
      config.rows,
      config.cols,
      config.count,
      config.maxTail,
      config.lTails,
    );
  }

  ({List<Arrow> arrows, int rows, int cols}) _generateLevel(
    int rows,
    int cols,
    int targetCount,
    int maxTail,
    bool allowLTails,
  ) {
    final arrows = <Arrow>[];
    final occupied = <(int, int)>{};
    var nextId = 0;

    for (var i = 0; i < targetCount; i++) {
      // Decide tail configuration for this arrow
      final tailLen = maxTail > 0 ? _random.nextInt(maxTail + 1) : 0;
      final useLTail = allowLTails && tailLen >= 2 && _random.nextBool();

      final arrow = _placeArrow(
        rows, cols, occupied, nextId, tailLen, useLTail,
      );
      if (arrow == null) break;

      arrows.add(arrow);
      occupied.addAll(arrow.occupiedCells);
      nextId++;
    }

    // Shuffle so solution order isn't obvious
    arrows.shuffle(_random);

    return (arrows: arrows, rows: rows, cols: cols);
  }

  /// Try to place one arrow with a given tail configuration.
  /// The arrow must:
  /// 1. Not overlap any occupied cell (head + all tail cells)
  /// 2. Have a clear flight path (no occupied cells ahead of head)
  /// 3. All tail cells must be within grid bounds
  Arrow? _placeArrow(
    int rows,
    int cols,
    Set<(int, int)> occupied,
    int id,
    int tailLen,
    bool useLTail,
  ) {
    final candidates = <Arrow>[];

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (occupied.contains((r, c))) continue;

        for (final dir in Direction.values) {
          // Generate tail segments
          final tailOptions = _buildTailOptions(
            r, c, dir, tailLen, useLTail, rows, cols,
          );

          for (final segments in tailOptions) {
            final arrow = Arrow(
              id: id,
              row: r,
              col: c,
              direction: dir,
              tailSegments: segments,
            );

            // Check all occupied cells are in bounds and not taken
            final cells = arrow.occupiedCells;
            if (!_allInBounds(cells, rows, cols)) continue;
            if (cells.any(occupied.contains)) continue;

            // Check no duplicate cells within the arrow itself
            if (cells.toSet().length != cells.length) continue;

            // Check flight path is clear
            final path = arrow.flightPath(rows, cols);
            if (path.any(occupied.contains)) continue;

            candidates.add(arrow);
          }
        }
      }
    }

    if (candidates.isEmpty) {
      // Fall back to no tail if we couldn't place with tail
      if (tailLen > 0) {
        return _placeArrow(rows, cols, occupied, id, 0, false);
      }
      return null;
    }

    return candidates[_random.nextInt(candidates.length)];
  }

  /// Build possible tail segment configurations for an arrow.
  List<List<TailSegment>> _buildTailOptions(
    int headRow,
    int headCol,
    Direction arrowDir,
    int tailLen,
    bool useLTail,
    int rows,
    int cols,
  ) {
    if (tailLen == 0) return [[]];

    final options = <List<TailSegment>>[];

    // Option 1: Straight tail (extends opposite to arrow direction)
    final straightDir = arrowDir.opposite;
    options.add([TailSegment(direction: straightDir, length: tailLen)]);

    // Option 2: L-shaped tails (if allowed and tail >= 2)
    if (useLTail && tailLen >= 2) {
      final perps = arrowDir.perpendicular;

      for (final perpDir in perps) {
        // First segment: 1 to tailLen-1 cells opposite, then turn
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
