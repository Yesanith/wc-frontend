import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/clock.dart';
import 'package:wondrous_compass/state/market.dart';

void main() {
  group('trading post list', () {
    final entries = parseMarketIndex(
      '1\tWeapon\tLongBow\tExotic\t80\n'
      '2\tWeapon\tSword\tRare\t40\n'
      '3\tCraftingMaterial\t\tBasic\t0\n'
      'bad line\n'
      '4\tArmor\tCoat\tExotic\t80\n',
    );
    const names = {1: 'Hunter Longbow', 2: 'Rusty Sword', 3: 'Mithril Ore', 4: 'Heavy Coat'};
    String? nameOf(int id) => names[id];
    final prices = {
      1: const TpPrice(100, 200, 5, 50),
      2: const TpPrice(10, 12, 900, 3),
      3: const TpPrice(50, 60, 20000, 90000),
    };

    test('the file parses and skips broken lines', () {
      expect(entries.map((e) => e.id), [1, 2, 3, 4]);
      expect(entries.first.subtype, 'LongBow');
      expect(entries[2].subtype, '');
    });

    test('filters combine', () {
      expect(filterMarket(entries, const MarketFilter(type: 'Weapon'), nameOf: nameOf, prices: prices), [2, 1]);
      expect(filterMarket(entries, const MarketFilter(rarities: {'Exotic'}, sort: MarketSort.name), nameOf: nameOf),
          [4, 1]);
      expect(filterMarket(entries, const MarketFilter(minLevel: 41), nameOf: nameOf, prices: prices), [1, 4]);
      expect(filterMarket(entries, const MarketFilter(query: 'sword'), nameOf: nameOf, prices: prices), [2]);
    });

    test('price sorts keep unpriced items last either way', () {
      expect(filterMarket(entries, const MarketFilter(sort: MarketSort.sellHigh), nameOf: nameOf, prices: prices),
          [1, 3, 2, 4]);
      expect(filterMarket(entries, const MarketFilter(sort: MarketSort.sellLow), nameOf: nameOf, prices: prices),
          [2, 3, 1, 4]);
      // listed only drops what nobody sells
      expect(filterMarket(entries, const MarketFilter(minSupply: 1), nameOf: nameOf, prices: prices),
          unorderedEquals([1, 2, 3]));
    });

    test('without prices the list falls back to names', () {
      expect(filterMarket(entries, const MarketFilter(sort: MarketSort.flip), nameOf: nameOf), [4, 1, 3, 2]);
    });

    test('flip profit is after both fees', () {
      // relist at 199: 199 - 10 - 20 = 169, bought at 100
      expect(const TpPrice(100, 200, 1, 1).flip, 69);
      expect(const TpPrice(0, 200, 1, 1).flip, 0);
    });
  });

  test('birthdays come round once a year', () {
    final created = DateTime.utc(2019, 10, 3, 18);
    expect(nextBirthday(created, DateTime.utc(2026, 9, 28)), DateTime.utc(2026, 10, 3, 18));
    expect(nextBirthday(created, DateTime.utc(2026, 10, 4)), DateTime.utc(2027, 10, 3, 18));
    expect(yearsSince(created, DateTime.utc(2026, 10, 3, 18)), 7);
    expect(yearsSince(created, DateTime.utc(2026, 9, 28)), 6);
  });
}
