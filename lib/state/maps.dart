import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gw2_api.dart';
import '../services/cache.dart';
import '../util.dart';
import 'api.dart';
import 'settings.dart';

class GameMap {
  const GameMap(this.id, this.name, this.region, this.continent, this.floors, this.regionId, this.minLevel, this.maxLevel);
  final int id;
  final String name;
  final String region;
  final int continent;

  /// the default floor first, then every other floor the map is drawn on
  final List<int> floors;
  final int regionId;
  final int minLevel;
  final int maxLevel;
}

/// open world maps, sorted by region then name. cached on disk, they only
/// change when a new map ships.
///
/// /v2/maps is mostly story instances: of roughly 1080 entries only about 120
/// are type Public. The rest are not drawn on any continent floor, so they
/// carry no waypoints and their detail lookup 404s
final mapsProvider = FutureProvider<List<GameMap>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);

  final raw = await cachedList(cache, 'maps_${lang.apiLang}', 'rows', () => api.maps());
  final rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  final maps = <GameMap>[];
  for (final row in rows) {
    final regionName = '${row['region_name'] ?? ''}';
    if (regionName.isEmpty || row['type'] != 'Public') continue;
    final defaultFloor = asInt(row['default_floor']);
    maps.add(GameMap(
      asInt(row['id']),
      '${row['name'] ?? ''}',
      regionName,
      asInt(row['continent_id']),
      [defaultFloor, ...intList(row['floors']).where((f) => f != defaultFloor)],
      asInt(row['region_id']),
      asInt(row['min_level']),
      asInt(row['max_level']),
    ));
  }
  maps.sort((a, b) => a.region == b.region ? a.name.compareTo(b.name) : a.region.compareTo(b.region));
  return maps;
});

class PointOfInterest {
  const PointOfInterest(this.name, this.type, this.chatLink, this.x, this.y);
  final String name;
  final String type;
  final String chatLink;

  /// position in continent pixels, the same space as [MapDetail.rect]
  final double x;
  final double y;

  bool get isWaypoint => type == 'waypoint';
}

/// one map as it is drawn on a continent floor
class MapDetail {
  const MapDetail({
    required this.continent,
    required this.floor,
    required this.rect,
    required this.pois,
  });

  final int continent;

  /// the floor that answered, which is also the floor the tiles come from
  final int floor;

  /// [left, top, right, bottom] in continent pixels at the continent's
  /// maximum zoom, which is how the tile server addresses everything
  final List<double> rect;
  final List<PointOfInterest> pois;

  double get width => rect[2] - rect[0];
  double get height => rect[3] - rect[1];
  bool get hasBounds => width > 0 && height > 0;
}

List<double>? _rect(dynamic raw) {
  if (raw is! List || raw.length < 2) return null;
  final a = raw[0], b = raw[1];
  if (a is! List || b is! List || a.length < 2 || b.length < 2) return null;
  return [
    (a[0] as num).toDouble(),
    (a[1] as num).toDouble(),
    (b[0] as num).toDouble(),
    (b[1] as num).toDouble(),
  ];
}

/// waypoints, landmarks and vistas of one map. a map is not always drawn on
/// the floor it calls default, so walk its floors until one answers
final mapDetailProvider = FutureProvider.family<MapDetail?, int>((ref, mapId) async {
  final api = ref.watch(gw2ApiProvider);
  final maps = await ref.watch(mapsProvider.future);
  GameMap? map;
  for (final m in maps) {
    if (m.id == mapId) map = m;
  }
  if (map == null) return null;

  Json? detail;
  var used = map.floors.isEmpty ? 1 : map.floors.first;
  for (final floor in map.floors) {
    try {
      detail = await api.mapDetail(map.continent, floor, map.regionId, map.id);
      used = floor;
      break;
    } on Gw2ApiException catch (e) {
      if (e.status != 404) rethrow;
    }
  }
  if (detail == null) return null;

  final pois = <PointOfInterest>[];
  final raw = detail['points_of_interest'];
  if (raw is Map) {
    for (final entry in raw.values) {
      if (entry is! Map) continue;
      final coord = entry['coord'];
      pois.add(PointOfInterest(
        '${entry['name'] ?? ''}',
        '${entry['type'] ?? ''}',
        '${entry['chat_link'] ?? ''}',
        coord is List && coord.isNotEmpty ? (coord[0] as num).toDouble() : 0,
        coord is List && coord.length > 1 ? (coord[1] as num).toDouble() : 0,
      ));
    }
  }
  pois.sort((a, b) {
    if (a.isWaypoint != b.isWaypoint) return a.isWaypoint ? -1 : 1;
    return a.name.compareTo(b.name);
  });

  return MapDetail(
    continent: map.continent,
    floor: used,
    rect: _rect(detail['continent_rect']) ?? const [0, 0, 0, 0],
    pois: pois,
  );
});
