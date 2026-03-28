import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/hearts_display.dart';
import '../widgets/arrow_board_widget.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Consumer<GameProvider>(
          builder: (context, provider, _) {
            final state = provider.gameState;
            if (state == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return Stack(
              children: [
                Column(
                  children: [
                    // Header
                    _GameHeader(
                      levelNumber: provider.currentLevelNumber,
                      lives: state.lives,
                      maxLives: state.maxLives,
                      remaining: state.remainingArrows.length,
                      onBack: () => Navigator.pop(context),
                      onReset: () => provider.resetLevel(),
                    ),
                    const Divider(height: 1, color: Color(0xFFE8E5F0)),
                    // Arrow board
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: ArrowBoardWidget(),
                      ),
                    ),
                    // Bottom info
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Text(
                        'Tap arrows to fly them out. Avoid collisions!',
                        style: TextStyle(
                          color: const Color(0xFF9E9E9E),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Completion overlay
                if (state.isComplete)
                  _OverlayBanner(
                    title: 'Level Complete!',
                    titleColor: const Color(0xFF4CAF50),
                    subtitle:
                        'Arrows cleared: ${state.removedOrder.length}',
                    lives: state.lives,
                    actions: [
                      _BannerAction(
                        label: 'Menu',
                        isPrimary: false,
                        onTap: () => Navigator.pop(context),
                      ),
                      _BannerAction(
                        label: 'Next Level',
                        isPrimary: true,
                        onTap: () {
                          final next = provider.currentLevelNumber + 1;
                          if (next <= GameProvider.totalLevels) {
                            provider.startLevel(next);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                if (state.isGameOver)
                  _OverlayBanner(
                    title: 'Game Over',
                    titleColor: const Color(0xFFFF6B8A),
                    subtitle: 'No lives remaining',
                    lives: 0,
                    actions: [
                      _BannerAction(
                        label: 'Menu',
                        isPrimary: false,
                        onTap: () => Navigator.pop(context),
                      ),
                      _BannerAction(
                        label: 'Retry',
                        isPrimary: true,
                        onTap: () => provider.resetLevel(),
                      ),
                    ],
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
  final int remaining;
  final VoidCallback onBack;
  final VoidCallback onReset;

  const _GameHeader({
    required this.levelNumber,
    required this.lives,
    required this.maxLives,
    required this.remaining,
    required this.onBack,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Color(0xFF9E9EAF), size: 22),
            onPressed: onBack,
          ),
          IconButton(
            icon:
                const Icon(Icons.refresh, color: Color(0xFF9E9EAF), size: 24),
            onPressed: onReset,
          ),
          const Spacer(),
          Text(
            'Level $levelNumber',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C63FF),
            ),
          ),
          const Spacer(),
          HeartsDisplay(currentLives: lives, maxLives: maxLives),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _BannerAction {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _BannerAction({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });
}

class _OverlayBanner extends StatelessWidget {
  final String title;
  final Color titleColor;
  final String subtitle;
  final int lives;
  final List<_BannerAction> actions;

  const _OverlayBanner({
    required this.title,
    required this.titleColor,
    required this.subtitle,
    required this.lives,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: titleColor.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                    color: Color(0xFF9E9E9E), fontSize: 14),
              ),
              const SizedBox(height: 16),
              HeartsDisplay(currentLives: lives),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: actions.map((action) {
                  if (action.isPrimary) {
                    return ElevatedButton(
                      onPressed: action.onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: Text(action.label),
                    );
                  }
                  return OutlinedButton(
                    onPressed: action.onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9E9E9E),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: Text(action.label),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
