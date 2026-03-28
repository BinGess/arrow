import '../models/direction.dart';
import '../models/game_state.dart';
import '../models/maze_level.dart';

/// Handles game logic: move validation, state transitions, win/lose checks.
class GameEngine {
  final MazeLevel level;

  GameEngine(this.level);

  /// Create the initial game state for this level.
  GameState createInitialState() {
    final startPos = Position(level.startRow, level.startCol);
    return GameState(
      lives: 5,
      currentPosition: startPos,
      path: [startPos],
      cellStates: {startPos: CellState.current},
    );
  }

  /// Attempt to move from the current position by tapping a cell.
  /// Returns the new game state.
  GameState handleTap(GameState state, int row, int col) {
    if (state.isComplete || state.isGameOver) return state;

    final currentPos = state.currentPosition;
    final cell = level.cellAt(currentPos.row, currentPos.col);
    final targetPos = Position(row, col);

    // Check if tapped cell is the current cell
    if (targetPos == currentPos) return state;

    // The player moves in the direction of the arrow at their current position
    final direction = cell.direction;
    final nextRow = currentPos.row + direction.dr;
    final nextCol = currentPos.col + direction.dc;

    // Check if the target matches where the arrow points
    if (row != nextRow || col != nextCol) {
      // Player tapped a cell that isn't the next cell in the arrow direction
      // This is not how the game works - ignore non-adjacent-arrow taps
      return state;
    }

    // Check if movement is blocked by a wall
    if (cell.hasWall(direction)) {
      return _handleWrongMove(state, targetPos);
    }

    // Check bounds
    if (!level.isInBounds(nextRow, nextCol)) {
      return _handleWrongMove(state, targetPos);
    }

    // Check if the next cell has a wall on the incoming side
    final nextCell = level.cellAt(nextRow, nextCol);
    if (nextCell.hasWall(direction.opposite)) {
      return _handleWrongMove(state, targetPos);
    }

    // Valid move!
    return _handleValidMove(state, Position(nextRow, nextCol));
  }

  /// Move in the direction of the current cell's arrow.
  /// This is the simplified control: just tap anywhere or swipe to follow the arrow.
  GameState moveInArrowDirection(GameState state) {
    if (state.isComplete || state.isGameOver) return state;

    final currentPos = state.currentPosition;
    final cell = level.cellAt(currentPos.row, currentPos.col);
    final direction = cell.direction;

    final nextRow = currentPos.row + direction.dr;
    final nextCol = currentPos.col + direction.dc;

    // Check walls and bounds
    if (cell.hasWall(direction) || !level.isInBounds(nextRow, nextCol)) {
      return _handleWrongMove(
          state, Position(currentPos.row, currentPos.col));
    }

    final nextCell = level.cellAt(nextRow, nextCol);
    if (nextCell.hasWall(direction.opposite)) {
      return _handleWrongMove(state, Position(nextRow, nextCol));
    }

    return _handleValidMove(state, Position(nextRow, nextCol));
  }

  /// Player taps a specific direction to move (alternative control).
  GameState moveInDirection(GameState state, Direction direction) {
    if (state.isComplete || state.isGameOver) return state;

    final currentPos = state.currentPosition;
    final cell = level.cellAt(currentPos.row, currentPos.col);

    // Check if the arrow at current position points in the tapped direction
    if (cell.direction != direction) {
      // Wrong direction! The arrow doesn't point that way.
      final nextRow = currentPos.row + direction.dr;
      final nextCol = currentPos.col + direction.dc;
      return _handleWrongMove(state, Position(nextRow, nextCol));
    }

    return moveInArrowDirection(state);
  }

  GameState _handleValidMove(GameState state, Position newPos) {
    final newPath = [...state.path, newPos];
    final newCellStates = Map<Position, CellState>.from(state.cellStates);

    // Mark previous current as correct
    newCellStates[state.currentPosition] = CellState.correct;
    newCellStates[newPos] = CellState.current;

    final isComplete = level.isEnd(newPos.row, newPos.col);

    return state.copyWith(
      currentPosition: newPos,
      path: newPath,
      cellStates: newCellStates,
      isComplete: isComplete,
    );
  }

  GameState _handleWrongMove(GameState state, Position wrongPos) {
    final newLives = state.lives - 1;
    final newCellStates = Map<Position, CellState>.from(state.cellStates);
    newCellStates[wrongPos] = CellState.wrong;

    return state.copyWith(
      lives: newLives,
      cellStates: newCellStates,
      isGameOver: newLives <= 0,
    );
  }

  /// Reset the game state for retry.
  GameState reset() => createInitialState();
}
