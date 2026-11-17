import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/metas.dart';
import '../data/waypoints.dart';
import '../state/navigation.dart';
import '../state/world_map.dart';
import '../theme.dart';
import 'clock.dart';

/// the home page's ground: the world map of the game, from the overview tiles shipped with the app, under a wash of the colour of the
/// page, with the next events pinned where their waypoints are. it only sits behind the page, nothing of the page is on it
class AtlasBackdrop extends ConsumerWidget {
  const AtlasBackdrop({super.key});

  // the overview level of the default floor: 5 by 7 tiles of 256 pixels, 64 units of the continent to a pixel
  static const _width = 1280.0;
  static const _height = 1792.0;
  static const _tile = 256.0;
  static const _unitsPerPixel = 64.0;
  static const _columns = 5;
  static const _rows = 7;

  /// where on the continent the window rests, as a part of its width and height: Kryta, with Lion's Arch, and the maps round it
  static const _focusX = 0.55;
  static const _focusY = 0.3;

  /// how much closer than the width of the page the map is drawn
  static const _closer = 1.35;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final markers = ref.watch(worldMarkersProvider(defaultFloor)).valueOrNull ?? const <MapMarker>[];
    return LayoutBuilder(
      builder: (context, box) {
        // a little closer than the page is wide, so that the land fills the free side of the page and the columns at the other side
        // cover only the sea
        final scale = math.max(box.maxWidth / _width, box.maxHeight / _height) * _closer;
        final mapWidth = _width * scale;
        final mapHeight = _height * scale;
        final left = (box.maxWidth * 0.38 - _focusX * mapWidth).clamp(box.maxWidth - mapWidth, 0.0);
        final top = (box.maxHeight * 0.45 - _focusY * mapHeight).clamp(box.maxHeight - mapHeight, 0.0);
        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: mapWidth,
                height: mapHeight,
                child: Stack(
                  children: [
                    for (var x = 0; x < _columns; x++)
                      for (var y = 0; y < _rows; y++)
                        Positioned(
                          left: x * _tile * scale,
                          top: y * _tile * scale,
                          width: _tile * scale + 0.6,
                          height: _tile * scale + 0.6,
                          child: Image.asset(
                            'assets/tiles/$defaultFloor/1/${x}_$y.jpg',
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                          ),
                        ),
                  ],
                ),
              ),
              // the wash: the page's own colour, so that what is on the page reads as it does without a map
              Positioned.fill(child: ColoredBox(color: AppColors.bg.withValues(alpha: AppColors.isDark ? 0.74 : 0.86))),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.0,
                      colors: [Colors.transparent, AppColors.bg.withValues(alpha: 0.55)],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
              ),
              ClockBuilder(
                step: ClockStep.minute,
                builder: (context, now) {
                  final byCode = {
                    for (final m in markers)
                      if (m.kind == 'waypoint') m.chatLink: m
                  };
                  final pins = <Widget>[];
                  var first = true;
                  for (final o in upNext(now, count: 5)) {
                    final waypoint = waypointFor(o.map, o.event);
                    final marker = waypoint == null ? null : byCode[waypoint.code];
                    if (marker == null) continue;
                    final dx = left + marker.x / _unitsPerPixel * scale;
                    final dy = top + marker.y / _unitsPerPixel * scale;
                    // not under the strip along the top nor under the column of cards at the right: nothing could be read there
                    if (dx < 0 || dy < 72 || dx > box.maxWidth - 420 || dy > box.maxHeight - 140) continue;
                    pins.add(Positioned(
                      left: dx - 7,
                      top: dy - 7,
                      child: _Pin(label: '${_clock(o.start)} ${o.event.name}', strong: first),
                    ));
                    first = false;
                  }
                  return Stack(children: pins);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

String _clock(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// where an event is: a gold dot with its ring and, beside it, the time and the name
class _Pin extends ConsumerWidget {
  const _Pin({required this.label, required this.strong});

  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(sectionProvider.notifier).state = AppSection.maps,
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
