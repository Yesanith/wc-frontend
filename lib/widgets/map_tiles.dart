import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/maps.dart';
import '../theme.dart';

/// the official tile service. tiles are 256px jpgs addressed as
/// /{continent}/{floor}/{zoom}/{x}/{y}.jpg
const _host = 'https://tiles.guildwars2.com';
const _tile = 256.0;

/// maximum zoom per continent, from /v2/continents. a continent is
/// continent_dims pixels across at that zoom, and halves with each step down
const _maxZoom = {1: 8, 2: 6};

/// how many tiles one map may load at once. a whole map at full zoom would be
/// hundreds of images, and this keeps the biggest ones near 40
const _tileBudget = 40;

/// the block of tiles that covers a map, and where continent coordinates
/// land inside it
class TileLayout {
  const TileLayout({
    required this.zoom,
    required this.column,
    required this.row,
    required this.columns,
    required this.rows,
    required this.scale,
  });

  final int zoom;

  /// tile indices of the top left tile of the block
  final int column;
  final int row;
  final int columns;
  final int rows;

  /// continent pixels per pixel at this zoom
  final double scale;

  double get width => columns * _tile;
  double get height => rows * _tile;
  int get count => columns * rows;

  /// continent coordinates to a position inside the block
  Offset offsetOf(double x, double y) =>
      Offset(x / scale - column * _tile, y / scale - row * _tile);
}

/// the highest zoom whose tile block still fits in [budget], falling back to
/// zoom 1 for a map so large that nothing fits
TileLayout layoutFor(List<double> rect, int maxZoom, {int budget = _tileBudget}) {
  var zoom = maxZoom;
  var layout = _blockAt(rect, maxZoom, zoom);
  while (zoom > 1 && layout.count > budget) {
    zoom--;
    layout = _blockAt(rect, maxZoom, zoom);
  }
  return layout;
}

TileLayout _blockAt(List<double> rect, int maxZoom, int zoom) {
  final scale = math.pow(2, maxZoom - zoom).toDouble();
  final column = rect[0] / scale ~/ _tile;
  final row = rect[1] / scale ~/ _tile;
  return TileLayout(
    zoom: zoom,
    column: column,
    row: row,
    columns: (rect[2] / scale ~/ _tile) - column + 1,
    rows: (rect[3] / scale ~/ _tile) - row + 1,
    scale: scale,
  );
}

/// the game map itself, pannable and zoomable, with a pin on every point of
/// interest. tiles come straight from the tile service, which needs no key
class MapTiles extends StatefulWidget {
  const MapTiles({super.key, required this.detail, this.onTapPoi});

  final MapDetail detail;
  final void Function(PointOfInterest poi)? onTapPoi;

  @override
  State<MapTiles> createState() => _MapTilesState();
}

class _MapTilesState extends State<MapTiles> {
  final _controller = TransformationController();
  Size? _fitted;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// tiles snap outwards to whole tiles, so the block is bigger than the map.
  /// open on the map itself rather than the corner of the block
  void _fit(Size viewport, TileLayout layout) {
    if (_fitted == viewport) return;
    _fitted = viewport;
    final detail = widget.detail;
    final left = detail.rect[0] / layout.scale - layout.column * _tile;
    final top = detail.rect[1] / layout.scale - layout.row * _tile;
    final width = detail.width / layout.scale;
    final height = detail.height / layout.scale;
    if (width <= 0 || height <= 0) return;

    final scale = math.min(viewport.width / width, viewport.height / height);
    // the matrix maps child pixels to viewport pixels as scale * (p + offset)
    final fitted = Matrix4.identity()
      ..scale(scale)
      ..translate(
        (viewport.width / scale - width) / 2 - left,
        (viewport.height / scale - height) / 2 - top,
      );

    // the viewer listens to the controller, so writing to it inside build
    // would ask it to rebuild mid build. settle it on the next frame instead
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.value = fitted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final layout = layoutFor(detail.rect, _maxZoom[detail.continent] ?? 8);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: AppColors.bg,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _fit(constraints.biggest, layout);
            return InteractiveViewer(
              transformationController: _controller,
              // the tile block is far bigger than the viewport, so it must be
              // laid out at its own size instead of being squashed to fit
              constrained: false,
              minScale: 0.2,
              maxScale: 8,
              boundaryMargin: const EdgeInsets.all(400),
              child: SizedBox(
                width: layout.width,
                height: layout.height,
                child: Stack(
                  children: [
                    for (var cx = 0; cx < layout.columns; cx++)
                      for (var cy = 0; cy < layout.rows; cy++)
                        Positioned(
                          left: cx * _tile,
                          top: cy * _tile,
                          width: _tile,
                          height: _tile,
                          child: Image.network(
                            '$_host/${detail.continent}/${detail.floor}'
                            '/${layout.zoom}/${layout.column + cx}/${layout.row + cy}.jpg',
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.bg),
                          ),
                        ),
                    for (final poi in detail.pois)
                      if (poi.x > 0 && poi.y > 0)
                        _Pin(
                          poi: poi,
                          at: layout.offsetOf(poi.x, poi.y),
                          onTap: widget.onTapPoi,
                        ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.poi, required this.at, this.onTap});

  static const _size = 22.0;

  final PointOfInterest poi;
  final Offset at;
  final void Function(PointOfInterest poi)? onTap;

  @override
  Widget build(BuildContext context) {
    final waypoint = poi.isWaypoint;
    return Positioned(
      left: at.dx - _size / 2,
      top: at.dy - _size / 2,
      width: _size,
      height: _size,
      child: GestureDetector(
        onTap: onTap == null ? null : () => onTap!(poi),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xCC0E1014),
            shape: BoxShape.circle,
            border: Border.all(color: waypoint ? AppColors.gold : AppColors.muted, width: 1.5),
          ),
          child: Icon(
            waypoint ? Icons.place : Icons.flag_outlined,
            size: 13,
            color: waypoint ? AppColors.gold : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
