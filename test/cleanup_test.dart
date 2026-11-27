import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/cleanup.dart';
import 'package:wondrous_compass/util.dart';

CleanupStack stack(int id, Map<String, dynamic> item, {int count = 1, String? binding, String? where}) =>
    CleanupStack(ItemSlot(id, count, {'id': id, ...item}, binding: binding), where);

void main() {
  const ecto = 2500; // 25 silver for a glob
  test('grey items go to a merchant for their merchant price', () {
    final plan = planCleanup([
      stack(1, {'rarity': 'Junk', 'type': 'Trophy', 'vendor_value': 40}, count: 5),
    ], const {}, ecto);
    expect(plan.of(CleanupAction.junk).single.value, 200);
  });

  test('rare gear of level 80 is salvaged when its ectoplasm is worth more than its sale', () {
    final plan = planCleanup([
      stack(2, {'rarity': 'Rare', 'type': 'Weapon', 'level': 80}),
    ], {
      2: 1000
    }, ecto);
    final e = plan.of(CleanupAction.salvage).single;
    expect(e.ectos, ectosPerRare);
    expect(e.value, (afterFees(ecto) * ectosPerRare).round());
  });

  test('and sold when its sale is worth more', () {
    final plan = planCleanup([
      stack(3, {'rarity': 'Rare', 'type': 'Armor', 'level': 80}),
    ], {
      3: 90000
    }, ecto);
    expect(plan.of(CleanupAction.sell).single.value, afterFees(90000));
    expect(plan.of(CleanupAction.salvage), isEmpty);
  });

  test('a material in the bank or a bag belongs in the material storage', () {
    final plan = planCleanup([
      stack(4, {'rarity': 'Basic', 'type': 'CraftingMaterial'}, count: 250, where: 'Aurel'),
    ], const {}, ecto);
    expect(plan.of(CleanupAction.deposit).single.stack.where, 'Aurel');
  });

  test('bound, ascended and legendary items are kept and not listed', () {
    final plan = planCleanup([
      stack(5, {'rarity': 'Exotic', 'type': 'Weapon', 'level': 80}, binding: 'Account'),
      stack(6, {
        'rarity': 'Exotic',
        'type': 'Weapon',
        'level': 80,
        'flags': ['AccountBound']
      }),
      stack(7, {'rarity': 'Ascended', 'type': 'Trinket', 'level': 80}),
      stack(8, {'rarity': 'Legendary', 'type': 'Weapon', 'level': 80}),
    ], {
      5: 1,
      6: 1,
      7: 1,
      8: 1
    }, ecto);
    expect(plan.isEmpty, isTrue);
  });

  test('what nobody buys is not offered for sale', () {
    final plan = planCleanup([
      stack(9, {'rarity': 'Masterwork', 'type': 'Weapon', 'level': 50})
    ], const {}, ecto);
    expect(plan.isEmpty, isTrue);
  });

  test('the trading post keeps 15 % of a sale', () {
    expect(afterFees(100), 85);
    expect(afterFees(10), 8);
  });
}
