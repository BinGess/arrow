import 'package:flutter_test/flutter_test.dart';
import 'package:arrow_maze/engine/level_generator.dart';
import 'package:arrow_maze/engine/level_validator.dart';
import 'package:arrow_maze/models/arrow.dart';

void main() {
  group('Level Solvability Tests', () {
    final generator = LevelGenerator(seed: 42);

    for (var level = 1; level <= 50; level++) {
      test('Level $level is solvable', () {
        final result = generator.generate(level);
        final arrows = result.arrows;
        final rows = result.rows;
        final cols = result.cols;

        // Must have arrows
        expect(arrows.isNotEmpty, true,
            reason: 'Level $level has no arrows');

        // Must be solvable
        final solution = LevelValidator.findSolution(arrows, rows, cols);
        expect(solution, isNotNull,
            reason: 'Level $level is NOT solvable!');

        // Solution must include all arrows
        if (solution != null) {
          expect(solution.length, arrows.length,
              reason:
                  'Solution for level $level does not remove all arrows');

          // Verify by simulation
          _verifySolution(arrows, rows, cols, solution, level);
        }
      });
    }

    test('All levels have reasonable difficulty', () {
      for (var level = 1; level <= 50; level++) {
        final result = generator.generate(level);
        final metrics = LevelValidator.analyzeMetrics(
          result.arrows, result.rows, result.cols,
        );

        expect(metrics.isSolvable, true,
            reason: 'Level $level is not solvable');

        if (level >= 10) {
          expect(metrics.maxChainDepth >= 2, true,
              reason: 'Level $level chain depth too shallow: '
                  '${metrics.maxChainDepth}');
        }
      });
    });

    test('Multiple seeds produce solvable puzzles', () {
      for (var seed = 0; seed < 20; seed++) {
        final gen = LevelGenerator(seed: seed);
        for (final level in [1, 5, 10, 15, 20, 30, 40, 50]) {
          final result = gen.generate(level);
          final solvable = LevelValidator.isSolvable(
            result.arrows, result.rows, result.cols,
          );
          expect(solvable, true,
              reason: 'Seed $seed, level $level is NOT solvable');
        }
      }
    });
  });
}

/// Simulate the solution step-by-step to verify correctness.
void _verifySolution(
  List<Arrow> arrows, int rows, int cols,
  List<int> solution, int level,
) {
  final remaining = {for (final a in arrows) a.id: a};

  for (var step = 0; step < solution.length; step++) {
    final arrowId = solution[step];
    final arrow = remaining[arrowId];

    expect(arrow, isNotNull,
        reason: 'Level $level step $step: arrow $arrowId not found');

    // Occupied cells of OTHER remaining arrows
    final otherOccupied = <(int, int)>{};
    for (final other in remaining.values) {
      if (other.id == arrowId) continue;
      otherOccupied.addAll(other.occupiedCells);
    }

    // Verify flight path is clear
    final path = arrow!.flightPath(rows, cols);
    for (final cell in path) {
      expect(otherOccupied.contains(cell), false,
          reason: 'Level $level step $step: arrow $arrowId '
              'collides at $cell');
    }

    remaining.remove(arrowId);
  }

  expect(remaining.isEmpty, true,
      reason: 'Level $level: ${remaining.length} arrows still remaining');
}
