import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/pvp.dart';

/// the nine tiers exactly as /v2/pvp/ranks returns them
const _tiers = [
  PvpRank('Rabbit', null, 1, 9),
  PvpRank('Deer', null, 10, 19),
  PvpRank('Dolyak', null, 20, 29),
  PvpRank('Wolf', null, 30, 39),
  PvpRank('Tiger', null, 40, 49),
  PvpRank('Bear', null, 50, 59),
  PvpRank('Shark', null, 60, 69),
  PvpRank('Phoenix', null, 70, 79),
  PvpRank('Dragon', null, 80, 81),
];

void main() {
  group('rankTierFor', () {
    test('picks the tier a rank sits in', () {
      expect(rankTierFor(_tiers, 1)?.name, 'Rabbit');
      expect(rankTierFor(_tiers, 9)?.name, 'Rabbit');
      expect(rankTierFor(_tiers, 10)?.name, 'Deer');
      expect(rankTierFor(_tiers, 35)?.name, 'Wolf');
      expect(rankTierFor(_tiers, 73)?.name, 'Phoenix');
      expect(rankTierFor(_tiers, 80)?.name, 'Dragon');
    });

    test('every tier boundary lands on the right side', () {
      for (final tier in _tiers) {
        expect(rankTierFor(_tiers, tier.minRank)?.name, tier.name, reason: 'floor of ${tier.name}');
        expect(rankTierFor(_tiers, tier.maxRank)?.name, tier.name, reason: 'ceiling of ${tier.name}');
      }
    });

    test('the top tier is open ended', () {
      // the api caps Dragon at 81, but ranks keep going past it
      expect(rankTierFor(_tiers, 82)?.name, 'Dragon');
      expect(rankTierFor(_tiers, 500)?.name, 'Dragon');
    });

    test('a rank below the first tier has none', () {
      expect(rankTierFor(_tiers, 0), isNull);
    });

    test('an empty tier list never throws', () {
      expect(rankTierFor(const [], 40), isNull);
    });

    test('order of the tier list does not matter', () {
      final shuffled = [..._tiers.reversed];
      expect(rankTierFor(shuffled, 35)?.name, 'Wolf');
      expect(rankTierFor(shuffled, 500)?.name, 'Dragon');
    });
  });
}
