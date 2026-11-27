part of '../world_map_screen.dart';

/// the game's icon when /v2/files has one, a drawn fallback otherwise
class _MarkerIcon extends StatelessWidget {
  const _MarkerIcon({required this.kind, this.icon, this.region = ''});

  final String kind;
  final String? icon;

  /// the mastery region of a mastery point, which colours it as the game does
  final String region;

  @override
  Widget build(BuildContext context) {
    // the game's files have no map icon for a mastery point: it is drawn, in its region's colour
    if (kind == 'mastery') return CustomPaint(painter: _MasteryMark(_masteryColor(region)));
    final url = icon;
    if (url != null) return CachedIcon(url: url, fit: BoxFit.contain);
    final (IconData glyph, Color color) = switch (kind) {
      'waypoint' => (Icons.diamond, const Color(0xFF5BC8E8)),
      'landmark' => (Icons.diamond_outlined, Colors.white),
      'vista' => (Icons.change_history, const Color(0xFFE0605A)),
      'heart' => (Icons.favorite, const Color(0xFFF2C744)),
      'hero' => (Icons.stars, const Color(0xFF6CC070)),
      _ => (Icons.location_on, AppColors.gold),
    };
    return Icon(glyph, color: color, size: 22, shadows: const [Shadow(blurRadius: 3, color: Colors.black)]);
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
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: TextField(
            controller: controller,
            focusNode: focus,
            onChanged: onChanged,
            decoration: fieldDecoration(hint, prefixIcon: Icon(Icons.search, color: AppColors.muted)),
          ),
        ),
        if (results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
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
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
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

/// one map tile: from the app's assets for the overview levels of the default floor,
/// otherwise downloaded once and kept on disk
class _Tile extends StatelessWidget {
  const _Tile({required this.floor, required this.level, required this.x, required this.y});

  final int floor;
  final int level;
  final int x;
  final int y;

  @override
  Widget build(BuildContext context) {
    final remote = CachedIcon(url: '$_tileHost/$worldContinent/$floor/$level/$x/$y.jpg', fit: BoxFit.fill);
    if (floor != bundledTileFloor || level > bundledTileMaxLevel) return remote;
    return Image.asset(
      'assets/tiles/$floor/$level/${x}_$y.jpg',
      fit: BoxFit.fill,
      gaplessPlayback: true,
      // not bundled yet, or ocean the job skipped: fall back to the network
      errorBuilder: (context, error, stack) => remote,
    );
  }
}

/// the colour of a mastery region, close to the one the game gives its points
Color _masteryColor(String region) => switch (region) {
      'Maguuma' => const Color(0xFF3F9A3A),
      'Desert' => const Color(0xFFB0459C),
      'Tundra' => const Color(0xFF4F9AD6),
      'Jade' => const Color(0xFF1F9C8C),
      'Sky' => const Color(0xFFE0A020),
      'Wild' => const Color(0xFF7A9A2A),
      'Magic' => const Color(0xFF7A5BD0),
      _ => const Color(0xFFC0392B),
    };

/// a mastery point: a shield in the region's colour with a white rim and a rising chevron
class _MasteryMark extends CustomPainter {
  const _MasteryMark(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shield = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.88, h * 0.2)
      ..lineTo(w * 0.84, h * 0.58)
      ..quadraticBezierTo(w * 0.78, h * 0.82, w * 0.5, h * 0.96)
      ..quadraticBezierTo(w * 0.22, h * 0.82, w * 0.16, h * 0.58)
      ..lineTo(w * 0.12, h * 0.2)
      ..close();
    canvas.drawShadow(shield, Colors.black, 2, false);
    canvas.drawPath(shield, Paint()..color = color);
    canvas.drawPath(
      shield,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, w * 0.08)
        ..strokeJoin = StrokeJoin.round,
    );
    final chevron = Path()
      ..moveTo(w * 0.32, h * 0.6)
      ..lineTo(w * 0.5, h * 0.4)
      ..lineTo(w * 0.68, h * 0.6);
    canvas.drawPath(
      chevron,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, w * 0.1)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MasteryMark old) => old.color != color;
}
