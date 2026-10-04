import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// a gradient ring for "how far along", with an optional label inside
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, this.size = 64, this.stroke = 7, this.child, this.colors});

  final double value;
  final double size;
  final double stroke;
  final Widget? child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, stroke, AppColors.track, colors ?? [AppColors.gold, AppColors.ember]),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.track, this.colors);

  final double value;
  final double stroke;
  final Color track;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (value <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: colors,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.colors != colors;
}

/// a thin bar, in a gradient unless a colour is given
class Meter extends StatelessWidget {
  const Meter({super.key, required this.value, this.height = 6, this.color});

  final double value;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: AppColors.track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 1).toDouble(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: color == null ? LinearGradient(colors: [AppColors.gold, AppColors.ember]) : null,
                  color: color,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// small caps label over a section, with room for an action on the right
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style:
                  TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.hint),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// the card with a soft wash of colour in its top corner
class GlowCard extends StatelessWidget {
  const GlowCard({super.key, required this.child, this.glow, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final Color? glow;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final g = glow;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
        gradient: g == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, 0.55],
                colors: [g.withValues(alpha: 0.14), AppColors.surface],
              ),
      ),
      child: child,
    );
  }
}
