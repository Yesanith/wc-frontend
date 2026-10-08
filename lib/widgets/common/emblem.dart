import 'package:flutter/material.dart';

import '../../theme.dart';

/// the diamond emblem, drawn on the start screen and the hero card
class DiamondEmblem extends StatelessWidget {
  const DiamondEmblem({super.key, required this.size, this.color, this.filled = true});

  final double size;

  /// the gold of the palette when none is given
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _EmblemPainter(color ?? AppColors.gold, filled)),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  const _EmblemPainter(this.color, this.filled);

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width > 90 ? 2 : 1.6;
    final cx = size.width / 2;
    final cy = size.height / 2;

    Path diamond(double r) => Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();

    canvas.drawPath(diamond(size.width / 2 - 2), stroke);
    canvas.drawPath(diamond(size.width / 2 - size.width * 0.22), stroke);
    if (filled) {
      canvas.drawPath(diamond(size.width * 0.1), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}

/// the night sky the plugin paints behind its live preview: a deep blue
/// fading to black with a scatter of four pointed stars. the stars sit in
/// the same places every time, from a fixed seed
class StageHero extends StatelessWidget {
  const StageHero({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.window),
        border: Border.all(color: AppColors.line),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [AppColors.skyTop, AppColors.skyBottom],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: const _StarsPainter(),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // a small linear congruential generator, so the sky is the same on every build
    var seed = 20260926;
    double next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final count = (size.width * size.height / 2600).clamp(14, 60).round();
    for (var i = 0; i < count; i++) {
      final at = Offset(next() * size.width, next() * size.height);
      final big = next() > 0.82;
      final r = big ? 3.2 + next() * 1.6 : 0.9 + next() * 0.8;
      final alpha = big ? 0.9 : 0.35 + next() * 0.4;
      final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
      if (big) {
        // a four pointed sparkle
        final path = Path()
          ..moveTo(at.dx, at.dy - r)
          ..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
          ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)
          ..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
          ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(at, r * 0.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => false;
}
