import 'package:flutter/material.dart';

/// Displays the player's remaining lives as hearts.
class HeartsDisplay extends StatelessWidget {
  final int currentLives;
  final int maxLives;

  const HeartsDisplay({
    super.key,
    required this.currentLives,
    this.maxLives = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLives, (index) {
        final isFilled = index < currentLives;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            isFilled ? Icons.favorite : Icons.favorite_border,
            color: isFilled
                ? const Color(0xFFFF6B8A)
                : const Color(0xFFCCC2DC),
            size: 24,
          ),
        );
      }),
    );
  }
}
