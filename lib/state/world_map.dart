import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache.dart';
import '../util.dart';
import 'api.dart';
import 'settings.dart';

/// tyria. the mists continent has its own coordinates and is left out
const worldContinent = 1;

/// floors offered in the picker. the map opens on floor 0, which is the one
/// that carries the whole surface of tyria, the same default gw2 toolkit uses
const worldFloors = [2, 1, 0, -1, -2];
const defaultFloor = 0;

/// marker kinds, in the order the layer sheet lists them
const markerKinds = ['waypoint', 'landmark', 'vista', 'heart', 'hero', 'mastery', 'unlock'];

/// the zoom from which a kind shows up, closer means more detail
const markerMinZoom = {
  'waypoint': 4.5,
  'landmark': 5.5,
  'vista': 5.5,
  'heart': 5.5,
  'hero': 5.5,
  'mastery': 5.5,
  'unlock': 5.0,
};

class ContinentInfo {
  const ContinentInfo(this.width, this.height, this.minZoom, this.maxZoom);
  final double width;
  final double height;
  final int minZoom;
  final int maxZoom;
}

/// dimensions and zoom range of tyria, falls back to the known values
final continentProvider = FutureProvider<ContinentInfo>((ref) async {
  const fallback = ContinentInfo(81920, 114688, 0, 7);
  try {
    final raw = await ref.watch(gw2ApiProvider).get('/continents/$worldContinent');
    if (raw is! Map) return fallback;
    final dims = raw['continent_dims'];
    if (dims is! List || dims.length < 2) return fallback;
    return ContinentInfo(
      (dims[0] as num).toDouble(),
      (dims[1] as num).toDouble(),
      asInt(raw['min_zoom']),
      asInt(raw['max_zoom']) <= 0 ? 7 : asInt(raw['max_zoom']),
    );
  } catch (_) {
    return fallback;
  }
});

/// one thing drawn on the map, in continent coordinates
class MapMarker {
  const MapMarker(this.kind, this.x, this.y, this.name, this.chatLink, this.mapName);

  /// a marker kind, or 'map', 'region' and 'sector' for labels
  final String kind;
  final double x;
  final double y;
  final String name;
  final String chatLink;
  final String mapName;

  List<Object?> toRow() => [kind, x, y, name, chatLink, mapName];

  static MapMarker? fromRow(dynamic row) {
    if (row is! List || row.length < 6) return null;
    return MapMarker(
      '${row[0]}',
      (row[1] as num).toDouble(),
      (row[2] as num).toDouble(),
      '${row[3] ?? ''}',
      '${row[4] ?? ''}',
      '${row[5] ?? ''}',
    );
  }
}

/// pulls every marker and label out of a floor response. runs in a
/// background isolate: the response is several megabytes of json
List<List<Object?>> extractMarkers(String body) {
  final out = <List<Object?>>[];
  final floor = jsonDecode(body);
  if (floor is! Map) return out;

  List<double>? coord(dynamic c) {
    if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
      return [(c[0] as num).toDouble(), (c[1] as num).toDouble()];
    }
    return null;
  }

  void add(String kind, dynamic c, dynamic name, dynamic chat, String mapName) {
    final at = coord(c);
    if (at == null) return;
    out.add([kind, at[0], at[1], '${name ?? ''}', '${chat ?? ''}', mapName]);
  }

  final regions = floor['regions'];
  if (regions is! Map) return out;
  for (final region in regions.values) {
    if (region is! Map) continue;
    add('region', region['label_coord'], region['name'], '', '');
    final maps = region['maps'];
    if (maps is! Map) continue;
    for (final map in maps.values) {
      if (map is! Map) continue;
      final mapName = '${map['name'] ?? ''}';
      if (mapName.isEmpty) continue;
      add('map', map['label_coord'], mapName, '', mapName);

      final pois = map['points_of_interest'];
      if (pois is Map) {
        for (final p in pois.values) {
          if (p is! Map) continue;
          final type = '${p['type'] ?? ''}';
          // landmark is what the game calls a point of interest
          if (const {'waypoint', 'landmark', 'vista', 'unlock'}.contains(type)) {
            add(type, p['coord'], p['name'], p['chat_link'], mapName);
          }
        }
      }
      final tasks = map['tasks'];
      if (tasks is Map) {
        for (final t in tasks.values) {
          if (t is Map) add('heart', t['coord'], t['objective'], t['chat_link'], mapName);
        }
      }
      for (final h in (map['skill_challenges'] as List?) ?? const []) {
        if (h is Map) add('hero', h['coord'], '', '', mapName);
      }
      for (final m in (map['mastery_points'] as List?) ?? const []) {
        if (m is Map) add('mastery', m['coord'], m['region'], '', mapName);
      }
      final sectors = map['sectors'];
      if (sectors is Map) {
        for (final sct in sectors.values) {
          if (sct is Map) add('sector', sct['coord'], sct['name'], sct['chat_link'], mapName);
        }
      }
    }
  }
  return out;
}

/// every marker and label of one floor, kept on disk for a month in the
/// compact form above instead of the raw response
final worldMarkersProvider = FutureProvider.family<List<MapMarker>, int>((ref, floor) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);
  final rows = await cachedList(
    cache,
    'worldmap_${worldContinent}_${floor}_${lang.apiLang}',
    'rows',
    () async => compute(extractMarkers, await api.getText('/continents/$worldContinent/floors/$floor')),
  );
  return [
    for (final r in rows)
      if (MapMarker.fromRow(r) case final m?) m,
  ];
});

/// the game's own map icons from /v2/files, by marker kind
final markerIconsProvider = FutureProvider<Map<String, String>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final rows = await cachedList(cache, 'map_files', 'rows', () => api.allOf('/files'));
  final byId = <String, String>{
    for (final r in rows)
      if (r is Map && r['icon'] != null) '${r['id']}': '${r['icon']}',
  };
  const fileFor = {
    'waypoint': 'map_waypoint',
    'landmark': 'map_poi',
    'vista': 'map_vista',
    'heart': 'map_heart_empty',
    'hero': 'map_heropoint',
    'unlock': 'map_dungeon',
  };
  return {
    for (final e in fileFor.entries)
      if (byId[e.value] != null) e.key: byId[e.value]!,
  };
});
