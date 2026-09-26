import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/icon_cache.dart';
import '../state/settings.dart';
import '../state/world_map.dart';
import '../theme.dart';

const _tileHost = 'https://tiles.guildwars2.com';
const _tile = 256.0;

/// where the map opens, roughly lion's arch
const _startCenter = Offset(49000, 31500);
const _startZoom = 3.0;

/// markers drawn at once, the rest wait until you zoom in further
const _markerBudget = 350;

/// the whole of tyria: drag to pan, pinch or double tap to zoom. region names
/// far out, map names closer, then waypoints, then everything else
class WorldMapScreen extends ConsumerStatefulWidget {
  const WorldMapScreen({super.key});

  @override
  ConsumerState<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends ConsumerState<WorldMapScreen> {
  int _floor = defaultFloor;
  double _zoom = _startZoom;
  Offset _center = _startCenter;
  Size _viewport = Size.zero;

  // gesture start values
  double _gestureZoom = _startZoom;
  Offset _gestureWorld = Offset.zero;
  Offset? _doubleTapAt;

  final Set<String> _layers = {...markerKinds};
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// screen pixels per continent unit at the current zoom
  double _scale(ContinentInfo info) => math.pow(2, _zoom - info.maxZoom).toDouble();

  Offset _toScreen(ContinentInfo info, double x, double y) {
    final s = _scale(info);
    return Offset((x - _center.dx) * s + _viewport.width / 2, (y - _center.dy) * s + _viewport.height / 2);
  }

  Offset _toWorld(ContinentInfo info, Offset screen, {double? zoom, Offset? center}) {
    final s = math.pow(2, (zoom ?? _zoom) - info.maxZoom).toDouble();
    final c = center ?? _center;
    return Offset(c.dx + (screen.dx - _viewport.width / 2) / s, c.dy + (screen.dy - _viewport.height / 2) / s);
  }

  Offset _clampCenter(ContinentInfo info, Offset c) =>
      Offset(c.dx.clamp(0, info.width).toDouble(), c.dy.clamp(0, info.height).toDouble());

  void _zoomAround(ContinentInfo info, Offset screenPoint, double newZoom) {
    // keep the point under the finger where it is
    final world = _toWorld(info, screenPoint);
    final zoom = newZoom.clamp(info.minZoom.toDouble(), info.maxZoom + 1.0).toDouble();
    final s = math.pow(2, zoom - info.maxZoom).toDouble();
    setState(() {
      _zoom = zoom;
      _center = _clampCenter(
        info,
        Offset(world.dx - (screenPoint.dx - _viewport.width / 2) / s, world.dy - (screenPoint.dy - _viewport.height / 2) / s),
      );
    });
  }

  void _flyTo(ContinentInfo info, MapMarker m) {
    _searchFocus.unfocus();
    setState(() {
      _center = _clampCenter(info, Offset(m.x, m.y));
      _zoom = math.max(_zoom, m.kind == 'map' || m.kind == 'region' ? 4.8 : 6.3);
      _query = '';
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final info = ref.watch(continentProvider).valueOrNull;
    final markers = ref.watch(worldMarkersProvider(_floor));
    final icons = ref.watch(markerIconsProvider).valueOrNull ?? const <String, String>{};

    if (info == null) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        final list = markers.valueOrNull ?? const <MapMarker>[];
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (d) {
                  _gestureZoom = _zoom;
                  _gestureWorld = _toWorld(info, d.localFocalPoint);
                },
                onScaleUpdate: (d) {
                  final zoom = (_gestureZoom + math.log(d.scale) / math.ln2)
                      .clamp(info.minZoom.toDouble(), info.maxZoom + 1.0)
                      .toDouble();
                  final sc = math.pow(2, zoom - info.maxZoom).toDouble();
                  setState(() {
                    _zoom = zoom;
                    _center = _clampCenter(
                      info,
                      Offset(
                        _gestureWorld.dx - (d.localFocalPoint.dx - _viewport.width / 2) / sc,
                        _gestureWorld.dy - (d.localFocalPoint.dy - _viewport.height / 2) / sc,
                      ),
                    );
                  });
                },
                onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                onDoubleTap: () => _zoomAround(info, _doubleTapAt ?? _viewport.center(Offset.zero), _zoom + 1),
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(child: Container(color: const Color(0xFF0C1A22))),
                      ..._tiles(info),
                      ..._labels(info, list),
                      ..._markers(info, list, icons, s),
                    ],
                  ),
                ),
              ),
            ),
            // search on top, results under it
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: _SearchBox(
                controller: _search,
                focus: _searchFocus,
                hint: s.t('map_search'),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                results: _query.length < 2 ? const [] : _searchResults(list),
                onPick: (m) => _flyTo(info, m),
                kindLabel: (k) => _kindLabel(s, k),
              ),
            ),
            if (markers.isLoading)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(minHeight: 2, color: AppColors.gold, backgroundColor: Colors.transparent),
              ),
            Positioned(
              left: 12,
              bottom: 12,
              child: _FloorButton(
                floor: _floor,
                label: s.t('floor_n', {'n': _floor}),
                onPick: (f) => setState(() => _floor = f),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'map_layers',
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.gold,
                tooltip: s.t('map_layers'),
                onPressed: () => _showLayers(s),
                child: const Icon(Icons.layers_outlined),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 2,
              child: IgnorePointer(
                child: Center(
                  child: Text('© ArenaNet', style: TextStyle(fontSize: 10, color: Colors.white70)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// the tiles covering the viewport at the zoom level closest to the view
  List<Widget> _tiles(ContinentInfo info) {
    final level = _zoom.floor().clamp(info.minZoom, info.maxZoom);
    final s = _scale(info);
    final span = _tile * math.pow(2, info.maxZoom - level).toDouble(); // continent units per tile
    final topLeft = _toWorld(info, Offset.zero);
    final bottomRight = _toWorld(info, Offset(_viewport.width, _viewport.height));
    final maxX = (info.width / span).ceil() - 1;
    final maxY = (info.height / span).ceil() - 1;
    final x0 = (topLeft.dx / span).floor().clamp(0, maxX);
    final x1 = (bottomRight.dx / span).floor().clamp(0, maxX);
    final y0 = (topLeft.dy / span).floor().clamp(0, maxY);
    final y1 = (bottomRight.dy / span).floor().clamp(0, maxY);
    final size = span * s;
    return [
      for (var x = x0; x <= x1; x++)
        for (var y = y0; y <= y1; y++)
          Positioned(
            key: ValueKey('t$_floor-$level-$x-$y'),
            left: _toScreen(info, x * span, y * span).dx,
            top: _toScreen(info, x * span, y * span).dy,
            // a pixel of overlap hides the seams between tiles
            width: size + 1,
            height: size + 1,
            child: CachedIcon(url: '$_tileHost/$worldContinent/$_floor/$level/$x/$y.jpg', fit: BoxFit.fill),
          ),
    ];
  }

  bool _onScreen(Offset p, [double margin = 40]) =>
      p.dx > -margin && p.dy > -margin && p.dx < _viewport.width + margin && p.dy < _viewport.height + margin;

  /// region names far out, map names in the middle, sector names up close
  List<Widget> _labels(ContinentInfo info, List<MapMarker> list) {
    final String kind;
    final double size;
    if (_zoom < 3.6) {
      kind = 'region';
      size = 16;
    } else if (_zoom < 5.6) {
      kind = 'map';
      size = 13;
    } else if (_zoom >= 6.4) {
      kind = 'sector';
      size = 11;
    } else {
      return const [];
    }
    final out = <Widget>[];
    for (final m in list) {
      if (m.kind != kind || m.name.isEmpty) continue;
      final p = _toScreen(info, m.x, m.y);
      if (!_onScreen(p, 100)) continue;
      out.add(Positioned(
        left: p.dx - 90,
        top: p.dy - 12,
        width: 180,
        child: IgnorePointer(
          child: Text(
            m.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: size,
              fontWeight: kind == 'sector' ? FontWeight.w500 : FontWeight.w800,
              fontStyle: kind == 'sector' ? FontStyle.italic : FontStyle.normal,
              color: kind == 'region' ? AppColors.gold : Colors.white,
              shadows: const [Shadow(blurRadius: 4, color: Colors.black), Shadow(blurRadius: 2, color: Colors.black)],
            ),
          ),
        ),
      ));
    }
    return out;
  }

  List<Widget> _markers(ContinentInfo info, List<MapMarker> list, Map<String, String> icons, S s) {
    final out = <Widget>[];
    for (final m in list) {
      final min = markerMinZoom[m.kind];
      if (min == null || _zoom < min || !_layers.contains(m.kind)) continue;
      final p = _toScreen(info, m.x, m.y);
      if (!_onScreen(p)) continue;
      out.add(Positioned(
        left: p.dx - 13,
        top: p.dy - 13,
        width: 26,
        height: 26,
        child: GestureDetector(
          onTap: () => _showMarker(s, m),
          child: _MarkerIcon(kind: m.kind, icon: icons[m.kind]),
        ),
      ));
      if (out.length >= _markerBudget) break;
    }
    return out;
  }

  List<MapMarker> _searchResults(List<MapMarker> list) {
    const searchable = {'waypoint', 'landmark', 'vista', 'unlock', 'map', 'region', 'heart'};
    final hits = <MapMarker>[];
    for (final m in list) {
      if (!searchable.contains(m.kind) || !m.name.toLowerCase().contains(_query)) continue;
      hits.add(m);
      if (hits.length >= 30) break;
    }
    // maps and regions first, they are the likelier target
    hits.sort((a, b) => (a.kind == 'map' || a.kind == 'region' ? 0 : 1).compareTo(b.kind == 'map' || b.kind == 'region' ? 0 : 1));
    return hits;
  }

  String _kindLabel(S s, String kind) => s.t('marker_$kind');

  void _showLayers(S s) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(s.t('map_layers'), style: display(18)),
              ),
              for (final k in markerKinds)
                CheckboxListTile(
                  value: _layers.contains(k),
                  activeColor: AppColors.gold,
                  title: Text(_kindLabel(s, k)),
                  secondary: SizedBox(
                    width: 26,
                    height: 26,
                    child: _MarkerIcon(kind: k, icon: ref.read(markerIconsProvider).valueOrNull?[k]),
                  ),
                  onChanged: (on) {
                    setState(() => on == true ? _layers.add(k) : _layers.remove(k));
                    setSheet(() {});
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarker(S s, MapMarker m) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: _MarkerIcon(kind: m.kind, icon: ref.read(markerIconsProvider).valueOrNull?[m.kind]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(m.name.isEmpty ? _kindLabel(s, m.kind) : m.name, style: display(18)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${_kindLabel(s, m.kind)} · ${m.mapName}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              if (m.chatLink.isNotEmpty) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: m.chatLink));
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('copied'))));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text('${s.t('copy')}  ${m.chatLink}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// the game's icon when /v2/files has one, a drawn fallback otherwise
class _MarkerIcon extends StatelessWidget {
  const _MarkerIcon({required this.kind, this.icon});

  final String kind;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final url = icon;
    if (url != null) return CachedIcon(url: url, fit: BoxFit.contain);
    final (IconData glyph, Color color) = switch (kind) {
      'waypoint' => (Icons.diamond, const Color(0xFF5BC8E8)),
      'landmark' => (Icons.diamond_outlined, Colors.white),
      'vista' => (Icons.change_history, const Color(0xFFE0605A)),
      'heart' => (Icons.favorite, const Color(0xFFF2C744)),
      'hero' => (Icons.stars, const Color(0xFF6CC070)),
      'mastery' => (Icons.military_tech, const Color(0xFFB07CE8)),
      _ => (Icons.location_on, AppColors.gold),
    };
    return Icon(glyph, color: color, size: 22, shadows: const [Shadow(blurRadius: 3, color: Colors.black)]);
  }
}

class _FloorButton extends StatelessWidget {
  const _FloorButton({required this.floor, required this.label, required this.onPick});

  final int floor;
  final String label;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: floor,
      color: AppColors.surface,
      onSelected: onPick,
      itemBuilder: (context) => [
        for (final f in worldFloors) PopupMenuItem(value: f, child: Text('$f')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stairs_outlined, size: 18, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.focus,
    required this.hint,
    required this.onChanged,
    required this.results,
    required this.onPick,
    required this.kindLabel,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final ValueChanged<String> onChanged;
  final List<MapMarker> results;
  final ValueChanged<MapMarker> onPick;
  final String Function(String kind) kindLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          child: TextField(
            controller: controller,
            focusNode: focus,
            onChanged: onChanged,
            decoration: fieldDecoration(hint, prefixIcon: const Icon(Icons.search, color: AppColors.muted)),
          ),
        ),
        if (results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: results.length,
              itemBuilder: (context, i) {
                final m = results[i];
                return ListTile(
                  dense: true,
                  title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    m.kind == 'map' || m.kind == 'region' ? kindLabel(m.kind) : '${kindLabel(m.kind)} · ${m.mapName}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  onTap: () => onPick(m),
                );
              },
            ),
          ),
      ],
    );
  }
}
