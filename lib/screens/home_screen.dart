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
                'Rotate tiles, connect the path',
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

/// Draws a simple connected-pipes logo.
class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final seg = size.width * 0.18;

    // Draw a connected path pattern
    final path = Path();
    // Horizontal line
    path.moveTo(cx - seg * 1.5, cy);
    path.lineTo(cx + seg * 1.5, cy);
    // Vertical from center up
    path.moveTo(cx, cy - seg * 1.5);
    path.lineTo(cx, cy);
    // Corner piece going right then down
    path.moveTo(cx + seg * 1.5, cy);
    path.lineTo(cx + seg * 1.5, cy + seg * 1.2);
    // Vertical left side
    path.moveTo(cx - seg * 1.5, cy);
    path.lineTo(cx - seg * 1.5, cy - seg * 1.2);

    canvas.drawPath(path, paint);

    // Draw nodes at junctions
    final nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 5, nodePaint);
    canvas.drawCircle(Offset(cx - seg * 1.5, cy), 4, nodePaint);
    canvas.drawCircle(Offset(cx + seg * 1.5, cy), 4, nodePaint);

    // Arrow indicator
    final arrowPaint = Paint()
      ..color = const Color(0xFFFF6B8A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // Small arrow pointing right near center
    canvas.drawLine(
      Offset(cx + 5, cy - seg * 1.2),
      Offset(cx + seg, cy - seg * 1.2),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(cx + seg, cy - seg * 1.2),
      Offset(cx + seg - 6, cy - seg * 1.2 - 5),
      arrowPaint,
    );
    canvas.drawLine(
      Offset(cx + seg, cy - seg * 1.2),
      Offset(cx + seg - 6, cy - seg * 1.2 + 5),
      arrowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
