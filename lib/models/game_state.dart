/// Tracks the state of a game in progress.
class GameState {
  final int lives;
  final int maxLives;
  final int moveCount;
  final Set<(int, int)> connectedTiles;
  final bool isComplete;
  final bool isGameOver;

  const GameState({
    required this.lives,
    this.maxLives = 5,
    this.moveCount = 0,
    this.connectedTiles = const {},
    this.isComplete = false,
    this.isGameOver = false,
  });

  GameState copyWith({
    int? lives,
    int? moveCount,
    Set<(int, int)>? connectedTiles,
    bool? isComplete,
    bool? isGameOver,
  }) {
    return GameState(
      lives: lives ?? this.lives,
      maxLives: maxLives,
      moveCount: moveCount ?? this.moveCount,
      connectedTiles: connectedTiles ?? this.connectedTiles,
      isComplete: isComplete ?? this.isComplete,
      isGameOver: isGameOver ?? this.isGameOver,
    );
  }
}
