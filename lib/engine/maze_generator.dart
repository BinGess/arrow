import 'dart:math';
import '../models/direction.dart';
import '../models/maze_cell.dart';
import '../models/maze_level.dart';

/// Generates solvable arrow maze puzzles with increasing difficulty.
class MazeGenerator {
  final Random _random;

  MazeGenerator({int? seed}) : _random = Random(seed);

  /// Get maze dimensions for a given level.
  static (int rows, int cols) dimensionsForLevel(int level) {
    if (level <= 3) return (4, 3);
    if (level <= 6) return (5, 4);
    if (level <= 10) return (6, 5);
    if (level <= 15) return (8, 6);
    if (level <= 20) return (9, 7);
    if (level <= 30) return (10, 8);
    return (12, 9);
  }

  /// Generate a maze level.
  MazeLevel generate(int levelNumber) {
    final (rows, cols) = dimensionsForLevel(levelNumber);
    return _generateMaze(levelNumber, rows, cols);
  }

  MazeLevel _generateMaze(int levelNumber, int rows, int cols) {
    // 1. Create a maze structure using recursive backtracking
    final walls = _generateWalls(rows, cols);

    // 2. Pick start and end positions
    final startRow = 0;
    final startCol = _random.nextInt(cols);
    final endRow = rows - 1;
    final endCol = _random.nextInt(cols);

    // 3. Find the solution path using BFS
    final solutionPath =
        _findPath(walls, rows, cols, startRow, startCol, endRow, endCol);

    if (solutionPath == null) {
      // Fallback: regenerate if no path (shouldn't happen with proper maze gen)
      return _generateMaze(levelNumber, rows, cols);
    }

    // 4. Assign arrows: solution path cells get correct direction arrows,
    //    non-solution cells get random directions.
    final grid = _buildGrid(walls, rows, cols, solutionPath);

    return MazeLevel(
      levelNumber: levelNumber,
      rows: rows,
      cols: cols,
      grid: grid,
      startRow: startRow,
      startCol: startCol,
      endRow: endRow,
      endCol: endCol,
    );
  }

  /// Generate wall structure using recursive backtracking (perfect maze).
  /// Returns a 2D array of wall sets for each cell.
  List<List<Set<Direction>>> _generateWalls(int rows, int cols) {
    // Initialize all walls present
    final walls = List.generate(
      rows,
      (r) => List.generate(
        cols,
        (c) => Set<Direction>.from(Direction.values),
      ),
    );

    final visited = List.generate(rows, (_) => List.filled(cols, false));
    final stack = <(int, int)>[];

    // Start from random cell
    final sr = _random.nextInt(rows);
    final sc = _random.nextInt(cols);
    visited[sr][sc] = true;
    stack.add((sr, sc));

    while (stack.isNotEmpty) {
      final (cr, cc) = stack.last;

      // Get unvisited neighbors
      final neighbors = <(int, int, Direction)>[];
      for (final dir in Direction.values) {
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

      // Pick random neighbor
      final (nr, nc, dir) = neighbors[_random.nextInt(neighbors.length)];

      // Remove walls between current and neighbor
      walls[cr][cc].remove(dir);
      walls[nr][nc].remove(dir.opposite);

      visited[nr][nc] = true;
      stack.add((nr, nc));
    }

    // Add extra passages for higher levels to create multiple paths
    // (makes the maze less perfect but more interesting)
    final extraPassages = (rows * cols * 0.1).toInt();
    for (var i = 0; i < extraPassages; i++) {
      final r = _random.nextInt(rows);
      final c = _random.nextInt(cols);
      final dirs = walls[r][c].toList();
      if (dirs.isNotEmpty) {
        final dir = dirs[_random.nextInt(dirs.length)];
        final nr = r + dir.dr;
        final nc = c + dir.dc;
        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
          walls[r][c].remove(dir);
          walls[nr][nc].remove(dir.opposite);
        }
      }
    }

    return walls;
  }

  /// Find shortest path using BFS.
  List<(int, int)>? _findPath(
    List<List<Set<Direction>>> walls,
    int rows,
    int cols,
    int startRow,
    int startCol,
    int endRow,
    int endCol,
  ) {
    final visited = List.generate(rows, (_) => List.filled(cols, false));
    final parent = <String, (int, int)?>{};
    final queue = <(int, int)>[];

    visited[startRow][startCol] = true;
    parent['$startRow,$startCol'] = null;
    queue.add((startRow, startCol));

    while (queue.isNotEmpty) {
      final (cr, cc) = queue.removeAt(0);

      if (cr == endRow && cc == endCol) {
        // Reconstruct path
        final path = <(int, int)>[];
        (int, int)? current = (cr, cc);
        while (current != null) {
          path.add(current);
          current = parent['${current.$1},${current.$2}'];
        }
        return path.reversed.toList();
      }

      for (final dir in Direction.values) {
        // Check if there's no wall blocking this direction
        if (walls[cr][cc].contains(dir)) continue;

        final nr = cr + dir.dr;
        final nc = cc + dir.dc;
        if (nr >= 0 &&
            nr < rows &&
            nc >= 0 &&
            nc < cols &&
            !visited[nr][nc]) {
          visited[nr][nc] = true;
          parent['$nr,$nc'] = (cr, cc);
          queue.add((nr, nc));
        }
      }
    }

    return null;
  }

  /// Build the grid of MazeCells, assigning correct arrows for solution path.
  List<List<MazeCell>> _buildGrid(
    List<List<Set<Direction>>> walls,
    int rows,
    int cols,
    List<(int, int)> solutionPath,
  ) {
    // Create a map of solution directions
    final solutionDirs = <String, Direction>{};
    for (var i = 0; i < solutionPath.length - 1; i++) {
      final (cr, cc) = solutionPath[i];
      final (nr, nc) = solutionPath[i + 1];
      final dr = nr - cr;
      final dc = nc - cc;
      Direction dir;
      if (dr == -1) {
        dir = Direction.up;
      } else if (dr == 1) {
        dir = Direction.down;
      } else if (dc == -1) {
        dir = Direction.left;
      } else {
        dir = Direction.right;
      }
      solutionDirs['$cr,$cc'] = dir;
    }

    return List.generate(rows, (r) {
      return List.generate(cols, (c) {
        final key = '$r,$c';

        // Determine arrow direction
        Direction direction;
        if (solutionDirs.containsKey(key)) {
          direction = solutionDirs[key]!;
        } else {
          // For non-solution cells, assign a random passable direction
          // (a direction without a wall), or any random direction.
          final passable = Direction.values
              .where((d) => !walls[r][c].contains(d))
              .toList();
          if (passable.isNotEmpty) {
            direction = passable[_random.nextInt(passable.length)];
          } else {
            direction = Direction.values[_random.nextInt(4)];
          }
        }

        return MazeCell(
          direction: direction,
          row: r,
          col: c,
          wallTop: walls[r][c].contains(Direction.up),
          wallRight: walls[r][c].contains(Direction.right),
          wallBottom: walls[r][c].contains(Direction.down),
          wallLeft: walls[r][c].contains(Direction.left),
        );
      });
    });
  }
}
