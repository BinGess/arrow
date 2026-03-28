import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/game_engine.dart';
import '../engine/maze_generator.dart';
import '../models/direction.dart';
import '../models/game_state.dart';
import '../models/maze_level.dart';

/// Manages game state and persistence.
class GameProvider extends ChangeNotifier {
  static const int totalLevels = 50;
  static const String _unlockedKey = 'unlocked_level';
  static const String _starsKey = 'level_stars_';

  final MazeGenerator _generator = MazeGenerator();

  int _unlockedLevel = 1;
  int get unlockedLevel => _unlockedLevel;

  MazeLevel? _currentLevel;
  MazeLevel? get currentLevel => _currentLevel;

  GameEngine? _engine;
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
    _engine = GameEngine(_currentLevel!);
    _gameState = _engine!.createInitialState();
    notifyListeners();
  }

  /// Tap on a cell in the maze.
  void tapCell(int row, int col) {
    if (_engine == null || _gameState == null) return;

    final newState = _engine!.handleTap(_gameState!, row, col);
    if (newState != _gameState) {
      _gameState = newState;
      if (newState.isComplete) {
        _onLevelComplete();
      }
      notifyListeners();
    }
  }

  /// Follow the arrow at current position.
  void followArrow() {
    if (_engine == null || _gameState == null) return;

    final newState = _engine!.moveInArrowDirection(_gameState!);
    if (newState != _gameState) {
      _gameState = newState;
      if (newState.isComplete) {
        _onLevelComplete();
      }
      notifyListeners();
    }
  }

  /// Move in a specific direction.
  void move(Direction direction) {
    if (_engine == null || _gameState == null) return;

    final newState = _engine!.moveInDirection(_gameState!, direction);
    if (newState != _gameState) {
      _gameState = newState;
      if (newState.isComplete) {
        _onLevelComplete();
      }
      notifyListeners();
    }
  }

  void _onLevelComplete() {
    if (_currentLevel == null || _gameState == null) return;

    final level = _currentLevel!.levelNumber;
    final stars = _gameState!.lives;

    // Save best stars
    if (stars > (_levelStars[level] ?? 0)) {
      _levelStars[level] = stars;
    }

    // Unlock next level
    if (level >= _unlockedLevel && level < totalLevels) {
      _unlockedLevel = level + 1;
    }

    _saveProgress();
  }

  /// Reset current level.
  void resetLevel() {
    if (_engine == null) return;
    _gameState = _engine!.reset();
    notifyListeners();
  }

  /// Restart current level with a new maze.
  void regenerateLevel() {
    if (_currentLevel == null) return;
    startLevel(_currentLevel!.levelNumber);
  }
}
