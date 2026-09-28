import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/screens/inventory_screen.dart';
import 'package:tyria_codex/state/account.dart';
import 'package:tyria_codex/state/clock.dart';
import 'package:tyria_codex/state/inventory.dart';
import 'package:tyria_codex/state/market.dart';

void main() {
  const bank = OwnedPlace(OwnedKind.bank);
  const mats = OwnedPlace(OwnedKind.materials);
  const heroBags = OwnedPlace(OwnedKind.bags, 'Hero');
  const altBags = OwnedPlace(OwnedKind.bags, 'Alt');
  const worn = OwnedPlace(OwnedKind.equipped, 'Hero');

  group('tidy up', () {
    test('storage size is the fullest slot rounded up to 250', () {
      expect(guessStorageCap([12, 250, 90]), 250);
      expect(guessStorageCap([251, 3]), 500);
      expect(guessStorageCap([2750]), 2750);
      expect(guessStorageCap([]), 0);
    });

    final report = buildCleanup(
      owned: {
        // a material in the bank and a bag, and in storage
        1: {mats: 250, bank: 20, heroBags: 5},
        // a stackable split over two characters
        2: {heroBags: 10, altBags: 4},
        // a sword in two bags is two swords
        3: {heroBags: 1, altBags: 1},
        // junk in a bag
        4: {altBags: 7},
        // worn gear is left alone
        5: {worn: 1, heroBags: 1},
        // a material in storage only
        6: {mats: 100},
      },
      items: {
        1: {'type': 'CraftingMaterial', 'rarity': 'Basic'},
        2: {'type': 'Consumable', 'rarity': 'Fine'},
        3: {'type': 'Weapon', 'rarity': 'Exotic'},
        4: {'type': 'Trophy', 'rarity': 'Junk', 'vendor_value': 16},
        5: {'type': 'Armor', 'rarity': 'Ascended'},
      },
      materialIds: {1, 6},
    );

    test('materials outside storage can be deposited', () {
      expect(report.deposit.map((r) => r.itemId), [1]);
      expect(report.deposit.single.count, 25);
      expect(report.deposit.single.places.keys, unorderedEquals([bank, heroBags]));
    });

    test('stackables in several places are split, gear is not', () {
      expect(report.split.map((r) => r.itemId), [2]);
      expect(report.split.single.count, 14);
    });

    test('junk and what it sells for', () {
      expect(report.junk.map((r) => r.itemId), [4]);
      expect(report.junkValue, 7 * 16);
    });

    test('a slot at the guessed size is full', () {
      expect(report.storageCap, 250);
      expect(report.full.map((r) => r.itemId), [1]);
      expect(report.isEmpty, isFalse);
    });
  });

  test('owned items filter by place and sort by how many', () {
    final owned = {
      1: {bank: 3},
      2: {heroBags: 50, bank: 1},
      3: {worn: 1},
    };
    expect(searchOwned(owned, '', null, null), [2, 1, 3]);
    expect(searchOwned(owned, '', OwnedKind.bank, null), [2, 1]);
    expect(searchOwned(owned, '', OwnedKind.equipped, null), [3]);
    // without names nothing matches a query
    expect(searchOwned(owned, 'sword', null, null), isEmpty);
  });

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
