part of '../world_map_screen.dart';

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
  const _FloorButton({required this.floor, required this.label, required this.levelLabel, required this.onPick});

  final int floor;
  final String label;
  final String Function(int floor) levelLabel;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: floor,
      color: AppColors.surface,
      onSelected: onPick,
      itemBuilder: (context) => [
        for (final f in worldFloors) PopupMenuItem(value: f, child: Text(levelLabel(f))),
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
            Icon(Icons.stairs_outlined, size: 18, color: AppColors.gold),
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
