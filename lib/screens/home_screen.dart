import 'package:flutter/material.dart';
import 'level_select_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // Game icon - pipe/connection visual
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _LogoPainter(),
                ),
              ),
              const SizedBox(height: 32),
              // Title
              const Text(
                'Arrow Maze',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D3A),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap arrows, avoid collisions',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF9E9E9E),
                ),
              ),
              const Spacer(flex: 2),
              // Play button
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LevelSelectScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 200,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'PLAY',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws scattered arrows logo.
class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width * 0.12;

    // Draw several arrows in different directions
    _drawArrow(canvas, cx - s, cy - s * 1.5, -1, 0, s, paint); // up
    _drawArrow(canvas, cx + s, cy - s * 0.5, 1, 0, s, paint);  // down
    _drawArrow(canvas, cx - s * 0.5, cy + s, 0, -1, s, paint); // left
    _drawArrow(canvas, cx + s * 0.5, cy + s * 0.3, 0, 1, s, paint); // right
  }

  void _drawArrow(Canvas canvas, double cx, double cy,
      int dr, int dc, double len, Paint paint) {
    final dx = dc * len;
    final dy = dr * len;
    final tip = Offset(cx + dx, cy + dy);
    final tail = Offset(cx - dx * 0.5, cy - dy * 0.5);
    canvas.drawLine(tail, tip, paint);
    // Head
    final hl = len * 0.4;
    if (dc != 0) {
      canvas.drawLine(tip, Offset(tip.dx - dc * hl, tip.dy - hl * 0.5), paint);
      canvas.drawLine(tip, Offset(tip.dx - dc * hl, tip.dy + hl * 0.5), paint);
    } else {
      canvas.drawLine(tip, Offset(tip.dx - hl * 0.5, tip.dy - dr * hl), paint);
      canvas.drawLine(tip, Offset(tip.dx + hl * 0.5, tip.dy - dr * hl), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
