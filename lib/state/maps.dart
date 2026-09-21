import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache.dart';
import '../util.dart';
import 'api.dart';
import 'settings.dart';

class GameMap {
  const GameMap(this.id, this.name, this.region, this.continent, this.floor, this.regionId, this.minLevel, this.maxLevel);
  final int id;
  final String name;
  final String region;
  final int continent;
  final int floor;
  final int regionId;
  final int minLevel;
  final int maxLevel;
}

/// all maps, sorted by region then name. cached on disk, they only change
/// when a new map ships
final mapsProvider = FutureProvider<List<GameMap>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);

  final raw = await cachedList(cache, 'maps_${lang.apiLang}', 'rows', () => api.maps());
  final rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  final maps = <GameMap>[];
  for (final row in rows) {
    final regionName = '${row['region_name'] ?? ''}';
    if (regionName.isEmpty) continue;
    maps.add(GameMap(
      asInt(row['id']),
      '${row['name'] ?? ''}',
      regionName,
      asInt(row['continent_id']),
      asInt(row['default_floor']),
      asInt(row['region_id']),
      asInt(row['min_level']),
      asInt(row['max_level']),
    ));
  }
  maps.sort((a, b) => a.region == b.region ? a.name.compareTo(b.name) : a.region.compareTo(b.region));
  return maps;
});

class PointOfInterest {
  const PointOfInterest(this.name, this.type, this.chatLink);
  final String name;
  final String type;
  final String chatLink;

  bool get isWaypoint => type == 'waypoint';
}

/// waypoints, landmarks and vistas of one map
final mapDetailProvider = FutureProvider.family<List<PointOfInterest>, int>((ref, mapId) async {
  final api = ref.watch(gw2ApiProvider);
  final maps = await ref.watch(mapsProvider.future);
  GameMap? map;
  for (final m in maps) {
    if (m.id == mapId) map = m;
  }
  if (map == null) return const [];
  final detail = await api.mapDetail(map.continent, map.floor, map.regionId, map.id);
  final pois = <PointOfInterest>[];
  final raw = detail['points_of_interest'];
  if (raw is Map) {
    for (final entry in raw.values) {
      if (entry is! Map) continue;
      pois.add(PointOfInterest(
        '${entry['name'] ?? ''}',
        '${entry['type'] ?? ''}',
        '${entry['chat_link'] ?? ''}',
      ));
    }
  }
  pois.sort((a, b) {
    if (a.isWaypoint != b.isWaypoint) return a.isWaypoint ? -1 : 1;
    return a.name.compareTo(b.name);
  });
  return pois;
});
