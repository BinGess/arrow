import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'tile_widget.dart';

/// Renders the entire puzzle grid of rotatable tiles.
class PuzzleGridWidget extends StatelessWidget {
  const PuzzleGridWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, _) {
        final level = provider.currentLevel;
        final state = provider.gameState;
        if (level == null || state == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth - 24;
            final maxHeight = constraints.maxHeight - 24;
            final cellW = maxWidth / level.cols;
            final cellH = maxHeight / level.rows;
            final cellSize = cellW < cellH ? cellW : cellH;
            final gridWidth = cellSize * level.cols;
            final gridHeight = cellSize * level.rows;

            return Center(
              child: SizedBox(
                width: gridWidth,
                height: gridHeight,
                child: Stack(
                  children: List.generate(level.rows * level.cols, (index) {
                    final row = index ~/ level.cols;
                    final col = index % level.cols;
                    final tile = level.tileAt(row, col);
                    final isActive = state.connectedTiles.contains((row, col));

                    return Positioned(
                      left: col * cellSize,
                      top: row * cellSize,
                      width: cellSize,
                      height: cellSize,
                      child: TileWidget(
                        key: ValueKey('tile_${row}_$col'),
                        tile: tile,
                        isActive: isActive,
                        size: cellSize,
                        onTap: tile.isFixed
                            ? null
                            : () => provider.rotateTile(row, col),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
