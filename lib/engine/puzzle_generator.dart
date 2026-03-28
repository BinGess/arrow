import 'dart:math';
import '../models/puzzle_tile.dart';
import '../models/puzzle_level.dart';

/// Generates solvable rotational path-link puzzles.
///
/// Strategy:
/// 1. Build a connected path/tree on the grid using random walk.
/// 2. Assign tile types based on connections (how many neighbors are connected).
/// 3. Set the solution rotation for each tile.
/// 4. Scramble rotations randomly to create the puzzle.
class PuzzleGenerator {
  final Random _random;

  PuzzleGenerator({int? seed}) : _random = Random(seed);

  /// Grid dimensions by difficulty level.
  static (int rows, int cols) dimensionsForLevel(int level) {
    if (level <= 3) return (4, 4);
    if (level <= 6) return (5, 5);
    if (level <= 10) return (6, 5);
    if (level <= 15) return (7, 6);
    if (level <= 20) return (8, 7);
    if (level <= 30) return (9, 8);
    if (level <= 40) return (10, 9);
    return (11, 10);
  }

  /// Whether to use arrow constraints at this level.
  static bool useArrows(int level) => level >= 8;

  /// Fraction of tiles that get arrow constraints.
  static double arrowDensity(int level) {
    if (level < 8) return 0;
    if (level < 15) return 0.15;
    if (level < 25) return 0.25;
    return 0.35;
  }

  PuzzleLevel generate(int levelNumber) {
    final (rows, cols) = dimensionsForLevel(levelNumber);
    return _generate(levelNumber, rows, cols);
  }

  PuzzleLevel _generate(int levelNumber, int rows, int cols) {
    // Step 1: Build a spanning tree using randomized DFS to connect all cells.
    final connections = _buildSpanningTree(rows, cols);

    // Step 2: Optionally add extra connections for higher levels
    //         to create loops and more complex puzzles.
    if (levelNumber > 5) {
      _addExtraConnections(connections, rows, cols, levelNumber);
    }

    // Step 3: Determine tile type and solution rotation for each cell.
    final solutionRotations = List.generate(rows, (_) => List.filled(cols, 0));
    final solutionGrid = List.generate(rows, (r) {
      return List.generate(cols, (c) {
        final openDirs = connections[r][c];
        final type = _tileTypeForConnections(openDirs);
        final rotation = _rotationForConnections(type, openDirs);
        solutionRotations[r][c] = rotation;

        // Decide if this cell has an arrow
        bool hasArrow = false;
        CardinalDirection? arrowDir;
        if (useArrows(levelNumber) &&
            openDirs.isNotEmpty &&
            _random.nextDouble() < arrowDensity(levelNumber)) {
          hasArrow = true;
          final dirs = openDirs.toList();
          arrowDir = dirs[_random.nextInt(dirs.length)];
        }

        // Mark source and target
        final isSource = r == 0 && c == 0;
        final isTarget = r == rows - 1 && c == cols - 1;

        return PuzzleTile(
          row: r,
          col: c,
          type: type,
          rotation: rotation,
          isFixed: isSource || isTarget,
          hasArrow: hasArrow,
          arrowDirection: arrowDir,
          isSource: isSource,
          isTarget: isTarget,
        );
      });
    });

    // Step 4: Scramble rotations (except fixed tiles) to create the puzzle.
    final scrambledGrid = List.generate(rows, (r) {
      return List.generate(cols, (c) {
        final tile = solutionGrid[r][c];
        if (tile.isFixed || tile.type == TileType.cross) {
          return tile; // Cross tiles look the same in any rotation
        }
        // Random rotation, but ensure it's different from solution
        var scrambleRot = _random.nextInt(4);
        // For straight tiles, only 2 distinct orientations
        if (tile.type == TileType.straight) {
          scrambleRot = _random.nextInt(2) * 2; // 0 or 2
          if (scrambleRot == tile.rotation % 2 * 2) {
            scrambleRot = (scrambleRot + 2) % 4;
          }
          // Actually ensure it differs
          if (scrambleRot % 2 == tile.rotation % 2) {
            scrambleRot = (scrambleRot + 1) % 4;
          }
        } else {
          // Try to ensure scrambled rotation differs from solution
          if (scrambleRot == tile.rotation) {
            scrambleRot = (scrambleRot + 1 + _random.nextInt(3)) % 4;
          }
        }
        return PuzzleTile(
          row: r,
          col: c,
          type: tile.type,
          rotation: scrambleRot,
          isFixed: tile.isFixed,
          hasArrow: tile.hasArrow,
          arrowDirection: tile.arrowDirection,
          isSource: tile.isSource,
          isTarget: tile.isTarget,
        );
      });
    });

    return PuzzleLevel(
      levelNumber: levelNumber,
      rows: rows,
      cols: cols,
      grid: scrambledGrid,
      solutionRotations: solutionRotations,
    );
  }

