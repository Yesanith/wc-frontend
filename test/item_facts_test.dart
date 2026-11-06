import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/l10n/strings.dart';
import 'package:wondrous_compass/screens/item_detail_screen.dart';

void main() {
  const s = S(AppLang.en);

  test('a weapon lists strength, damage type and infusion slots', () {
    final item = {'type': 'Weapon'};
    final details = {
      'type': 'Greatsword',
      'damage_type': 'Physical',
      'min_power': 1045,
      'max_power': 1155,
      'defense': 0,
      'infusion_slots': [
        {
          'flags': ['Infusion'],
        },
        {
          'flags': ['Infusion'],
        },
      ],
    };
    final rows = itemFactRows(s, item, details);
    expect(rows.map((r) => r.$1), [s.t('weapon_strength'), s.t('damage_type'), s.t('infusion_slots')]);
    expect(rows.first.$2, '1,045 – 1,155');
    expect(rows.last.$2, '2');
  });

  test('armour, bags and consumables show their own facts', () {
    expect(itemFactRows(s, {'type': 'Armor'}, {'defense': 121, 'weight_class': 'Heavy'}).map((r) => r.$2), [
      '121',
      'Heavy',
    ]);
    expect(itemFactRows(s, {'type': 'Bag'}, {'size': 32}).single.$2, '32');
    expect(itemFactRows(s, {'type': 'Consumable'}, {'duration_ms': 3600000}).single.$2, '1 h');
    expect(itemFactRows(s, {'type': 'Consumable'}, {'duration_ms': 1800000}).single.$2, '30 min');
    expect(itemFactRows(s, {'type': 'Trophy'}, null), isEmpty);
  });

  test('binding flags read in plain words, other flags are left out', () {
    final labels = itemFlagLabels(s, {
      'flags': ['AccountBound', 'NoSell', 'HideSuffix', 'Unique'],
    });
    expect(labels, [s.t('flag_account_bound'), s.t('flag_unique'), s.t('flag_no_sell')]);
    expect(itemFlagLabels(s, {}), isEmpty);
  });
}
