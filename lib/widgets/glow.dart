import 'package:material_ui/material_ui.dart';

/// a soft round light behind the first page and the sign in, fading to nothing at its edge
class Glow extends StatelessWidget {
  const Glow({super.key, required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
