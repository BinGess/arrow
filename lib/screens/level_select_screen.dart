import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2D2D3A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Level',
          style: TextStyle(
            color: Color(0xFF2D2D3A),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: GameProvider.totalLevels,
              itemBuilder: (context, index) {
                final level = index + 1;
                final isUnlocked = level <= provider.unlockedLevel;
                final stars = provider.starsForLevel(level);

                return _LevelTile(
                  level: level,
                  isUnlocked: isUnlocked,
                  stars: stars,
                  onTap: isUnlocked
                      ? () {
                          provider.startLevel(level);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GameScreen(),
                            ),
                          );
                        }
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final bool isUnlocked;
  final int stars;
  final VoidCallback? onTap;

  const _LevelTile({
    required this.level,
    required this.isUnlocked,
    required this.stars,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isUnlocked ? Colors.white : const Color(0xFFE8E5F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnlocked
                ? const Color(0xFF6C63FF).withOpacity(0.3)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isUnlocked) ...[
              Text(
                '$level',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D3A),
                ),
              ),
              if (stars > 0) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < stars ? Icons.favorite : Icons.favorite_border,
                      size: 8,
                      color: i < stars
                          ? const Color(0xFFFF6B8A)
                          : const Color(0xFFCCC2DC),
                    ),
                  ),
                ),
              ],
            ] else
              const Icon(
                Icons.lock,
                size: 20,
                color: Color(0xFFB0A8C4),
              ),
          ],
        ),
      ),
    );
  }
}
