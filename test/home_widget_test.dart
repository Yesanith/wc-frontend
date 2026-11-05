import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/data/metas.dart';
import 'package:wondrous_compass/services/home_widget_sync.dart';

const _maps = [
  MetaMap('a', 'Map A', Expansion.core, [
    MetaEvent('Boss One', [60, 180], kind: MetaKind.boss, bossId: 'boss_one'),
    MetaEvent('Meta Two', [90]),
  ]),
  MetaMap('b', 'Map B', Expansion.hot, [
    MetaEvent('Hard Three', [30], kind: MetaKind.hardBoss, bossId: 'hard_three'),
  ]),
];

List<List<String>> lines(String schedule) => [for (final l in schedule.split('\n')) l.split('\t')];

void main() {
  group('widgetSchedule', () {
    test('lists the world bosses when nothing is pinned, by time of day', () {
      final got = lines(widgetSchedule(const {}, maps: _maps));
      expect(got, [
        ['30', 'Hard Three', 'Map B'],
        ['60', 'Boss One', 'Map A'],
        ['180', 'Boss One', 'Map A'],
      ]);
    });

    test('lists what is pinned instead, a meta included', () {
      final got = lines(widgetSchedule({'a/Meta Two'}, maps: _maps));
      expect(got, [
        ['90', 'Meta Two', 'Map A'],
      ]);
    });

    test('a pin is found by the boss id where there is one', () {
      final got = lines(widgetSchedule({'hard_three'}, maps: _maps));
      expect(got.single, ['30', 'Hard Three', 'Map B']);
    });

    test('every line has three fields, and no tab or line break inside one', () {
      final schedule = widgetSchedule(const {});
      expect(schedule, isNotEmpty);
      for (final parts in lines(schedule)) {
        expect(parts, hasLength(3));
        expect(int.tryParse(parts[0]), isNotNull);
        expect(int.parse(parts[0]), inInclusiveRange(0, 1439));
      }
    });
  });

  test('the widget exists only on android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(homeWidgetReady, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(homeWidgetReady, isTrue);
  });
}
