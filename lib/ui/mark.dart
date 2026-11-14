import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_engine/game_engine.dart';

import 'theme.dart';

/// Draws an X or an O that strokes itself in when it first appears.
class MarkView extends StatelessWidget {
  const MarkView({super.key, required this.mark});

  final Mark mark;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion(context, 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Transform.scale(
        scale: 0.6 + 0.4 * Curves.easeOutBack.transform(t),
        child: CustomPaint(
          painter: _MarkPainter(mark, t),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.mark, this.progress);

  final Mark mark;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 0.12;
    final inset = s * 0.22;
    final rect = Rect.fromCenter(
        center: size.center(Offset.zero), width: s - inset * 2, height: s - inset * 2);
    final paint = Paint()
      ..color = mark == Mark.x ? ArenaColors.x : ArenaColors.o
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (mark == Mark.o) {
      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, paint);
      return;
    }
    // X: first stroke, then second.
    final a = (progress * 2).clamp(0.0, 1.0);
    final b = (progress * 2 - 1).clamp(0.0, 1.0);
    canvas.drawLine(rect.topLeft, Offset.lerp(rect.topLeft, rect.bottomRight, a)!, paint);
    if (b > 0) {
      canvas.drawLine(rect.topRight, Offset.lerp(rect.topRight, rect.bottomLeft, b)!, paint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.progress != progress || old.mark != mark;
}

/// The app's logo: a small 3×3 board with a winning diagonal.
class ArenaLogo extends StatelessWidget {
  const ArenaLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    const layout = ['X', 'O', '', '', 'X', 'O', '', '', 'X'];
    final surface = Theme.of(context).colorScheme.surface;
    return SizedBox.square(
      dimension: size,
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: size * 0.05,
        crossAxisSpacing: size * 0.05,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 9; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                color: i % 4 == 0
                    ? ArenaColors.win.withValues(alpha: 0.35)
                    : surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(size * 0.08),
              ),
              child: layout[i].isEmpty
                  ? null
                  : MarkView(mark: layout[i] == 'X' ? Mark.x : Mark.o),
            ),
        ],
      ),
    );
  }
}