  /// Build a spanning tree connecting all cells using randomized DFS.
  /// Returns a 2D array where each cell has a set of directions it connects to.
  List<List<Set<CardinalDirection>>> _buildSpanningTree(int rows, int cols) {
    final connections = List.generate(
      rows,
      (_) => List.generate(cols, (_) => <CardinalDirection>{}),
    );
    final visited = List.generate(rows, (_) => List.filled(cols, false));
    final stack = <(int, int)>[];

    // Start from top-left
    visited[0][0] = true;
    stack.add((0, 0));

    while (stack.isNotEmpty) {
      final (cr, cc) = stack.last;

      final neighbors = <(int, int, CardinalDirection)>[];
      for (final dir in CardinalDirection.values) {
        final nr = cr + dir.dr;
        final nc = cc + dir.dc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !visited[nr][nc]) {
          neighbors.add((nr, nc, dir));
        }
      }

      if (neighbors.isEmpty) {
        stack.removeLast();
        continue;
      }

      final (nr, nc, dir) = neighbors[_random.nextInt(neighbors.length)];
      connections[cr][cc].add(dir);
      connections[nr][nc].add(dir.opposite);
      visited[nr][nc] = true;
      stack.add((nr, nc));
    }

    return connections;
  }

  /// Add extra connections to create loops for more complex puzzles.
  void _addExtraConnections(
    List<List<Set<CardinalDirection>>> connections,
    int rows,
    int cols,
    int level,
  ) {
    final extraCount = (rows * cols * 0.08 * (level / 10)).toInt().clamp(1, 10);
    for (var i = 0; i < extraCount; i++) {
      final r = _random.nextInt(rows);
      final c = _random.nextInt(cols);
      final allDirs = CardinalDirection.values.toList()..shuffle(_random);
      for (final dir in allDirs) {
        final nr = r + dir.dr;
        final nc = c + dir.dc;
        if (nr >= 0 &&
            nr < rows &&
            nc >= 0 &&
            nc < cols &&
            !connections[r][c].contains(dir)) {
          connections[r][c].add(dir);
          connections[nr][nc].add(dir.opposite);
          break;
        }
      }
    }
  }

  /// Determine tile type from the number/pattern of connections.
  TileType _tileTypeForConnections(Set<CardinalDirection> connections) {
    switch (connections.length) {
      case 0:
        return TileType.endCap; // shouldn't happen in a spanning tree
      case 1:
        return TileType.endCap;
      case 2:
        // Check if opposite (straight) or adjacent (corner)
        final list = connections.toList();
        if (list[0] == list[1].opposite) {
          return TileType.straight;
        }
        return TileType.corner;
      case 3:
        return TileType.tJunction;
      case 4:
        return TileType.cross;
      default:
        return TileType.cross;
    }
  }

  /// Find the rotation that makes the base tile type match the desired connections.
  int _rotationForConnections(
      TileType type, Set<CardinalDirection> connections) {
    for (var rot = 0; rot < 4; rot++) {
      final baseSides = PuzzleTile.baseSidesFor(type);
      final rotatedSides = baseSides.map((d) {
        var r = d;
        for (var i = 0; i < rot; i++) {
          r = r.rotatedCW;
        }
        return r;
      }).toSet();

      if (_setsEqual(rotatedSides, connections)) {
        return rot;
      }
    }
    return 0; // fallback
  }

  bool _setsEqual(Set<CardinalDirection> a, Set<CardinalDirection> b) {
    if (a.length != b.length) return false;
    return a.every(b.contains);
  }
}
