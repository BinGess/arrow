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

  List<Arrow> _originalArrows = [];
  final Map<int, int> _levelStars = {};

  /// Currently flying arrows (supports multiple simultaneous fly-outs).
  final List<Arrow> _flyingArrows = [];
  List<Arrow> get flyingArrows => List.unmodifiable(_flyingArrows);

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

  void startLevel(int levelNumber) {
    _currentLevelNumber = levelNumber;
    final result = _generator.generate(levelNumber);
    _gridRows = result.rows;
    _gridCols = result.cols;
    _originalArrows = List.of(result.arrows);
    _engine = GameEngine(rows: _gridRows, cols: _gridCols);
    _gameState = _engine!.createInitialState(result.arrows);
    _flyingArrows.clear();
    notifyListeners();
  }

  /// Tap an arrow. No animation blocking - taps are always responsive.
  void tapArrow(int arrowId) {
    if (_engine == null || _gameState == null) return;
    if (_gameState!.isComplete || _gameState!.isGameOver) return;

    final arrow = _gameState!.remainingArrows
        .where((a) => a.id == arrowId)
        .firstOrNull;
    if (arrow == null) return;

    final (newState, result, _) = _engine!.tapArrow(_gameState!, arrowId);
    _gameState = newState;

    if (result == TapResult.success) {
      // Add to flying list (animation is visual-only, doesn't block input)
      _flyingArrows.add(arrow);
      notifyListeners();

      // Clean up after animation finishes
      final animMs = _animDuration(arrow);
      Future.delayed(Duration(milliseconds: animMs), () {
        _flyingArrows.remove(arrow);
        if (newState.isComplete) {
          _onLevelComplete();
        }
        notifyListeners();
      });
    } else {
      // Collision flash
      notifyListeners();
      Future.delayed(const Duration(milliseconds: 500), () {
        _gameState = _gameState?.copyWith(clearCollision: true);
        notifyListeners();
      });
    }
  }

  /// Animation duration for an arrow (ms).
  int _animDuration(Arrow arrow) {
    final bodyLen = arrow.occupiedCells.length;
    final exitCells = (_gridRows > _gridCols ? _gridRows : _gridCols) + 2;
    return (120 + bodyLen * 40 + exitCells * 25).clamp(200, 700);
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

  void resetLevel() {
    if (_engine == null) return;
    _gameState = _engine!.createInitialState(_originalArrows);
    _flyingArrows.clear();
    notifyListeners();
  }

  void regenerateLevel() {
    startLevel(_currentLevelNumber);
  }
}
