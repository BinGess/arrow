import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/hearts_display.dart';
import '../widgets/puzzle_grid_widget.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Consumer<GameProvider>(
          builder: (context, provider, _) {
            final level = provider.currentLevel;
            final state = provider.gameState;
            if (level == null || state == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                // Header
                _GameHeader(
                  levelNumber: level.levelNumber,
                  lives: state.lives,
                  maxLives: state.maxLives,
                  moveCount: state.moveCount,
                  onBack: () => Navigator.pop(context),
                  onReset: () => provider.resetLevel(),
                ),
                const Divider(height: 1, color: Color(0xFFE8E5F0)),
                // Puzzle grid
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: PuzzleGridWidget(),
                  ),
                ),
                // Bottom bar with hint button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tap tiles to rotate',
                          style: TextStyle(
                            color: const Color(0xFF9E9E9E),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _HintButton(
                        lives: state.lives,
                        enabled: !state.isComplete && !state.isGameOver,
                        onPressed: () => provider.useHint(),
                      ),
                    ],
                  ),
                ),
                // Completion overlay
                if (state.isComplete)
                  _CompletionBanner(
                    lives: state.lives,
                    moveCount: state.moveCount,
                    onNext: () {
                      final nextLevel = level.levelNumber + 1;
                      if (nextLevel <= GameProvider.totalLevels) {
                        provider.startLevel(nextLevel);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    onMenu: () => Navigator.pop(context),
                  ),
                if (state.isGameOver)
                  _GameOverBanner(
                    onRetry: () => provider.resetLevel(),
                    onMenu: () => Navigator.pop(context),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GameHeader extends StatelessWidget {
  final int levelNumber;
  final int lives;
  final int maxLives;
  final int moveCount;
  final VoidCallback onBack;
  final VoidCallback onReset;

  const _GameHeader({
    required this.levelNumber,
    required this.lives,
    required this.maxLives,
    required this.moveCount,
    required this.onBack,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Color(0xFF9E9EAF), size: 22),
            onPressed: onBack,
          ),
          IconButton(
            icon: const Icon(Icons.refresh,
                color: Color(0xFF9E9EAF), size: 24),
            onPressed: onReset,
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                'Level $levelNumber',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6C63FF),
                ),
              ),
            ],
          ),
          const Spacer(),
          HeartsDisplay(currentLives: lives, maxLives: maxLives),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  final int lives;
  final bool enabled;
  final VoidCallback onPressed;

  const _HintButton({
    required this.lives,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final canUse = enabled && lives > 0;
    return GestureDetector(
      onTap: canUse ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: canUse
              ? const Color(0xFFFF9800).withOpacity(0.1)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: canUse
                ? const Color(0xFFFF9800).withOpacity(0.3)
                : const Color(0xFFE0E0E0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 18,
              color: canUse
                  ? const Color(0xFFFF9800)
                  : const Color(0xFFBDBDBD),
            ),
            const SizedBox(width: 4),
            Text(
              'Hint',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: canUse
                    ? const Color(0xFFFF9800)
                    : const Color(0xFFBDBDBD),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  final int lives;
  final int moveCount;
  final VoidCallback onNext;
  final VoidCallback onMenu;

  const _CompletionBanner({
    required this.lives,
    required this.moveCount,
    required this.onNext,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Level Complete!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Moves: $moveCount',
            style: const TextStyle(color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 12),
          HeartsDisplay(currentLives: lives),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: onMenu,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9E9E9E),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Menu'),
              ),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Next Level'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameOverBanner extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  const _GameOverBanner({
    required this.onRetry,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B8A).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Game Over',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF6B8A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No hints remaining',
            style: TextStyle(color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              OutlinedButton(
                onPressed: onMenu,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9E9E9E),
                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Menu'),
              ),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
