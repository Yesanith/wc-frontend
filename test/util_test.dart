import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/util.dart';

void main() {
  setUp(() => groupSeparator = ',');

  group('asInt', () {
    test('passes ints through and truncates doubles', () {
      expect(asInt(5), 5);
      expect(asInt(5.9), 5);
      expect(asInt(-5.9), -5);
    });

    test('parses numeric strings and falls back to zero', () {
      expect(asInt('12'), 12);
      expect(asInt('abc'), 0);
      expect(asInt(null), 0);
    });
  });

  group('fmtInt', () {
    test('groups thousands', () {
      expect(fmtInt(0), '0');
      expect(fmtInt(999), '999');
      expect(fmtInt(1000), '1,000');
      expect(fmtInt(1284567), '1,284,567');
    });

    test('keeps the sign outside the grouping', () {
      expect(fmtInt(-1284567), '-1,284,567');
    });

    test('follows the separator set by the app language', () {
      groupSeparator = '.';
      expect(fmtInt(1284567), '1.284.567');
    });
  });

  group('compact', () {
    test('switches units at 10k and 1M', () {
      expect(compact(9999), '9,999');
      expect(compact(10000), '10.0k');
      expect(compact(999999), '1000.0k');
      expect(compact(1000000), '1.0M');
    });
  });

  test('fmtHours converts seconds and labels the unit', () {
    expect(fmtHours(7200), '2 h');
    expect(fmtHours(3599), '0 h');
    expect(fmtHours(36000, 'hrs'), '10 hrs');
  });

  group('Coins', () {
    test('splits copper into gold, silver and copper', () {
      final c = Coins(123456);
      expect(c.gold, 12);
      expect(c.silver, 34);
      expect(c.copper, 56);
    });

    test('handles amounts below one silver', () {
      final c = Coins(7);
      expect(c.gold, 0);
      expect(c.silver, 0);
      expect(c.copper, 7);
    });
  });

  group('titleCase', () {
    test('builds a display name from an api id', () {
      expect(titleCase('thief'), 'Thief');
      expect(titleCase('stronghold_of_the_faithful'), 'Stronghold of the Faithful');
    });

    test('capitalises a minor word when it starts the name', () {
      expect(titleCase('the_key_of_ahdashim'), 'The Key of Ahdashim');
    });
  });

  group('attributeName', () {
    test('maps the api keys the game renames', () {
      expect(attributeName('CritDamage'), 'Ferocity');
      expect(attributeName('ConditionDuration'), 'Expertise');
      expect(attributeName('BoonDuration'), 'Concentration');
    });

    test('splits camel case for everything else', () {
      expect(attributeName('MagicFind'), 'Magic Find');
      expect(attributeName('Power'), 'Power');
    });
  });

  group('intList', () {
    test('drops nulls and coerces the rest', () {
      expect(intList([1, null, '3', 4.7]), [1, 3, 4]);
    });

    test('treats null as empty', () {
      expect(intList(null), isEmpty);
    });
  });
}
