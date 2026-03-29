import 'dart:math';
import '../models/arrow.dart';
import 'level_validator.dart';

// ─── Private: Grid occupancy tracker ────────────────────────

class _GridMap {
  final int rows, cols;
  final Set<(int, int)> obstacles = {};
  final Map<(int, int), int> _cellOwner = {}; // cell → arrowId

  _GridMap(this.rows, this.cols);

  bool isInBounds(int r, int c) => r >= 0 && r < rows && c >= 0 && c < cols;
  bool isObstacle(int r, int c) => obstacles.contains((r, c));
  bool isFree(int r, int c) =>
      isInBounds(r, c) &&
      !obstacles.contains((r, c)) &&
      !_cellOwner.containsKey((r, c));
  int? arrowAt(int r, int c) => _cellOwner[(r, c)];

  void addObstacle(int r, int c) => obstacles.add((r, c));

  void occupyArrow(Arrow arrow) {
    for (final cell in arrow.occupiedCells) {
      _cellOwner[cell] = arrow.id;
    }
  }

  int distToEdge(int r, int c, Direction dir) {
    switch (dir) {
      case Direction.up:
        return r;
      case Direction.down:
        return rows - 1 - r;
      case Direction.left:
        return c;
      case Direction.right:
        return cols - 1 - c;
    }
  }

  /// Cells from (r,c)+dir to board edge (exclusive of (r,c) itself).
  List<(int, int)> flightPath(int r, int c, Direction dir) {
    final path = <(int, int)>[];
    var cr = r + dir.dr, cc = c + dir.dc;
    while (isInBounds(cr, cc)) {
      path.add((cr, cc));
      cr += dir.dr;
      cc += dir.dc;
    }
    return path;
  }

  /// Is the entire flight path free of obstacles and arrows?
  bool isFlightClear(int r, int c, Direction dir) {
    for (final (cr, cc) in flightPath(r, c, dir)) {
      if (obstacles.contains((cr, cc)) || _cellOwner.containsKey((cr, cc))) {
        return false;
      }
    }
    return true;
  }

  /// All cells with no obstacle and no arrow.
  List<(int, int)> freeCells() {
    final cells = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (isFree(r, c)) cells.add((r, c));
      }
    }
    return cells;
  }
}

// ─── Private: Dependency chain node ─────────────────────────

class _ChainNode {
  final Arrow arrow;
  final int depth; // 0 = root (exit arrow, removed LAST by player)
  final int chainId;
  _ChainNode? parent;
  final List<_ChainNode> children = [];

  _ChainNode({
    required this.arrow,
    required this.depth,
    required this.chainId,
    this.parent,
  });

  /// Collect all nodes in this subtree (including self).
  List<_ChainNode> allNodes() {
    final nodes = [this];
    for (final child in children) {
      nodes.addAll(child.allNodes());
    }
    return nodes;
  }

  /// Max depth in subtree.
  int get maxDepth {
    if (children.isEmpty) return depth;
    return children.map((c) => c.maxDepth).fold(depth, max);
  }
}

// ─── Public: Topological Constraint Level Generator ─────────

class LevelGenerator {
  final int? _baseSeed;

  LevelGenerator({int? seed}) : _baseSeed = seed;

  // ── Config ────────────────────────────────────────────────

  static ({
    int rows,
    int cols,
    int obstacleCount,
    int chainCount,
    int targetDepth,
    int trapCount,
    int trapMinDepth,
    int maxTail,
    double lTailChance,
    int minFlightPath,
    int lives,
  }) configForLevel(int level) {
    final t = ((level - 1) / 49.0).clamp(0.0, 1.0);
    return (
      rows: (14 + t * 10).round(),
      cols: (11 + t * 7).round(),
      obstacleCount: (3 + t * 17).round(),
      chainCount: (6 + t * 9).round(),
      targetDepth: (3 + t * 7).round(),
      trapCount: (2 + t * 23).round(),
      trapMinDepth: (1 + t * 3).round(),
      maxTail: (3 + t * 4).round(),
      lTailChance: 0.40 + t * 0.48,
      minFlightPath: (3 + t * 2).round(),
      lives: (5 - t * 4).round().clamp(1, 5),
    );
  }

