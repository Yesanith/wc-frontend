import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/world_map.dart';

void main() {
  final floor = jsonEncode({
    'regions': {
      '4': {
        'name': 'Kryta',
        'label_coord': [100, 200],
        'maps': {
          '15': {
            'name': 'Queensdale',
            'label_coord': [110, 210],
            'points_of_interest': {
              '1': {'type': 'waypoint', 'name': 'Shaemoor Waypoint', 'coord': [1, 2], 'chat_link': '[&BAAA]'},
              '2': {'type': 'landmark', 'name': 'Shaemoor', 'coord': [3, 4], 'chat_link': '[&BBBB]'},
              '3': {'type': 'vista', 'coord': [5, 6]},
              '4': {'type': 'something_new', 'coord': [7, 8]},
            },
            'tasks': {
              '9': {'objective': 'Help Farmer Diah', 'coord': [9, 10], 'chat_link': '[&BCCC]'},
            },
            'skill_challenges': [
              {'id': '0-4', 'coord': [11, 12]},
            ],
            'mastery_points': [
              {'id': 1, 'region': 'Tyria', 'coord': [13, 14]},
            ],
            'sectors': {
              '20': {'name': 'Shaemoor Fields', 'coord': [15, 16]},
            },
          },
          '99': {'name': '', 'label_coord': [0, 0]},
        },
      },
    },
  });

  test('pulls every kind out of a floor', () {
    final markers = extractMarkers(floor).map(MapMarker.fromRow).whereType<MapMarker>().toList();
    final kinds = markers.map((m) => m.kind).toList();
    expect(kinds, containsAll(['region', 'map', 'waypoint', 'landmark', 'vista', 'heart', 'hero', 'mastery', 'sector']));
    // unknown point types and nameless maps are skipped
    expect(markers.where((m) => m.name == 'something_new'), isEmpty);
    expect(markers.where((m) => m.kind == 'map').map((m) => m.name), ['Queensdale']);

    final waypoint = markers.firstWhere((m) => m.kind == 'waypoint');
    expect(waypoint.name, 'Shaemoor Waypoint');
    expect(waypoint.chatLink, '[&BAAA]');
    expect(waypoint.mapName, 'Queensdale');
    expect(waypoint.x, 1);
    expect(waypoint.y, 2);
    expect(markers.firstWhere((m) => m.kind == 'heart').name, 'Help Farmer Diah');
  });

  test('rows survive the round trip through the cache', () {
    const m = MapMarker('vista', 1.5, 2.5, 'Top', '[&X]', 'Somewhere');
    final back = MapMarker.fromRow(jsonDecode(jsonEncode(m.toRow())));
    expect(back?.kind, 'vista');
    expect(back?.x, 1.5);
    expect(back?.mapName, 'Somewhere');
    expect(MapMarker.fromRow('junk'), isNull);
  });

  test('tile grid uses zoom 7 as the scale, not the api\'s max_zoom of 8', () {
    // the tile service serves 20 by 28 tiles at zoom 3 for tyria
    const width = 81920.0, height = 114688.0;
    final span = 256.0 * (1 << (tyriaTileZoom - 3));
    expect((width / span).ceil(), 20);
    expect((height / span).ceil(), 28);
  });

  test('every marker kind has a zoom threshold', () {
    for (final k in markerKinds) {
      expect(markerMinZoom[k], isNotNull, reason: k);
    }
  });
}
