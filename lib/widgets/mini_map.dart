import 'package:material_ui/material_ui.dart';

import '../state/world_map.dart';
import '../theme.dart';

/// a small window on the map of the game with a point at the middle of it, from the overview tiles shipped with the app: where a
/// waypoint, and so an event, is. [x] and [y] are continent coordinates
class MiniMap extends StatelessWidget {
  const MiniMap({super.key, required this.x, required this.y, this.height = 150});

  final double x;
  final double y;
  final double height;

  // screen pixels to a pixel of the first level, which is 64 units of the continent
  static const _k = 1.6;
  static const _unitsPerPixel = 64.0;
  static const _sea = Color(0xFF14505C);

  List<Widget> _level(int level, double width, Offset origin) {
    final columns = 5 * (1 << (level - 1));
    final rows = 7 * (1 << (level - 1));
    final tile = 256 * _k / (1 << (level - 1));
    final x0 = ((-origin.dx) / tile).floor().clamp(0, columns - 1);
    final x1 = ((width - origin.dx) / tile).ceil().clamp(1, columns);
    final y0 = ((-origin.dy) / tile).floor().clamp(0, rows - 1);
    final y1 = ((height - origin.dy) / tile).ceil().clamp(1, rows);
    return [
      for (var tx = x0; tx < x1; tx++)
        for (var ty = y0; ty < y1; ty++)
          Positioned(
            left: origin.dx + tx * tile,
            top: origin.dy + ty * tile,
            width: tile + 0.6,
            height: tile + 0.6,
            child: Image.asset(
              'assets/tiles/$defaultFloor/$level/${tx}_$ty.jpg',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: height,
        decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(10)),
        child: LayoutBuilder(
          builder: (context, box) {
            final origin = Offset(box.maxWidth / 2 - x / _unitsPerPixel * _k, height / 2 - y / _unitsPerPixel * _k);
            return Stack(
              children: [
                const Positioned.fill(child: ColoredBox(color: _sea)),
                ..._level(1, box.maxWidth, origin),
                ..._level(2, box.maxWidth, origin),
                Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.45), spreadRadius: 5)],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
