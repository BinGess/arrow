import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/game_engine.dart';
import '../engine/level_generator.dart';
import '../models/arrow.dart';
import '../models/game_state.dart';

/// Manages game state, level progression, and persistence.
class GameProvider extends ChangeNotifier {
  static const int totalLevels = 50;
  static const String _unlockedKey = 'unlocked_level';
  static const String _starsKey = 'level_stars_';

  final LevelGenerator _generator = LevelGenerator();

  int _unlockedLevel = 1;
  int get unlockedLevel => _unlockedLevel;

  int _currentLevelNumber = 0;
  int get currentLevelNumber => _currentLevelNumber;

  int _gridRows = 0;
  int get gridRows => _gridRows;
  int _gridCols = 0;
  int get gridCols => _gridCols;

  GameEngine? _engine;
  GameState? _gameState;
  GameState? get gameState => _gameState;

  /// The original arrows for the current level (for reset).
  List<Arrow> _originalArrows = [];

  final Map<int, int> _levelStars = {};

  /// Arrow currently flying (for animation).
  Arrow? _flyingArrow;
  Arrow? get flyingArrow => _flyingArrow;

  /// Whether a fly animation is in progress.
  bool _isAnimating = false;
  bool get isAnimating => _isAnimating;

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
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unlockedKey, _unlockedLevel);
      for (final entry in _levelStars.entries) {
        await prefs.setInt('$_starsKey${entry.key}', entry.value);
      }
    } catch (_) {}
  }

  int starsForLevel(int level) => _levelStars[level] ?? 0;

  /// Start a specific level.
  void startLevel(int levelNumber) {
    _currentLevelNumber = levelNumber;
    final result = _generator.generate(levelNumber);
    _gridRows = result.rows;
    _gridCols = result.cols;
    _originalArrows = List.of(result.arrows);
    _engine = GameEngine(rows: _gridRows, cols: _gridCols);
    _gameState = _engine!.createInitialState(result.arrows);
    _flyingArrow = null;
    _isAnimating = false;
    notifyListeners();
  }

  /// Tap an arrow to try to fly it out.
  void tapArrow(int arrowId) {
    if (_engine == null || _gameState == null) return;
    if (_isAnimating) return;
    if (_gameState!.isComplete || _gameState!.isGameOver) return;

    // Find the arrow being tapped
    final arrow = _gameState!.remainingArrows
        .where((a) => a.id == arrowId)
        .firstOrNull;
    if (arrow == null) return;

    final (newState, result, hitArrow) =
        _engine!.tapArrow(_gameState!, arrowId);

    if (result == TapResult.success) {
      // Start fly-out animation
      _flyingArrow = arrow;
      _isAnimating = true;
      _gameState = newState;
      notifyListeners();

      // Duration matches the snake animation controller
      final bodyLen = arrow.occupiedCells.length;
      final animMs = (150 + bodyLen * 50 + 12 * 30).clamp(200, 800) + 50;
      Future.delayed(Duration(milliseconds: animMs), () {
        _flyingArrow = null;
        _isAnimating = false;
        if (newState.isComplete) {
          _onLevelComplete();
        }
        notifyListeners();
      });
    } else {
      // Collision - flash the colliding arrows
      _flyingArrow = arrow;
      _isAnimating = true;
      _gameState = newState;
      notifyListeners();

      Future.delayed(const Duration(milliseconds: 600), () {
        _flyingArrow = null;
        _isAnimating = false;
        _gameState = _gameState?.copyWith(clearCollision: true);
        notifyListeners();
      });
    }
  }

  void _onLevelComplete() {
    if (_gameState == null) return;
    final level = _currentLevelNumber;
    final stars = _gameState!.lives;

    if (stars > (_levelStars[level] ?? 0)) {
      _levelStars[level] = stars;
    }
    if (level >= _unlockedLevel && level < totalLevels) {
      _unlockedLevel = level + 1;
    }
    _saveProgress();
  }

  /// Reset current level.
  void resetLevel() {
    if (_engine == null) return;
    _gameState = _engine!.createInitialState(_originalArrows);
    _flyingArrow = null;
    _isAnimating = false;
    notifyListeners();
  }

  /// Regenerate with a new layout.
  void regenerateLevel() {
    startLevel(_currentLevelNumber);
  }
}
