import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/l10n/strings.dart';
import 'package:wondrous_compass/state/clock.dart';
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

  group('a date in words', () {
    final friday = DateTime(2026, 11, 13);

    test('follows the language of the app', () {
      expect(fullDateText(const S(AppLang.en), friday), 'Friday, November 13, 2026');
      expect(fullDateText(const S(AppLang.tr), friday), '13 Kasım 2026 Cuma');
      expect(fullDateText(const S(AppLang.de), friday), 'Freitag, 13. November 2026');
      expect(fullDateText(const S(AppLang.fr), friday), 'vendredi 13 novembre 2026');
      expect(shortDateText(const S(AppLang.tr), friday), '13 Kasım 2026');
    });

    test('has seven days and twelve months in every language', () {
      for (final lang in AppLang.values) {
        final s = S(lang);
        expect(s.t('weekdays').split(','), hasLength(7), reason: lang.code);
        expect(s.t('months').split(','), hasLength(12), reason: lang.code);
      }
    });
  });

  group('capitals', () {
    tearDown(() => turkishCasing = false);

    test('are the plain ones in most languages', () {
      turkishCasing = false;
      expect('Şimdi eşitle'.caps, 'ŞIMDI EŞITLE');
    });

    test('have the dotted İ in Turkish', () {
      turkishCasing = true;
      expect('Şimdi eşitle'.caps, 'ŞİMDİ EŞİTLE');
      expect('Nisan'.caps, 'NİSAN');
    });
  });
}
