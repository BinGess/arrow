import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/puzzle_generator.dart';
import '../engine/puzzle_solver.dart';
import '../models/game_state.dart';
import '../models/puzzle_level.dart';
import '../models/puzzle_tile.dart';

/// Manages game state, level progression, and persistence.
class GameProvider extends ChangeNotifier {
  static const int totalLevels = 50;
  static const String _unlockedKey = 'unlocked_level';
  static const String _starsKey = 'level_stars_';

  final PuzzleGenerator _generator = PuzzleGenerator();

  int _unlockedLevel = 1;
  int get unlockedLevel => _unlockedLevel;

  PuzzleLevel? _currentLevel;
  PuzzleLevel? get currentLevel => _currentLevel;

  GameState? _gameState;
  GameState? get gameState => _gameState;

  final Map<int, int> _levelStars = {};

  GameProvider() {
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _unlockedLevel = prefs.getInt(_unlockedKey) ?? 1;
      for (var i = 1; i <= totalLevels; i++) {
        _levelStars[i] = prefs.getInt('$_starsKey$i') ?? 0;
      }
      notifyListeners();
    } catch (_) {
      // SharedPreferences not available, use defaults
    }
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unlockedKey, _unlockedLevel);
      for (final entry in _levelStars.entries) {
        await prefs.setInt('$_starsKey${entry.key}', entry.value);
      }
    } catch (_) {
      // Ignore save errors
    }
  }

  int starsForLevel(int level) => _levelStars[level] ?? 0;

  /// Start a specific level.
  void startLevel(int levelNumber) {
    _currentLevel = _generator.generate(levelNumber);
    final connected = PuzzleSolver.findConnectedTiles(_currentLevel!);
    _gameState = GameState(
      lives: 5,
      connectedTiles: connected,
    );
    notifyListeners();
  }

  /// Rotate a tile at the given position.
  void rotateTile(int row, int col) {
    if (_currentLevel == null || _gameState == null) return;
    if (_gameState!.isComplete || _gameState!.isGameOver) return;

    final tile = _currentLevel!.tileAt(row, col);
    if (tile.isFixed) return;

    // Rotate the tile
    final rotatedTile = tile.rotated();

    // Update the grid
    final newGrid = List.generate(_currentLevel!.rows, (r) {
      return List.generate(_currentLevel!.cols, (c) {
        if (r == row && c == col) return rotatedTile;
        return _currentLevel!.grid[r][c];
      });
    });

    _currentLevel = PuzzleLevel(
      levelNumber: _currentLevel!.levelNumber,
      rows: _currentLevel!.rows,
      cols: _currentLevel!.cols,
      grid: newGrid,
      solutionRotations: _currentLevel!.solutionRotations,
    );

    // Recompute connectivity
    final connected = PuzzleSolver.findConnectedTiles(_currentLevel!);
    final isSolved = PuzzleSolver.isSolved(_currentLevel!);
    final moveCount = _gameState!.moveCount + 1;

    _gameState = _gameState!.copyWith(
      moveCount: moveCount,
      connectedTiles: connected,
      isComplete: isSolved,
    );

    if (isSolved) {
      _onLevelComplete();
    }

    notifyListeners();
  }

  void _onLevelComplete() {
    if (_currentLevel == null || _gameState == null) return;

    final level = _currentLevel!.levelNumber;

    // Stars based on remaining lives
    final stars = _gameState!.lives;
    if (stars > (_levelStars[level] ?? 0)) {
      _levelStars[level] = stars;
    }

    // Unlock next level
    if (level >= _unlockedLevel && level < totalLevels) {
      _unlockedLevel = level + 1;
    }

    _saveProgress();
  }

  /// Reset current level (re-scramble).
  void resetLevel() {
    if (_currentLevel == null) return;
    startLevel(_currentLevel!.levelNumber);
  }

  /// Hint: reveal one tile's correct rotation.
  void useHint() {
    if (_currentLevel == null || _gameState == null) return;
    if (_gameState!.lives <= 0) return;
    if (_gameState!.isComplete) return;

    // Find a tile that isn't in its solution rotation
    for (var r = 0; r < _currentLevel!.rows; r++) {
      for (var c = 0; c < _currentLevel!.cols; c++) {
        final tile = _currentLevel!.tileAt(r, c);
        final solutionRot = _currentLevel!.solutionRotations[r][c];
        if (!tile.isFixed && tile.rotation != solutionRot) {
          // Set this tile to solution rotation
          final correctedTile = PuzzleTile(
            row: r,
            col: c,
            type: tile.type,
            rotation: solutionRot,
            isFixed: true, // Lock it after hint
            hasArrow: tile.hasArrow,
            arrowDirection: tile.arrowDirection,
            isSource: tile.isSource,
            isTarget: tile.isTarget,
          );

          final newGrid = List.generate(_currentLevel!.rows, (gr) {
            return List.generate(_currentLevel!.cols, (gc) {
              if (gr == r && gc == c) return correctedTile;
              return _currentLevel!.grid[gr][gc];
            });
          });

          _currentLevel = PuzzleLevel(
            levelNumber: _currentLevel!.levelNumber,
            rows: _currentLevel!.rows,
            cols: _currentLevel!.cols,
            grid: newGrid,
            solutionRotations: _currentLevel!.solutionRotations,
          );

          // Cost: 1 life
          final connected = PuzzleSolver.findConnectedTiles(_currentLevel!);
          final isSolved = PuzzleSolver.isSolved(_currentLevel!);

          _gameState = _gameState!.copyWith(
            lives: _gameState!.lives - 1,
            connectedTiles: connected,
            isComplete: isSolved,
            isGameOver: _gameState!.lives - 1 <= 0 && !isSolved,
          );

          if (isSolved) _onLevelComplete();
          notifyListeners();
          return;
        }
      }
    }
  }
}
