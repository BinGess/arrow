/// The type of pipe/tile piece.
enum TileType {
  /// Connects two opposite sides (e.g., North-South).
  straight,

  /// Connects two adjacent sides (e.g., North-East).
  corner,

  /// Connects three sides (T-junction).
  tJunction,

  /// Connects all four sides.
  cross,

  /// Connects only one side (start/end point).
  endCap,
}

/// Cardinal directions for connections and arrows.
enum CardinalDirection {
  north,
  east,
  south,
  west;

  CardinalDirection get opposite {
    switch (this) {
      case CardinalDirection.north:
        return CardinalDirection.south;
      case CardinalDirection.south:
        return CardinalDirection.north;
      case CardinalDirection.east:
        return CardinalDirection.west;
      case CardinalDirection.west:
        return CardinalDirection.east;
    }
  }

  /// Delta row (north = -1, south = +1).
  int get dr {
    switch (this) {
      case CardinalDirection.north:
        return -1;
      case CardinalDirection.south:
        return 1;
      case CardinalDirection.east:
      case CardinalDirection.west:
        return 0;
    }
  }

  /// Delta col (west = -1, east = +1).
  int get dc {
    switch (this) {
      case CardinalDirection.north:
      case CardinalDirection.south:
        return 0;
      case CardinalDirection.east:
        return 1;
      case CardinalDirection.west:
        return -1;
    }
  }

  /// Rotate 90° clockwise.
  CardinalDirection get rotatedCW {
    switch (this) {
      case CardinalDirection.north:
        return CardinalDirection.east;
      case CardinalDirection.east:
        return CardinalDirection.south;
      case CardinalDirection.south:
        return CardinalDirection.west;
      case CardinalDirection.west:
        return CardinalDirection.north;
    }
  }
}

/// A single tile on the puzzle grid.
class PuzzleTile {
  final int row;
  final int col;
  final TileType type;

  /// Rotation state: 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270° (clockwise).
  final int rotation;

  /// If true, the player cannot rotate this tile.
  final bool isFixed;

  /// Whether this tile has a directional arrow constraint.
  final bool hasArrow;

  /// The arrow direction (only meaningful if hasArrow is true).
  final CardinalDirection? arrowDirection;

  /// Whether this tile is a source (start) tile.
  final bool isSource;

  /// Whether this tile is a target (end) tile.
  final bool isTarget;

  const PuzzleTile({
    required this.row,
    required this.col,
    required this.type,
    this.rotation = 0,
    this.isFixed = false,
    this.hasArrow = false,
    this.arrowDirection,
    this.isSource = false,
    this.isTarget = false,
  });

  /// Get the set of sides this tile connects at its current rotation.
  Set<CardinalDirection> get openSides {
    final base = baseSidesFor(type);
    // Rotate each direction by the rotation amount
    return base.map((d) {
      var rotated = d;
      for (var i = 0; i < rotation; i++) {
        rotated = rotated.rotatedCW;
      }
      return rotated;
    }).toSet();
  }

  /// The base open sides for each tile type at rotation 0.
  static Set<CardinalDirection> baseSidesFor(TileType type) {
    switch (type) {
      case TileType.straight:
        // North-South
        return {CardinalDirection.north, CardinalDirection.south};
      case TileType.corner:
        // North-East
        return {CardinalDirection.north, CardinalDirection.east};
      case TileType.tJunction:
        // North-East-South
        return {
          CardinalDirection.north,
          CardinalDirection.east,
          CardinalDirection.south,
        };
      case TileType.cross:
        return Set.from(CardinalDirection.values);
      case TileType.endCap:
        // North only
        return {CardinalDirection.north};
    }
  }

  /// Create a copy with rotation incremented by 1 (90° CW).
  PuzzleTile rotated() {
    if (isFixed) return this;
    return PuzzleTile(
      row: row,
      col: col,
      type: type,
      rotation: (rotation + 1) % 4,
      isFixed: isFixed,
      hasArrow: hasArrow,
      arrowDirection: arrowDirection,
      isSource: isSource,
      isTarget: isTarget,
    );
  }

  PuzzleTile copyWith({
    int? rotation,
    bool? isFixed,
    bool? hasArrow,
    CardinalDirection? arrowDirection,
    bool? isSource,
    bool? isTarget,
  }) {
    return PuzzleTile(
      row: row,
      col: col,
      type: type,
      rotation: rotation ?? this.rotation,
      isFixed: isFixed ?? this.isFixed,
      hasArrow: hasArrow ?? this.hasArrow,
      arrowDirection: arrowDirection ?? this.arrowDirection,
      isSource: isSource ?? this.isSource,
      isTarget: isTarget ?? this.isTarget,
    );
  }
}
