import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/progression.dart';

/// The api names a mastery region after the part of the world it covers, but
/// the hero panel groups the same tracks by release. These pairings were read
/// off /v2/masteries: every region's track list identifies its expansion, for
/// example Desert holds Raptor, Springer, Jackal and Crystal Champion.
void main() {
  group('masteryRegionName', () {
    test('gives the release name the game shows', () {
      expect(masteryRegionName('Tyria'), 'Central Tyria');
      expect(masteryRegionName('Maguuma'), 'Heart of Thorns');
      expect(masteryRegionName('Desert'), 'Path of Fire');
      expect(masteryRegionName('Tundra'), 'Icebrood Saga');
      expect(masteryRegionName('Jade'), 'End of Dragons');
      expect(masteryRegionName('Sky'), 'Secrets of the Obscure');
      expect(masteryRegionName('Wild'), 'Janthir Wilds');
      expect(masteryRegionName('Magic'), 'Visions of Eternity');
    });

    test('passes an unknown region through rather than blanking it', () {
      // a new expansion ships before this table hears about it
      expect(masteryRegionName('Abyss'), 'Abyss');
      expect(masteryRegionName(''), '');
    });
  });

  group('masteryRegionRank', () {
    test('orders the regions the way the hero panel lists them', () {
      const released = ['Tyria', 'Maguuma', 'Desert', 'Tundra', 'Jade', 'Sky', 'Wild', 'Magic'];
      final ranks = [for (final r in released) masteryRegionRank(r)];
      expect(ranks, List.generate(released.length, (i) => i));
    });

    test('sorting by rank beats sorting by the api name', () {
      const apiNames = ['Desert', 'Jade', 'Maguuma', 'Magic', 'Sky', 'Tundra', 'Tyria', 'Wild'];
      final byRank = [...apiNames]..sort((a, b) => masteryRegionRank(a).compareTo(masteryRegionRank(b)));
      expect(byRank.first, 'Tyria');
      expect(byRank[1], 'Maguuma');
      expect(byRank[2], 'Desert');
      expect(byRank.last, 'Magic');
    });

    test('an unknown region sorts last instead of first', () {
      expect(masteryRegionRank('Abyss'), greaterThan(masteryRegionRank('Magic')));
    });
  });
}
