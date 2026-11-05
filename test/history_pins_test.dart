import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wondrous_compass/data/metas.dart';
import 'package:wondrous_compass/state/price_history.dart';
import 'package:wondrous_compass/state/progression.dart';
import 'package:wondrous_compass/state/settings.dart';
import 'package:wondrous_compass/widgets/expansion_badge.dart';

Future<ProviderContainer> _container([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
  ]);
  addTearDown(container.dispose);
  return container;
}

Map<String, dynamic> _price(int buy, int sell) => {
      'buys': {'unit_price': buy, 'quantity': 1},
      'sells': {'unit_price': sell, 'quantity': 1},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('price history', () {
    test('one point per item and day, the latest price of the day wins', () async {
      final c = await _container();
      final history = c.read(priceHistoryProvider.notifier);
      final day = DateTime(2026, 9, 27, 10);
      await history.record({19721: _price(100, 120)}, now: day);
      await history.record({19721: _price(105, 125)}, now: day.add(const Duration(hours: 3)));
      await history.record({19721: _price(110, 130)}, now: day.add(const Duration(days: 1)));
      final points = c.read(priceHistoryProvider)[19721]!;
      expect(points.map((p) => p.day), ['2026-09-27', '2026-09-28']);
      expect(points.map((p) => p.sell), [125, 130]);
      expect(points.first.buy, 105);
    });

    test('an item with no buyers and no sellers is not recorded', () async {
      final c = await _container();
      await c.read(priceHistoryProvider.notifier).record({1: _price(0, 0)});
      expect(c.read(priceHistoryProvider), isEmpty);
    });

    test('the history survives a restart', () async {
      final c = await _container();
      await c.read(priceHistoryProvider.notifier).record({7: _price(1, 2)}, now: DateTime(2026, 1, 1));
      final prefs = await SharedPreferences.getInstance();
      final again = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
      addTearDown(again.dispose);
      expect(again.read(priceHistoryProvider)[7]!.single.sell, 2);
    });

    test('items nobody watches are forgotten after a month, watched ones stay', () {
      final now = DateTime(2026, 9, 27);
      final history = {
        1: [const PricePoint('2026-08-01', 1, 1)],
        2: [const PricePoint('2026-08-01', 1, 1)],
        3: [const PricePoint('2026-09-20', 1, 1)],
      };
      expect(prune(history, {2}, now).keys, unorderedEquals([2, 3]));
    });

    test('a range keeps the days inside it', () {
      final points = [
        const PricePoint('2026-09-01', 1, 10),
        const PricePoint('2026-09-22', 1, 20),
        const PricePoint('2026-09-27', 1, 30),
      ];
      final now = DateTime(2026, 9, 27, 12);
      expect(lastDays(points, 7, now: now).map((p) => p.sell), [20, 30]);
      expect(lastDays(points, null, now: now), hasLength(3));
    });

    test('the change is measured from the first to the last point', () {
      final points = [const PricePoint('a', 0, 100), const PricePoint('b', 50, 125)];
      expect(percentChange(points, (p) => p.sell), closeTo(25, 0.001));
      // a side without a price at one end has no change
      expect(percentChange(points, (p) => p.buy), isNull);
      expect(percentChange(points.take(1).toList(), (p) => p.sell), isNull);
    });
  });

  group('pinned achievements', () {
    test('pins toggle, keep their order and survive a restart', () async {
      final c = await _container();
      final pins = c.read(pinnedAchievementsProvider.notifier);
      await pins.toggle(10);
      await pins.toggle(20);
      await pins.toggle(30);
      await pins.toggle(20);
      expect(c.read(pinnedAchievementsProvider), [10, 30]);
      final prefs = await SharedPreferences.getInstance();
      final again = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
      addTearDown(again.dispose);
      expect(again.read(pinnedAchievementsProvider), [10, 30]);
    });

    test('a row uses the account progress, or the top tier when not started', () {
      final detail = {
        'name': 'Explorer',
        'tiers': [
          {'count': 5, 'points': 1},
          {'count': 20, 'points': 5},
        ],
      };
      final started = achievementRowFor(1, detail, {'current': 7, 'max': 20, 'done': false});
      expect((started.current, started.max, started.done), (7, 20, false));
      final fresh = achievementRowFor(1, detail, null);
      expect((fresh.current, fresh.max, fresh.done), (0, 20, false));
      expect(achievementRowFor(1, detail, {'current': 20, 'max': 20, 'done': true}).done, isTrue);
    });
  });

  test('folded material categories are remembered', () async {
    final c = await _container();
    final folded = c.read(collapsedMaterialsProvider.notifier);
    await folded.toggle(5);
    await folded.toggle(9);
    await folded.toggle(5);
    expect(c.read(collapsedMaterialsProvider), {9});
    await folded.setAll({1, 2, 3});
    final prefs = await SharedPreferences.getInstance();
    final again = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(again.dispose);
    expect(again.read(collapsedMaterialsProvider), {1, 2, 3});
  });

  test('every release has its own badge letters', () {
    final codes = [for (final e in Expansion.values) e.code];
    expect(codes.toSet(), hasLength(codes.length));
  });
}
