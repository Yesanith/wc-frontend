import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// says that what is under it lies on a picture, the map of the game on the home page: the cards in it are drawn as frosted glass,
/// the picture showing through them, instead of as sheets of paper
class OnMap extends InheritedWidget {
  const OnMap({super.key, required super.child});

  static bool of(BuildContext context) => context.getInheritedWidgetOfExactType<OnMap>() != null;

  @override
  bool updateShouldNotify(OnMap oldWidget) => false;
}

/// a plate of the colour of the page, half see through, with what is behind it blurred
class GlassPlate extends StatelessWidget {
  const GlassPlate({super.key, required this.child, this.radius = AppRadius.card, this.border, this.padding});

  final Widget child;
  final double radius;
  final Color? border;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.72),
            borderRadius: shape,
            border: Border.all(color: border ?? AppColors.surface.withValues(alpha: 0.65)),
          ),
          child: padding == null ? child : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}
