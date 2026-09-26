import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/reference.dart';
import 'package:tyria_codex/state/vault.dart';
import 'package:tyria_codex/state/wvw.dart';

VaultListing listing(String type, int cost) => VaultListing(
      itemId: cost,
      count: 1,
      type: type,
      cost: cost,
      purchased: 0,
      limit: 0,
      item: null,
    );

void main() {
  group('wvwColorOf', () {
    test('finds the team in the team lists', () {
      final match = {
        'all_worlds': {
          'red': [11001, 11002],
          'blue': [11005],
          'green': [11009],
        },
      };
      expect(wvwColorOf(match, 11002), 'red');
      expect(wvwColorOf(match, 11009), 'green');
      expect(wvwColorOf(match, 99999), isNull);
    });

    test('falls back to the single world of each side', () {
      final match = {
        'worlds': {'red': 2001, 'blue': 2002, 'green': 2003},
      };
      expect(wvwColorOf(match, 2002), 'blue');
    });
  });

  test('regions work for team ids and old world ids', () {
    expect(wvwRegion(11001), 'na');
    expect(wvwRegion(12003), 'eu');
    expect(wvwRegion(1008), 'na');
    expect(wvwRegion(2012), 'eu');
  });

  test('rank title is the highest tier reached', () {
    final ranks = [
      {'title': 'Invader', 'min_rank': 1},
      {'title': 'Assaulter', 'min_rank': 20},
      {'title': 'Raider', 'min_rank': 50},
    ];
    expect(wvwRankTitle(ranks, 0), isNull);
    expect(wvwRankTitle(ranks, 20), 'Assaulter');
    expect(wvwRankTitle(ranks, 400), 'Raider');
  });

  group('dyeColor', () {
    test('prefers the cloth colour', () {
      final dye = {
        'base_rgb': [1, 2, 3],
        'cloth': {'rgb': [200, 100, 50]},
      };
      expect(dyeColor(dye), const Color.fromARGB(255, 200, 100, 50));
    });

    test('falls back to the base colour and handles junk', () {
      expect(dyeColor({'base_rgb': [10, 20, 30]}), const Color.fromARGB(255, 10, 20, 30));
      expect(dyeColor(null), isNull);
      expect(dyeColor({'cloth': {'rgb': [1]}}), isNull);
    });
  });

  test('vault shop shows featured, regular, then legacy, each by price', () {
    final sorted = sortVaultListings([
      listing('Legacy', 5),
      listing('Normal', 300),
      listing('Featured', 900),
      listing('Normal', 20),
    ]);
    expect(sorted.map((l) => '${l.type}:${l.cost}'), ['Featured:900', 'Normal:20', 'Normal:300', 'Legacy:5']);
  });

  test('a listing is sold out only with a limit', () {
    expect(VaultListing(itemId: 1, count: 1, type: 'Normal', cost: 1, purchased: 3, limit: 3, item: null).soldOut, isTrue);
    expect(VaultListing(itemId: 1, count: 1, type: 'Normal', cost: 1, purchased: 9, limit: 0, item: null).soldOut, isFalse);
  });
}