  // ── Main entry ────────────────────────────────────────────

  int _nextId = 0;

  ({
    List<Arrow> arrows,
    Set<(int, int)> obstacles,
    int rows,
    int cols,
    int lives,
  }) generate(int levelNumber) {
    final config = configForLevel(levelNumber);

    for (var attempt = 0; attempt < 20; attempt++) {
      final seed = _baseSeed ?? (levelNumber * 1000 + attempt * 7 + 42);
      final random = Random(seed + attempt);
      _nextId = 0;

      final grid = _GridMap(config.rows, config.cols);

      // Step 1: Obstacles
      _placeObstacles(grid, config.obstacleCount, random);

      // Step 2: Chains
      final chainRoots = _buildChains(grid, config, random);
      final chainNodes = <_ChainNode>[];
      for (final root in chainRoots) {
        chainNodes.addAll(root.allNodes());
      }
      if (chainNodes.length < 5) continue;

      // Step 3: Traps
      final trapArrows = _injectTraps(grid, chainNodes, config, random);

      // Collect all arrows
      final allArrows = <Arrow>[
        ...chainNodes.map((n) => n.arrow),
        ...trapArrows,
      ]..shuffle(random);

      // Validate (should always pass with correct generation)
      if (LevelValidator.isSolvable(
          allArrows, config.rows, config.cols,
          obstacles: grid.obstacles)) {
        return (
          arrows: allArrows,
          obstacles: Set<(int, int)>.from(grid.obstacles),
          rows: config.rows,
          cols: config.cols,
          lives: config.lives,
        );
      }
    }

    // Fallback: chains only, no traps
    final random = Random(_baseSeed ?? (levelNumber * 1000 + 99));
    _nextId = 0;
    final grid = _GridMap(config.rows, config.cols);
    _placeObstacles(grid, config.obstacleCount, random);
    final roots = _buildChains(grid, config, random);
    final allArrows = <Arrow>[];
    for (final root in roots) {
      for (final node in root.allNodes()) {
        allArrows.add(node.arrow);
      }
    }
    return (
      arrows: allArrows,
      obstacles: Set<(int, int)>.from(grid.obstacles),
      rows: config.rows,
      cols: config.cols,
      lives: config.lives,
    );
  }

  // ── Step 1: Obstacles ─────────────────────────────────────

