import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/world_map.dart';

void main() {
  final rows = [
    {
      'id': 15,
      'name': 'Queensdale',
      'min_level': 1,
      'max_level': 15,
      'region_name': 'Kryta',
      'continent_id': 1,
      'continent_rect': [
        [42624, 28032],
        [46208, 30464]
      ],
    },
    // an instance of the same name, smaller: the open map is kept
    {
      'id': 999,
      'name': 'Queensdale',
      'continent_id': 1,
      'continent_rect': [
        [43000, 28100],
        [43100, 28200]
      ],
    },
    {
      'id': 18,
      'name': "Divinity's Reach",
      'region_name': 'Kryta',
      'continent_id': 1,
      'continent_rect': [
        [43000, 26000],
        [45000, 28500]
      ],
    },
    // the mists are another continent
    {
      'id': 38,
      'name': 'Eternal Battlegrounds',
      'continent_id': 2,
      'continent_rect': [
        [0, 0],
        [10, 10]
      ],
    },
  ];

  test('the maps of tyria by name, the open map over its instance', () {
    final maps = mapDetailsFrom(rows);
    expect(maps.keys, unorderedEquals(['Queensdale', "Divinity's Reach"]));
    final q = maps['Queensdale']!;
    expect(q.id, 15);
    expect([q.minLevel, q.maxLevel, q.region], [1, 15, 'Kryta']);
  });

  test('a tap is on the smallest map that holds it', () {
    final maps = mapDetailsFrom(rows).values;
    expect(mapAt(maps, const Offset(44000, 29000))?.name, 'Queensdale');
    // the city and queensdale overlap here: the city is the smaller
    expect(mapAt(maps, const Offset(44000, 28200))?.name, "Divinity's Reach");
    expect(mapAt(maps, const Offset(1, 1)), isNull);
  });
}
