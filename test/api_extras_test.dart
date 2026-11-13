import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/wvw.dart';
import 'package:wondrous_compass/util.dart';

void main() {
  group('the worlds of a matchup', () {
    final match = {
      'all_worlds': {
        'red': [1001, 1002],
        'blue': [2204],
        'green': [9999],
      },
    };
    final worlds = {1001: 'Anvil Rock', 1002: 'Borlis Pass', 2204: 'Abaddon'};

    test('are named as they always were', () {
      expect(wvwWorldNames(match, 'red', worlds), ['Anvil Rock', 'Borlis Pass']);
      expect(wvwWorldNames(match, 'green', worlds), isEmpty);
    });

    test('carry how full each is when it is known', () {
      final population = {1001: 'Full', 2204: 'Low'};
      expect(wvwWorldNames(match, 'red', worlds, extra: (id) => population[id]), ['Anvil Rock (Full)', 'Borlis Pass']);
      expect(wvwWorldNames(match, 'blue', worlds, extra: (id) => population[id]), ['Abaddon (Low)']);
    });
  });

  group('what an item is bound to', () {
    test('is nothing for an item that was never bound', () {
      const slot = ItemSlot(1, 3, null);
      expect(slot.binding, isNull);
      expect(slot.boundTo, isNull);
    });

    test('is the account, or the character and its name', () {
      const soul = ItemSlot(1, 1, null, binding: 'Character', boundTo: 'Leo');
      expect(soul.binding, 'Character');
      expect(soul.boundTo, 'Leo');
      expect(const ItemSlot(2, 1, null, binding: 'Account').binding, 'Account');
    });
  });
}
