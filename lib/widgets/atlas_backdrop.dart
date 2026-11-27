import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/metas.dart';
import '../data/waypoint_points.dart';
import '../state/hidden_timers.dart';
import '../data/waypoints.dart';
import '../services/icon_cache.dart';
import '../state/world_map.dart';
import '../theme.dart';
import 'clock.dart';
import 'common.dart';

/// the home page's ground: the world map of the game, as it is, which can be dragged, with the next events pinned where their
/// waypoints are. a pin opens the wiki page of its event. it sits behind the page: what the page leaves free of its own is the map
class AtlasBackdrop extends ConsumerStatefulWidget {
  const AtlasBackdrop({super.key});

  @override
  ConsumerState<AtlasBackdrop> createState() => _AtlasBackdropState();
}

class _AtlasBackdropState extends ConsumerState<AtlasBackdrop> {
  // the overview level of the default floor: 5 by 7 tiles of 256 pixels, 64 units of the continent to a pixel
  static const _width = 1280.0;
  static const _height = 1792.0;
  static const _unitsPerPixel = 64.0;

  /// where on the continent the window rests to begin with, as a part of its width and height: Kryta, with Lion's Arch
  static const _focusX = 0.55;
  static const _focusY = 0.3;

  /// how much closer than the width of the page the map is drawn to begin with
  static const _closer = 1.35;

  Size _size = Size.zero;

  /// how many screen pixels one pixel of the first level is, and where the map's top left corner is
  double _k = 1;
  Offset _origin = Offset.zero;

  double _minK(Size box) => math.max(box.width / _width, box.height / _height);

  void _reset(Size box) {
    _size = box;
    _k = _minK(box) * _closer;
    _origin =
        _clamp(Offset(box.width * 0.38 - _focusX * _width * _k, box.height * 0.45 - _focusY * _height * _k), _k, box);
  }

  /// the map always covers the window: no edge of it is ever on the page
  Offset _clamp(Offset o, double k, Size box) => Offset(
        o.dx.clamp(math.min(0.0, box.width - _width * k), 0.0),
        o.dy.clamp(math.min(0.0, box.height - _height * k), 0.0),
      );

  @override
  Widget build(BuildContext context) {
    // the pins follow the timers the administrator hides
    ref.watch(shownMetaMapsProvider);
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        if (size != _size) _reset(size);
        return ClipRect(
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // the map is only moved, to see the pins: to look at it closely there is the map page
              onPanUpdate: (d) => setState(() => _origin = _clamp(_origin + d.delta, _k, size)),
              child: Stack(
                children: [
                  ..._tiles(size),
                  ClockBuilder(
                    step: ClockStep.minute,
                    builder: (context, now) => Stack(children: _pins(now, size)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// the tiles in view: the first level all the way down, which has every tile, and over it the level that is nearest to a pixel of the
  /// tile to a pixel of the screen, which has none of the sea
  List<Widget> _tiles(Size box) {
    final level = (math.log(_k / 1.1) / math.ln2).ceil().clamp(0, 2) + 1;
    return [..._level(box, 1), if (level > 1) ..._level(box, level)];
  }

  List<Widget> _level(Size box, int level) {
    final columns = 5 * math.pow(2, level - 1).toInt();
    final rows = 7 * math.pow(2, level - 1).toInt();
    final tile = 256 * _k / math.pow(2, level - 1);
    final x0 = ((-_origin.dx) / tile).floor().clamp(0, columns - 1);
    final x1 = ((box.width - _origin.dx) / tile).ceil().clamp(1, columns);
    final y0 = ((-_origin.dy) / tile).floor().clamp(0, rows - 1);
    final y1 = ((box.height - _origin.dy) / tile).ceil().clamp(1, rows);
    return [
      for (var x = x0; x < x1; x++)
        for (var y = y0; y < y1; y++)
          Positioned(
            key: ValueKey('$level/$x/$y'),
            left: _origin.dx + x * tile,
            top: _origin.dy + y * tile,
            width: tile + 0.6,
            height: tile + 0.6,
            child: level <= 2
                ? Image.asset(
                    'assets/tiles/$defaultFloor/$level/${x}_$y.jpg',
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    // the sea has no tile of its own
                    errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                  )
                : CachedIcon(
                    url: 'https://tiles.guildwars2.com/$worldContinent/$defaultFloor/$level/$x/$y.jpg',
                    fit: BoxFit.fill),
          ),
    ];
  }

  /// the places of the waypoints are a small table that comes with the app: the whole world map, a megabyte, was unpacked on
  /// the home page for five of them
  List<Widget> _pins(DateTime now, Size box) {
    final pins = <Widget>[];
    var first = true;
    for (final o in upNext(now, count: 5, maps: ref.read(shownMetaMapsProvider))) {
      final waypoint = waypointFor(o.map, o.event);
      final point = waypoint == null ? null : waypointPoints[waypoint.code];
      if (point == null) continue;
      final (x, y) = point;
      final dx = _origin.dx + x / _unitsPerPixel * _k;
      final dy = _origin.dy + y / _unitsPerPixel * _k;
      // not under the strip along the top nor under the column of cards at the right: nothing could be read there
      if (dx < 0 || dy < 72 || dx > box.width - 560 || dy > box.height - 140) continue;
      pins.add(Positioned(
        left: dx - 7,
        top: dy - 7,
        child: _Pin(
          label: '${_clock(o.start)} ${o.event.name}',
          strong: first,
          onTap: () => openWikiPage(context, ref, o.event.wiki ?? o.event.name),
        ),
      ));
      first = false;
    }
    return pins;
  }
}

String _clock(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// where an event is: a gold dot with its ring and, beside it, the time and the name. a tap opens the event's wiki page
class _Pin extends StatelessWidget {
  const _Pin({required this.label, required this.strong, required this.onTap});

  final String label;
  final bool strong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold,
                border: Border.all(color: AppColors.surface, width: 2),
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: strong ? 0.45 : 0.28), spreadRadius: 4)],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: strong ? AppColors.gold : AppColors.line),
              ),
              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