  void _placeObstacles(_GridMap grid, int count, Random random) {
    const margin = 2;
    final rMax = grid.rows - margin;
    final cMax = grid.cols - margin;
    if (rMax <= margin || cMax <= margin) return;

    var placed = 0;
    for (var tries = 0; tries < count * 15 && placed < count; tries++) {
      final r = margin + random.nextInt(rMax - margin);
      final c = margin + random.nextInt(cMax - margin);
      if (!grid.isFree(r, c)) continue;

      // No adjacent obstacles (prevent clusters)
      var tooClose = false;
      for (final (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        if (grid.isObstacle(r + dr, c + dc)) {
          tooClose = true;
          break;
        }
      }
      if (tooClose) continue;

      grid.addObstacle(r, c);
      placed++;
    }
  }

  // ── Step 2: Build chains ──────────────────────────────────

  List<_ChainNode> _buildChains(
    _GridMap grid,
    dynamic config,
    Random random,
  ) {
    final roots = <_ChainNode>[];
    final exits = _findExits(grid, config.minFlightPath as int);
    exits.shuffle(random);

    var chainId = 0;
    for (final (r, c, dir) in exits) {
      if (chainId >= (config.chainCount as int)) break;
      if (!grid.isFree(r, c)) continue;

      final root = _growChain(grid, r, c, dir, chainId, config, random);
      if (root != null) {
        roots.add(root);
        chainId++;
      }
    }

    return roots;
  }

  /// Valid exit positions: inside the board, pointing toward edge,
  /// flight path to edge clear of obstacles.
  List<(int, int, Direction)> _findExits(_GridMap grid, int minFlight) {
    final exits = <(int, int, Direction)>[];
    for (var r = 0; r < grid.rows; r++) {
      for (var c = 0; c < grid.cols; c++) {
        for (final dir in Direction.values) {
          if (grid.distToEdge(r, c, dir) < minFlight) continue;
          // Flight path to edge must be clear of obstacles
          var clear = true;
          for (final (cr, cc) in grid.flightPath(r, c, dir)) {
            if (grid.isObstacle(cr, cc)) {
              clear = false;
              break;
            }
          }
          if (clear) exits.add((r, c, dir));
        }
      }
    }
    return exits;
  }

  /// Grow a dependency chain from an exit position.
  ///
  /// Layer 0 (root): exit arrow pointing toward edge — removed LAST.
  /// Layer N (leaves): blockers — removed FIRST by player.
  _ChainNode? _growChain(
    _GridMap grid,
    int r,
    int c,
    Direction dir,
    int chainId,
    dynamic config,
    Random random,
  ) {
    final maxTail = config.maxTail as int;
    final lTailChance = config.lTailChance as double;
    final minFlight = config.minFlightPath as int;

    // Place exit arrow (Layer 0 = root)
    final exitArrow = _buildArrow(grid, r, c, dir, maxTail, lTailChance, random);
    if (exitArrow == null) return null;
    if (!grid.isFlightClear(exitArrow.row, exitArrow.col, exitArrow.direction)) {
      _nextId--; // reclaim ID
      return null;
    }

    grid.occupyArrow(exitArrow);
    final root = _ChainNode(arrow: exitArrow, depth: 0, chainId: chainId);

    // Grow deeper layers (blockers of blockers)
    var currentLayer = [root];
    final targetDepth = config.targetDepth as int;

    for (var depth = 1; depth <= targetDepth; depth++) {
      final nextLayer = <_ChainNode>[];
      for (final parent in currentLayer) {
        final blockers = _spawnBlockers(
            grid, parent, depth, chainId, config, random);
        nextLayer.addAll(blockers);
      }
      if (nextLayer.isEmpty) break;
      currentLayer = nextLayer;
    }

    return root;
  }

  /// Try to spawn blocker(s) on a parent arrow's flight path.
  ///
  /// The blocker's occupied cells (head or tail) land on the parent's
  /// flight path, preventing the parent from flying out.
  List<_ChainNode> _spawnBlockers(
    _GridMap grid,
    _ChainNode parent,
    int depth,
    int chainId,
    dynamic config,
    Random random,
  ) {
    final parentFlight = parent.arrow.flightPath(grid.rows, grid.cols);
    final freeFlight =
        parentFlight.where((c) => grid.isFree(c.$1, c.$2)).toList();
    freeFlight.shuffle(random);

    final blockers = <_ChainNode>[];

    for (final (tr, tc) in freeFlight) {
      if (blockers.isNotEmpty) break; // 1 blocker per parent

      final arrow = _tryPlaceBlocker(grid, tr, tc,
          parent.arrow.direction, config, random);
      if (arrow != null) {
        grid.occupyArrow(arrow);
        final node = _ChainNode(
          arrow: arrow,
          depth: depth,
          chainId: chainId,
          parent: parent,
        );
        parent.children.add(node);
        blockers.add(node);
      }
    }

    return blockers;
  }

  /// Try to place a blocker covering (tr, tc).
  ///
  /// Strategy 1: head AT target cell, pointing perpendicular to parent.
  /// Strategy 2: head offset from target, tail extending to cover it.
  Arrow? _tryPlaceBlocker(
    _GridMap grid,
    int tr,
    int tc,
    Direction parentDir,
    dynamic config,
    Random random,
  ) {
    final maxTail = config.maxTail as int;
    final lTailChance = config.lTailChance as double;
    final minFlight = config.minFlightPath as int;

    // Prefer perpendicular directions
    final dirs = <Direction>[
      ...parentDir.perpendicular.toList()..shuffle(random),
      parentDir.opposite,
      parentDir,
    ];

    for (final dir in dirs) {
      // Strategy 1: head at target cell
      if (grid.distToEdge(tr, tc, dir) >= minFlight) {
        final arrow = _buildArrow(grid, tr, tc, dir, maxTail, lTailChance, random);
        if (arrow != null && _isValidPlacement(grid, arrow, minFlight)) {
          return arrow;
        } else if (arrow != null) {
          _nextId--; // reclaim
        }
      }

      // Strategy 2: head offset, straight tail covers target
      for (var offset = 1; offset <= maxTail; offset++) {
        final hr = tr + dir.dr * offset;
        final hc = tc + dir.dc * offset;
        if (!grid.isInBounds(hr, hc) || !grid.isFree(hr, hc)) break;
        if (grid.distToEdge(hr, hc, dir) < minFlight) continue;

        // Straight tail from head back to target cell
        final segments = [
          TailSegment(direction: dir.opposite, length: offset)
        ];
        final arrow = Arrow(
          id: _nextId,
          row: hr,
          col: hc,
          direction: dir,
          tailSegments: segments,
        );

        if (_isValidPlacement(grid, arrow, minFlight)) {
          _nextId++;
          return arrow;
        }
      }
    }

    return null;
  }

  // ── Step 3: Inject traps ──────────────────────────────────

  /// Traps = arrows that LOOK free but collide when tapped.
  ///
  /// Rules:
  ///   1. Trap body must NOT be on any chain arrow's flight path.
  ///   2. Trap flight path must hit a chain arrow (depth ≥ trapMinDepth).
  ///   3. Beyond all chain arrows on the path, must be clear to edge
  ///      (no obstacles, no traps). Once chains clear, trap can fly.
  List<Arrow> _injectTraps(
    _GridMap grid,
    List<_ChainNode> chainNodes,
    dynamic config,
    Random random,
  ) {
    final traps = <Arrow>[];
    final trapCount = config.trapCount as int;
    final trapMinDepth = config.trapMinDepth as int;
    final maxTail = config.maxTail as int;
    final lTailChance = config.lTailChance as double;
    final minFlight = config.minFlightPath as int;

    // Pre-compute chain data
    final chainArrowIds = <int>{};
    final arrowDepth = <int, int>{};
    final chainFlightCells = <(int, int)>{};
    for (final node in chainNodes) {
      chainArrowIds.add(node.arrow.id);
      arrowDepth[node.arrow.id] = node.depth;
      chainFlightCells
          .addAll(node.arrow.flightPath(grid.rows, grid.cols));
    }

    // Track placed trap cells (prevent trap-trap flight conflicts)
    final trapCells = <(int, int)>{};

    final freeCells = grid.freeCells()..shuffle(random);

    for (final (r, c) in freeCells) {
      if (traps.length >= trapCount) break;

      final trap = _tryCreateTrap(
        grid, r, c, chainArrowIds, arrowDepth, chainFlightCells,
        trapCells, trapMinDepth, maxTail, lTailChance, minFlight, random,
      );
      if (trap != null) {
        grid.occupyArrow(trap);
        trapCells.addAll(trap.occupiedCells);
        traps.add(trap);
      }
    }

    return traps;
  }

  Arrow? _tryCreateTrap(
    _GridMap grid,
    int r,
    int c,
    Set<int> chainArrowIds,
    Map<int, int> arrowDepth,
    Set<(int, int)> chainFlightCells,
    Set<(int, int)> trapCells,
    int trapMinDepth,
    int maxTail,
    double lTailChance,
    int minFlight,
    Random random,
  ) {
    final dirs = List.of(Direction.values)..shuffle(random);

    for (final dir in dirs) {
      if (grid.distToEdge(r, c, dir) < minFlight) continue;

      // Walk entire flight path — check what it hits
      final flightPath = grid.flightPath(r, c, dir);
      var hitsDeepChainArrow = false;
      var pathValid = true;

      for (final (cr, cc) in flightPath) {
        // Obstacle anywhere on path → can never fly, invalid
        if (grid.isObstacle(cr, cc)) {
          pathValid = false;
          break;
        }
        // Another trap on path → would create inter-trap dependency
        if (trapCells.contains((cr, cc))) {
          pathValid = false;
          break;
        }
        // Chain arrow on path → that's the "trap" mechanism
        final aid = grid.arrowAt(cr, cc);
        if (aid != null && chainArrowIds.contains(aid)) {
          final depth = arrowDepth[aid] ?? 0;
          if (depth >= trapMinDepth) {
            hitsDeepChainArrow = true;
          }
        }
      }

      if (!pathValid || !hitsDeepChainArrow) continue;

      // Build the trap arrow
      final arrow =
          _buildArrow(grid, r, c, dir, maxTail, lTailChance, random);
      if (arrow == null) continue;

      // Trap body must NOT block any chain arrow's flight path
      if (arrow.occupiedCells.any(chainFlightCells.contains)) {
        _nextId--;
        continue;
      }

      return arrow;
    }

    return null;
  }

  // ── Arrow building helpers ────────────────────────────────

  /// Build arrow at (r,c) pointing dir with best-fit tail.
  /// Returns null if even head-only placement fails.
  /// Allocates an ID (_nextId++).
  Arrow? _buildArrow(
    _GridMap grid,
    int r,
    int c,
    Direction dir,
    int maxTail,
    double lTailChance,
    Random random,
  ) {
    if (!grid.isFree(r, c)) return null;

    final id = _nextId++;
    final targetLen = maxTail > 0 ? 1 + random.nextInt(maxTail) : 0;

    // Try longest tail first, shorten on failure
    for (var tailLen = targetLen; tailLen >= 0; tailLen--) {
      final segmentOptions =
          _buildTailOptions(dir, tailLen, lTailChance, random);

      for (final segments in segmentOptions) {
        final arrow = Arrow(
            id: id, row: r, col: c, direction: dir, tailSegments: segments);
        final cells = arrow.occupiedCells;

        if (cells.toSet().length != cells.length) continue; // self-overlap
        if (!cells.every((cell) => grid.isFree(cell.$1, cell.$2))) continue;

        return arrow;
      }
    }

    // Head-only fallback
    return Arrow(id: id, row: r, col: c, direction: dir);
  }

  List<List<TailSegment>> _buildTailOptions(
    Direction dir,
    int tailLen,
    double lTailChance,
    Random random,
  ) {
    if (tailLen == 0) return [[]];

    final options = <List<TailSegment>>[];
    final straightDir = dir.opposite;

    // L-shaped tails (more complex, try first)
    if (tailLen >= 2 && random.nextDouble() < lTailChance) {
      final perps = dir.perpendicular.toList()..shuffle(random);
      for (final perpDir in perps) {
        for (var firstLen = 1; firstLen < tailLen; firstLen++) {
          options.add([
            TailSegment(direction: straightDir, length: firstLen),
            TailSegment(direction: perpDir, length: tailLen - firstLen),
          ]);
        }
      }
    }

    // Straight tail
    options.add([TailSegment(direction: straightDir, length: tailLen)]);

    return options;
  }

  bool _isValidPlacement(_GridMap grid, Arrow arrow, int minFlightPath) {
    final cells = arrow.occupiedCells;
    if (cells.toSet().length != cells.length) return false;
    if (!cells.every((c) => grid.isFree(c.$1, c.$2))) return false;
    if (grid.distToEdge(arrow.row, arrow.col, arrow.direction) <
        minFlightPath) {
      return false;
    }
    if (!grid.isFlightClear(arrow.row, arrow.col, arrow.direction)) {
      return false;
    }
    return true;
  }
}
