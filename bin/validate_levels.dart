// ignore_for_file: avoid_print
/// Standalone script to validate all levels.
/// Run with: dart run bin/validate_levels.dart

import '../lib/engine/level_generator.dart';
import '../lib/engine/level_validator.dart';
import '../lib/models/arrow.dart';

void main() {
  print('=== Arrow Puzzle Level Validation ===');
  print('');
  print('Key metrics:');
  print('  free%  = arrows removable at start (lower = harder puzzle)');
  print('  head%  = arrows without tails (lower = more complex board)');
  print('  L%     = arrows with L-shaped tails');
  print('  maxDir = most common single direction %');
  print('');

  var allPassed = true;
  final generator = LevelGenerator();

  for (var level = 1; level <= 50; level++) {
    final result = generator.generate(level);
    final arrows = result.arrows;
    final rows = result.rows;
    final cols = result.cols;
    final config = LevelGenerator.configForLevel(level);

    final solution = LevelValidator.findSolution(arrows, rows, cols,
        obstacles: result.obstacles);
    final metrics = LevelValidator.analyzeMetrics(arrows, rows, cols);

    if (solution == null) {
      print('FAIL  Level $level: NOT SOLVABLE!');
      allPassed = false;
      continue;
    }

    // Verify by simulation
    if (!_simulateSolution(arrows, rows, cols, solution, result.obstacles)) {
      print('FAIL  Level $level: Solution simulation failed!');
      allPassed = false;
      continue;
    }

    // Stats
    final headOnly = arrows.where((a) => !a.hasTail).length;
    final headPct = (headOnly * 100 / arrows.length).round();
    final lTails = arrows.where((a) => a.tailSegments.length >= 2).length;
    final lPct = (lTails * 100 / arrows.length).round();
    final freePct = (metrics.freeAtStart * 100 / arrows.length).round();

    final dirCounts = <Direction, int>{};
    for (final a in arrows) {
      dirCounts[a.direction] = (dirCounts[a.direction] ?? 0) + 1;
    }
    final maxDirPct = (dirCounts.values.fold(0, (a, b) => a > b ? a : b) * 100 / arrows.length).round();
    final dirStr = dirCounts.entries
        .map((e) => '${e.key.name[0].toUpperCase()}:${e.value}')
        .join(' ');

    // Quality flags
    final flags = <String>[];
    if (freePct > 20) flags.add('TOO_MANY_FREE');
    if (headPct > 15) flags.add('TOO_MANY_HEADONLY');
    if (maxDirPct > 35) flags.add('DIR_IMBALANCE');
    if (metrics.maxChainDepth < 3) flags.add('TOO_SHALLOW');

    final status = flags.isEmpty ? 'OK  ' : 'WARN';

    print('$status L${level.toString().padLeft(2)} '
        '${rows}x${cols.toString().padRight(2)} '
        '${arrows.length.toString().padLeft(3)} arrows obs=${result.obstacles.length.toString().padLeft(2)} '
        'free=${freePct.toString().padLeft(2)}%(${metrics.freeAtStart.toString().padLeft(2)}) '
        'head=${headPct.toString().padLeft(2)}% '
        'L=${lPct.toString().padLeft(2)}% '
        'maxDir=${maxDirPct.toString().padLeft(2)}% '
        'depth=${metrics.maxChainDepth.toString().padLeft(2)} '
        'lives=${config.lives} '
        '[$dirStr]'
        '${flags.isNotEmpty ? "  *** ${flags.join(", ")}" : ""}');
  }

  print('');
  if (allPassed) {
    print('ALL 50 LEVELS PASSED SOLVABILITY CHECK');
  } else {
    print('SOME LEVELS FAILED - see above');
  }

  // Summary stats
  print('\n=== Summary ===\n');
  var totalFree = 0, totalArrows = 0, totalHead = 0;
  for (var level = 1; level <= 50; level++) {
    final result = generator.generate(level);
    final metrics = LevelValidator.analyzeMetrics(result.arrows, result.rows, result.cols);
    totalFree += metrics.freeAtStart;
    totalArrows += result.arrows.length;
    totalHead += result.arrows.where((a) => !a.hasTail).length;
  }
  print('Average free at start: ${(totalFree * 100 / totalArrows).toStringAsFixed(1)}%');
  print('Average head-only:     ${(totalHead * 100 / totalArrows).toStringAsFixed(1)}%');
}

bool _simulateSolution(
  List<Arrow> arrows, int rows, int cols, List<int> solution,
  Set<(int, int)> obstacles,
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
      if (otherOccupied.contains(cell) || obstacles.contains(cell)) return false;
    }

    remaining.remove(arrowId);
  }

  return remaining.isEmpty;
}
