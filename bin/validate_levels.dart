// ignore_for_file: avoid_print
/// Standalone script to validate all levels are solvable.
/// Run with: dart run bin/validate_levels.dart

import '../lib/engine/level_generator.dart';
import '../lib/engine/level_validator.dart';
import '../lib/models/arrow.dart';

void main() {
  print('=== Arrow Maze Level Validation ===\n');

  var allPassed = true;
  final generator = LevelGenerator(seed: 42);

  for (var level = 1; level <= 50; level++) {
    final result = generator.generate(level);
    final arrows = result.arrows;
    final rows = result.rows;
    final cols = result.cols;

    final solution = LevelValidator.findSolution(arrows, rows, cols);
    final metrics = LevelValidator.analyzeMetrics(arrows, rows, cols);

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

    final status = metrics.maxChainDepth >= 2 ? 'OK   ' : 'EASY ';
    print('$status Level ${level.toString().padLeft(2)}: '
        '${arrows.length.toString().padLeft(2)} arrows, '
        '${rows}x${cols}, '
        'depth=${metrics.maxChainDepth}, '
        'free=${metrics.freeAtStart}, '
        'avgDeps=${metrics.avgDependencies.toStringAsFixed(1)}');
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
  for (var seed = 0; seed < 50; seed++) {
    final gen = LevelGenerator(seed: seed);
    var ok = true;
    for (final level in [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50]) {
      final result = gen.generate(level);
      if (!LevelValidator.isSolvable(result.arrows, result.rows, result.cols)) {
        print('FAIL  Seed $seed, Level $level: NOT SOLVABLE');
        ok = false;
        seedFailed++;
        break;
      }
    }
    if (ok) seedPassed++;
  }
  print('\nSeeds passed: $seedPassed / 50');
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
