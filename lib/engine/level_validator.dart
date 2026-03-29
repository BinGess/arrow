import '../models/arrow.dart';

/// Validates that a puzzle level is solvable by checking the
/// arrow dependency graph is a DAG (no cycles).
///
/// Dependency rule: Arrow X depends on Arrow Y if any of Y's
/// occupied cells fall in X's flight path. Y must be removed
/// before X can safely fly out.
class LevelValidator {
  /// Check if the puzzle is solvable. Returns the valid removal
  /// order if solvable, or null if unsolvable.
  ///
  /// If [obstacles] is provided, an arrow whose flight path hits an
  /// obstacle (after all blocking arrows are removed) can never fly out,
  /// so it's treated as permanently blocked and excluded from the solution.
  /// However, such arrows can still serve as blockers for other arrows.
  static List<int>? findSolution(List<Arrow> arrows, int rows, int cols,
      {Set<(int, int)>? obstacles}) {
    if (arrows.isEmpty) return [];

    final obs = obstacles ?? {};

    // Determine which arrows are obstacle-blocked:
    // An arrow is obstacle-blocked if its flight path hits an obstacle
    // AND no other arrow's body sits between it and the obstacle
    // (i.e. even after all arrows clear, it still can't fly).
    final obstacleBlocked = <int>{};
    for (final a in arrows) {
      final path = a.flightPath(rows, cols);
      for (final cell in path) {
        if (obs.contains(cell)) {
          obstacleBlocked.add(a.id);
          break;
        }
      }
    }

    // Build dependency graph: deps[x] = set of arrow IDs that block x.
    final arrowById = {for (final a in arrows) a.id: a};
    final deps = <int, Set<int>>{};
    final reverseDeps = <int, Set<int>>{}; // who does x block?

    for (final a in arrows) {
      deps[a.id] = {};
      reverseDeps[a.id] = {};
    }

    // For each arrow, find which other arrows' cells are in its flight path.
    for (final a in arrows) {
      final path = a.flightPath(rows, cols).toSet();
      for (final other in arrows) {
        if (other.id == a.id) continue;
        final otherCells = other.occupiedCells;
        if (otherCells.any(path.contains)) {
          // 'other' blocks 'a': a depends on other
          deps[a.id]!.add(other.id);
          reverseDeps[other.id]!.add(a.id);
        }
      }
    }

    // Any arrow permanently blocked by obstacles → unsolvable
    if (obstacleBlocked.isNotEmpty) return null;

    // Topological sort (Kahn's algorithm)
    // Arrows with no dependencies can be removed first.
    final inDegree = <int, int>{};
    for (final a in arrows) {
      inDegree[a.id] = deps[a.id]!.length;
    }

    final queue = <int>[];
    for (final a in arrows) {
      if (inDegree[a.id] == 0) {
        queue.add(a.id);
      }
    }

    final order = <int>[];
    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      order.add(id);

      for (final blocked in reverseDeps[id]!) {
        inDegree[blocked] = inDegree[blocked]! - 1;
        if (inDegree[blocked] == 0) {
          queue.add(blocked);
        }
      }
    }

    if (order.length == arrows.length) {
      return order; // Valid removal order
    }

    return null; // Cycle detected → unsolvable
  }

  /// Quick check: is the puzzle solvable?
  /// If [obstacles] is provided, arrows whose flight path hits an obstacle
  /// are treated as permanently blocked (infinite in-degree).
  static bool isSolvable(List<Arrow> arrows, int rows, int cols,
      {Set<(int, int)>? obstacles}) {
    return findSolution(arrows, rows, cols, obstacles: obstacles) != null;
  }

  /// Compute difficulty metrics for a puzzle.
  static PuzzleMetrics analyzeMetrics(
      List<Arrow> arrows, int rows, int cols) {
    final solution = findSolution(arrows, rows, cols);
    if (solution == null) {
      return PuzzleMetrics(
        isSolvable: false,
        freeAtStart: 0,
        maxChainDepth: 0,
        avgDependencies: 0,
        totalArrows: arrows.length,
      );
    }

    // Count free arrows at start (no dependencies)
    final deps = _buildDependencies(arrows, rows, cols);
    final freeCount = deps.entries.where((e) => e.value.isEmpty).length;

    // Find max chain depth via longest path in DAG
    final depth = _longestPath(arrows, deps);

    // Average dependencies
    final totalDeps = deps.values.fold(0, (s, d) => s + d.length);
    final avgDeps =
        arrows.isEmpty ? 0.0 : totalDeps / arrows.length;

    return PuzzleMetrics(
      isSolvable: true,
      freeAtStart: freeCount,
      maxChainDepth: depth,
      avgDependencies: avgDeps,
      totalArrows: arrows.length,
    );
  }

  static Map<int, Set<int>> _buildDependencies(
      List<Arrow> arrows, int rows, int cols) {
    final deps = <int, Set<int>>{};
    for (final a in arrows) {
      deps[a.id] = {};
    }
    for (final a in arrows) {
      final path = a.flightPath(rows, cols).toSet();
      for (final other in arrows) {
        if (other.id == a.id) continue;
        if (other.occupiedCells.any(path.contains)) {
          deps[a.id]!.add(other.id);
        }
      }
    }
    return deps;
  }

  /// Longest path in the dependency DAG (chain depth).
  static int _longestPath(
      List<Arrow> arrows, Map<int, Set<int>> deps) {
    final memo = <int, int>{};

    int dfs(int id) {
      if (memo.containsKey(id)) return memo[id]!;
      if (deps[id]!.isEmpty) {
        memo[id] = 0;
        return 0;
      }
      var maxDepth = 0;
      for (final depId in deps[id]!) {
        maxDepth = _max(maxDepth, 1 + dfs(depId));
      }
      memo[id] = maxDepth;
      return maxDepth;
    }

    var longest = 0;
    for (final a in arrows) {
      longest = _max(longest, dfs(a.id));
    }
    return longest;
  }

  static int _max(int a, int b) => a > b ? a : b;
}

/// Metrics about a puzzle's difficulty.
class PuzzleMetrics {
  final bool isSolvable;

  /// How many arrows can be removed immediately (no blockers).
  final int freeAtStart;

  /// Longest dependency chain depth.
  final int maxChainDepth;

  /// Average number of blocking dependencies per arrow.
  final double avgDependencies;

  final int totalArrows;

  const PuzzleMetrics({
    required this.isSolvable,
    required this.freeAtStart,
    required this.maxChainDepth,
    required this.avgDependencies,
    required this.totalArrows,
  });

  @override
  String toString() =>
      'Metrics(solvable=$isSolvable, free=$freeAtStart, '
      'depth=$maxChainDepth, avgDeps=${avgDependencies.toStringAsFixed(1)}, '
      'arrows=$totalArrows)';
}
