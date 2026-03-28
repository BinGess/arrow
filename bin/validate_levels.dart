// ignore_for_file: avoid_print
/// Standalone script to validate all levels are solvable.
/// Run with: dart run bin/validate_levels.dart

import '../lib/engine/level_generator.dart';
import '../lib/engine/level_validator.dart';
import '../lib/models/arrow.dart';

void main() {
  print('=== Arrow Puzzle Level Validation ===\n');

  var allPassed = true;
  final generator = LevelGenerator(seed: 42);

  for (var level = 1; level <= 50; level++) {
    final result = generator.generate(level);
    final arrows = result.arrows;
    final rows = result.rows;
    final cols = result.cols;

    final solution = LevelValidator.findSolution(arrows, rows, cols);
    final metrics = LevelValidator.analyzeMetrics(arrows, rows, cols);

    // Quality stats
    final headOnly = arrows.where((a) => !a.hasTail).length;
    final headPct = arrows.isEmpty ? 0 : (headOnly * 100 / arrows.length).round();
    final lTails = arrows.where((a) => a.tailSegments.length >= 2).length;
    final lPct = arrows.isEmpty ? 0 : (lTails * 100 / arrows.length).round();

    // Direction balance
    final dirCounts = <Direction, int>{};
    for (final a in arrows) {
      dirCounts[a.direction] = (dirCounts[a.direction] ?? 0) + 1;
    }
    final maxDirPct = arrows.isEmpty
        ? 0
        : (dirCounts.values.fold(0, (a, b) => a > b ? a : b) * 100 / arrows.length).round();
    final dirStr = dirCounts.entries
        .map((e) => '${e.key.name[0].toUpperCase()}:${e.value}')
        .join(' ');

    if (solution == null) {
      print('FAIL  Level $level: NOT SOLVABLE! '
          '(${arrows.length} arrows on ${rows}x${cols})');
      allPassed = false;
      continue;
    }

    // Verify solution by simulation
    final simOk = _simulateSolution(arrows, rows, cols, solution);
    if (!simOk) {
      print('FAIL  Level $level: Solution simulation failed!');
      allPassed = false;
      continue;
    }

    final config = LevelGenerator.configForLevel(level);
    print('L${level.toString().padLeft(2)} '
        '${rows}x${cols.toString().padRight(2)} '
        '${arrows.length.toString().padLeft(3)} arrows '
        '(target ${config.count.toString().padLeft(3)}) '
        'headOnly=${headPct.toString().padLeft(2)}% '
        'L-tail=${lPct.toString().padLeft(2)}% '
        'maxDir=${maxDirPct}% '
        '[$dirStr] '
        'depth=${metrics.maxChainDepth} '
        'free=${metrics.freeAtStart} '
        'lives=${config.lives}');
  }

  print('');
  if (allPassed) {
    print('ALL 50 LEVELS PASSED VALIDATION');
  } else {
    print('SOME LEVELS FAILED - see above');
  }

  // Test multiple seeds
  print('\n=== Multi-Seed Validation ===\n');
  var seedPassed = 0;
  var seedFailed = 0;
  for (var seed = 0; seed < 20; seed++) {
    final gen = LevelGenerator(seed: seed);
    var ok = true;
    for (final level in [1, 10, 20, 30, 40, 50]) {
      final result = gen.generate(level);
      if (!LevelValidator.isSolvable(result.arrows, result.rows, result.cols)) {
        print('FAIL  Seed $seed, Level $level: NOT SOLVABLE');
        ok = false;
        seedFailed++;
        break;
      }
      // Check quality
      final headOnly = result.arrows.where((a) => !a.hasTail).length;
      final headPct = result.arrows.isEmpty ? 0 : headOnly * 100 ~/ result.arrows.length;
      if (headPct > 20) {
        print('WARN  Seed $seed, Level $level: ${headPct}% head-only arrows');
      }
    }
    if (ok) seedPassed++;
  }
  print('\nSeeds passed: $seedPassed / 20');
  if (seedFailed > 0) print('Seeds failed: $seedFailed');
}

bool _simulateSolution(
  List<Arrow> arrows, int rows, int cols, List<int> solution,
) {
  final remaining = {for (final a in arrows) a.id: a};

  for (final arrowId in solution) {
    final arrow = remaining[arrowId];
    if (arrow == null) return false;

    final otherOccupied = <(int, int)>{};
    for (final other in remaining.values) {
      if (other.id == arrowId) continue;
      otherOccupied.addAll(other.occupiedCells);
    }

    final path = arrow.flightPath(rows, cols);
    for (final cell in path) {
      if (otherOccupied.contains(cell)) return false;
    }

    remaining.remove(arrowId);
  }

  return remaining.isEmpty;
}
