import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/hearts_display.dart';
import '../widgets/maze_grid_widget.dart';

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
                  onBack: () => Navigator.pop(context),
                  onReset: () => provider.resetLevel(),
                ),
                const Divider(height: 1, color: Color(0xFFE8E5F0)),
                // Maze
                Expanded(
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      // Swipe support: follow the current arrow direction
                      provider.followArrow();
                    },
                    onHorizontalDragEnd: (details) {
                      provider.followArrow();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: MazeGridWidget(),
                    ),
                  ),
                ),
                // Bottom action bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: _FollowArrowButton(
                    onPressed: state.isComplete || state.isGameOver
                        ? null
                        : () => provider.followArrow(),
                  ),
                ),
                // Completion / Game Over overlays
                if (state.isComplete)
                  _CompletionBanner(
                    lives: state.lives,
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
  final VoidCallback onBack;
  final VoidCallback onReset;

  const _GameHeader({
    required this.levelNumber,
    required this.lives,
    required this.maxLives,
    required this.onBack,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Color(0xFF9E9EAF), size: 22),
            onPressed: onBack,
          ),
          // Reset button
          IconButton(
            icon: const Icon(Icons.refresh,
                color: Color(0xFF9E9EAF), size: 24),
            onPressed: onReset,
          ),
          const Spacer(),
          // Level label
          Text(
            'Level $levelNumber',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C63FF),
            ),
          ),
          const Spacer(),
          // Hearts
          HeartsDisplay(currentLives: lives, maxLives: maxLives),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _FollowArrowButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _FollowArrowButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 4,
        ),
        child: const Text(
          'Follow Arrow',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  final int lives;
  final VoidCallback onNext;
  final VoidCallback onMenu;

  const _CompletionBanner({
    required this.lives,
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
            'No lives remaining',
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
