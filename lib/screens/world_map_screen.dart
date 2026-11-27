import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/metas.dart';
import '../data/waypoints.dart';
import '../l10n/strings.dart';
import '../services/icon_cache.dart';
import '../state/clock.dart';
import '../state/hidden_timers.dart';
import '../state/navigation.dart';
import '../state/settings.dart';
import '../state/world_map.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/clock.dart';
import '../widgets/common.dart';
import '../widgets/waypoint_link.dart' show copyWaypoint;
import 'events_screen.dart' show togglePin;
import '../widgets/responsive.dart' show SiteScope;

part 'world_map/widgets.dart';
part 'world_map/panels.dart';

const _tileHost = 'https://tiles.guildwars2.com';
const _tile = 256.0;

/// where the map opens, roughly lion's arch
const _startCenter = Offset(49000, 31500);
const _startZoom = 2.6;

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

  /// the map whose card is open, by name, and the marker last tapped
  String? _selected;
  MapMarker? _picked;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  // markers grouped by kind, rebuilt only when a new list arrives, so a
  // frame of panning does not walk every marker once per kind
  List<MapMarker>? _groupedFrom;
  Map<String, List<MapMarker>> _grouped = const {};

  Map<String, List<MapMarker>> _byKind(List<MapMarker> list) {
    if (!identical(list, _groupedFrom)) {
      final out = <String, List<MapMarker>>{};
      for (final m in list) {
        out.putIfAbsent(m.kind, () => []).add(m);
      }
      _groupedFrom = list;
      _grouped = out;
    }
    return _grouped;
  }

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
        Offset(world.dx - (screenPoint.dx - _viewport.width / 2) / s,
            world.dy - (screenPoint.dy - _viewport.height / 2) / s),
      );
    });
  }

  /// to a marker, a map or a region from the search: a map found is the chosen one, a marker is shown with its map
  void _flyTo(ContinentInfo info, MapMarker m, {bool keepSelection = false}) {
    _searchFocus.unfocus();
    setState(() {
      _center = _clampCenter(info, Offset(m.x, m.y));
      _zoom = math.max(_zoom, m.kind == 'map' || m.kind == 'region' ? 4.8 : 6.3);
      _query = '';
      _search.clear();
      if (m.kind == 'map') {
        _selected = m.name;
        _picked = null;
      } else if (m.kind != 'region') {
        if (!keepSelection && m.mapName.isNotEmpty) _selected = m.mapName;
        _picked = m;
      }
    });
  }

  /// the map under a tap: the map frame it falls in, among the maps that have markers
  void _tapAt(ContinentInfo info, Offset local, Map<String, MapDetail> details, Set<String> names) {
    final world = _toWorld(info, local);
    final hit = mapAt(details.values.where((d) => names.contains(d.name)), world);
    setState(() {
      _picked = null;
      _selected = hit?.name == _selected ? null : hit?.name;
    });
  }

  void _select(String? name) => setState(() {
        _selected = name;
        _picked = null;
      });

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final info = ref.watch(continentProvider).valueOrNull;
    final markers = ref.watch(worldMarkersProvider(_floor));
    final icons = ref.watch(markerIconsProvider).valueOrNull ?? const <String, String>{};
    final details = ref.watch(mapDetailsProvider).valueOrNull ?? const <String, MapDetail>{};
    final site = SiteScope.of(context);

    if (info == null) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        final list = markers.valueOrNull ?? const <MapMarker>[];
        final names = {for (final m in _byKind(list)['map'] ?? const <MapMarker>[]) m.name};
        final selected = _selected;
        final detail = selected == null ? null : details[selected];
        final onMap = selected == null
            ? const <MapMarker>[]
            : [
                for (final m in list)
                  if (m.mapName == selected) m
              ];
        final search = _SearchBox(
          controller: _search,
          focus: _searchFocus,
          hint: s.t('map_search'),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          results: _query.length < 2 ? const [] : _searchResults(list),
          onPick: (m) => _flyTo(info, m),
          kindLabel: (k) => _kindLabel(s, k),
        );
        final card = selected == null
            ? null
            : _MapCard(
                name: selected,
                detail: detail,
                markers: onMap,
                compact: !site,
                onClose: () => _select(null),
                onWaypoint: (m) => _flyTo(info, m, keepSelection: true),
              );
        final picked = _picked;
        final pickedAt = picked == null ? null : _toScreen(info, picked.x, picked.y);
        return Stack(
          children: [
            Positioned.fill(
              // the wheel of a mouse zooms around the pointer, a notch a third of a level
              child: Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _zoomAround(info, event.localPosition, _zoom - event.scrollDelta.dy / 300);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _tapAt(info, d.localPosition, details, names),
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
                        // the chosen map in a light frame, the rest of the world a little darker
                        if (detail != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _ChosenMapPainter(Rect.fromPoints(
                                  _toScreen(info, detail.rect.left, detail.rect.top),
                                  _toScreen(info, detail.rect.right, detail.rect.bottom),
                                )),
                              ),
                            ),
                          ),
                        ..._labels(info, list),
                        ..._markers(info, list, icons, s),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // the marker chosen on a site: its name and its chat link, beside it
            if (site && picked != null && pickedAt != null && _onScreen(pickedAt, 0))
              Positioned(
                left: (pickedAt.dx + 16).clamp(0.0, math.max(0.0, _viewport.width - 300)),
                top: (pickedAt.dy - 22).clamp(0.0, math.max(0.0, _viewport.height - 60)),
                child: _MarkerPopover(
                  marker: picked,
                  icon: icons[picked.kind],
                  kindLabel: _kindLabel(s, picked.kind),
                  onClose: () => setState(() => _picked = null),
                ),
              ),
            if (markers.isLoading)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child:
                    LinearProgressIndicator(minHeight: 2, color: AppColors.gold, backgroundColor: Colors.transparent),
              ),
            if (site) ...[
              // a site: search and the layers at the left, the chosen map at the right
              Positioned(
                left: 20,
                top: 20,
                width: 316,
                child: _LayersPanel(
                  search: search,
                  layers: _layers,
                  icons: icons,
                  counts: _counts(onMap),
                  kindLabel: (k) => _kindLabel(s, k),
                  onToggle: _toggleLayer,
                ),
              ),
              if (card != null)
                Positioned(
                  right: 20,
                  top: 20,
                  width: 360,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: math.max(200.0, _viewport.height - 100)),
                    child: card,
                  ),
                ),
              Positioned(
                left: 20,
                bottom: 20,
                child: _FloorPicker(floor: _floor, label: (f) => s.t('floor_n', {'n': f}), onPick: _setFloor),
              ),
              Positioned(
                right: 20,
                bottom: 20,
                child: _ZoomButtons(
                  onIn: () => _zoomAround(info, _viewport.center(Offset.zero), _zoom + 1),
                  onOut: () => _zoomAround(info, _viewport.center(Offset.zero), _zoom - 1),
                  onWhole: () => setState(() {
                    _zoom = _startZoom;
                    _center = _startCenter;
                  }),
                ),
              ),
            ] else ...[
              // a phone: search and the layers as chips on top, the chosen map in a card at the bottom
              Positioned(
                left: 12,
                right: 12,
                top: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 8),
                        _FloorPicker(
                            floor: _floor, label: (f) => s.t('floor_n', {'n': f}), onPick: _setFloor, compact: true),
                      ],
                    ),
                    if (_query.length < 2) ...[
                      const SizedBox(height: 8),
                      _LayerChips(layers: _layers, kindLabel: (k) => _kindLabel(s, k), onToggle: _toggleLayer),
                    ],
                  ],
                ),
              ),
              if (card != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: _viewport.height * 0.55),
                    child: card,
                  ),
                ),
            ],
            // without markers the map would just look empty, say why
            if (markers.hasError && list.isEmpty)
              Positioned(
                left: 12,
                right: 12,
                bottom: 80,
                child: ErrorBox(
                  error: markers.error,
                  onRetry: () => ref.invalidate(worldMarkersProvider(_floor)),
                ),
              ),
            if (card == null || site)
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

  void _toggleLayer(String kind) => setState(() => _layers.contains(kind) ? _layers.remove(kind) : _layers.add(kind));

  void _setFloor(int floor) => setState(() {
        _floor = floor;
        _picked = null;
      });

  /// how many of each kind the chosen map has
  Map<String, int> _counts(List<MapMarker> onMap) {
    final out = <String, int>{};
    for (final m in onMap) {
      out[m.kind] = (out[m.kind] ?? 0) + 1;
    }
    return out;
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
            child: _Tile(floor: _floor, level: level, x: x, y: y),
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
    for (final m in _byKind(list)[kind] ?? const <MapMarker>[]) {
      if (m.name.isEmpty) continue;
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
    final grouped = _byKind(list);
    final visible = <(MapMarker, Offset)>[];
    for (final kind in markerKinds) {
      final min = markerMinZoom[kind];
      if (min == null || _zoom < min || !_layers.contains(kind)) continue;
      for (final m in grouped[kind] ?? const <MapMarker>[]) {
        final p = _toScreen(info, m.x, m.y);
        if (_onScreen(p)) visible.add((m, p));
      }
    }
    // over budget, keep the markers closest to the middle of the screen
    // rather than whichever the data happens to list first
    if (visible.length > _markerBudget) {
      final middle = _viewport.center(Offset.zero);
      visible.sort((a, b) => (a.$2 - middle).distanceSquared.compareTo((b.$2 - middle).distanceSquared));
      visible.removeRange(_markerBudget, visible.length);
    }
    return [
      for (final (m, p) in visible)
        Positioned(
          left: p.dx - 13,
          top: p.dy - 13,
          width: 26,
          height: 26,
          child: GestureDetector(
            onTap: () {
              if (SiteScope.of(context)) {
                setState(() {
                  _picked = m;
                  if (m.mapName.isNotEmpty) _selected = m.mapName;
                });
              } else {
                if (m.mapName.isNotEmpty) setState(() => _selected = m.mapName);
                _showMarker(s, m);
              }
            },
            child: _MarkerIcon(kind: m.kind, icon: icons[m.kind]),
          ),
        ),
    ];
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
    hits.sort((a, b) =>
        (a.kind == 'map' || a.kind == 'region' ? 0 : 1).compareTo(b.kind == 'map' || b.kind == 'region' ? 0 : 1));
    return hits;
  }

  String _kindLabel(S s, String kind) => s.t('marker_$kind');

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
              Text('${_kindLabel(s, m.kind)} · ${m.mapName}', style: TextStyle(fontSize: 13, color: AppColors.muted)),
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
