import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/l10n/strings.dart';
import 'package:tyria_codex/screens/character_detail_screen.dart';
import 'package:tyria_codex/services/recipe_book.dart';
import 'package:tyria_codex/state/collections.dart';
import 'package:tyria_codex/state/crafting.dart';
import 'package:tyria_codex/state/professions.dart';
import 'package:tyria_codex/state/pvp.dart';
import 'package:tyria_codex/state/wvw.dart';

void main() {
  group('leaderboards', () {
    test('the ladder comes first, unknown boards after the known ones', () {
      expect(sortBoards(['guild', 'zzz', 'ladder', 'legendary']), ['ladder', 'legendary', 'guild', 'zzz']);
    });

    test('scores are named after the season scorings and rows sorted by rank', () {
      final season = {
        'leaderboards': {
          'ladder': {
            'scorings': [
              {'id': 'A', 'name': 'Rating'},
              {'id': 'B', 'name': 'Wins'},
            ],
          },
        },
      };
      final rows = boardRows([
        {
          'rank': 2,
          'name': 'Second.1234',
          'scores': [
            {'id': 'A', 'value': 1500},
            {'id': 'B', 'value': 40},
          ],
        },
        {
          'rank': 1,
          'name': 'First.5678',
          'scores': [
            {'id': 'A', 'value': 1700},
          ],
        },
        // guild boards name the guild and the team that played
        {'rank': 3, 'name': 'Some Guild', 'team': 'Squad', 'scores': []},
      ], season, 'ladder');
      expect(rows.map((r) => r.name), ['First.5678', 'Second.1234', 'Some Guild · Squad']);
      expect(rows[1].scores, [('Rating', 1500), ('Wins', 40)]);
    });

    test('a board the season does not describe still shows its numbers', () {
      final rows = boardRows([
        {
          'rank': 1,
          'name': 'x',
          'scores': [
            {'id': 'Q', 'value': 3},
          ],
        },
      ], null, 'guild');
      expect(rows.single.scores, [('', 3)]);
    });
  });

  group('used in', () {
    final book = RecipeBook({
      100: [
        const BookRecipe(
            id: 7,
            output: 100,
            outputCount: 1,
            disciplines: ['Weaponsmith'],
            minRating: 0,
            ingredients: [
              (1, 2),
              (2, 1),
            ]),
      ],
      200: [
        const BookRecipe(
            output: 200,
            outputCount: 1,
            disciplines: [mysticForge],
            minRating: 0,
            ingredients: [
              (1, 77),
            ]),
      ],
    });

    test('the book finds recipes by id and by ingredient', () {
      expect(book.byId[7]?.output, 100);
      expect(book.byId.containsKey(0), isFalse);
      expect(book.usedIn(1).map((r) => r.output), containsAll([100, 200]));
      expect(book.usedIn(3), isEmpty);
    });

    test('api results and the book merge into one entry per item made', () {
      final merged = mergeUsedIn(
        book,
        [7, 9],
        {
          9: {
            'id': 9,
            'output_item_id': 300,
            'disciplines': ['Chef'],
          },
        },
        1,
      );
      final byOutput = {for (final e in merged) e.output: e};
      expect(byOutput.keys, unorderedEquals([100, 200, 300]));
      expect(byOutput[100]!.recipeId, 7);
      expect(byOutput[200]!.disciplines, [mysticForge]);
      expect(byOutput[300]!.disciplines, ['Chef']);
    });

    test('offline, the book alone still answers', () {
      final merged = mergeUsedIn(book, const [], const {}, 1);
      expect(merged.map((e) => e.output), unorderedEquals([100, 200]));
    });
  });

  group('wardrobe skins', () {
    test('only the fields the list needs are kept', () {
      final compact = compactSkin({
        'id': 5,
        'name': 'Helm',
        'icon': 'https://x/y.png',
        'rarity': 'Exotic',
        'type': 'Armor',
        'description': 'long text',
        'flags': ['ShowInWardrobe'],
        'details': {'type': 'Helm', 'weight_class': 'Heavy', 'dye_slots': {}},
      });
      expect(compact.keys, unorderedEquals(['id', 'name', 'icon', 'rarity', 'type', 'details']));
      expect(compact['details'], {'type': 'Helm', 'weight_class': 'Heavy'});
    });

    test('the subtype names the slot and the weight', () {
      expect(
          skinSubtype({
            'details': {'type': 'Helm', 'weight_class': 'Heavy'}
          }),
          'Helm · Heavy');
      expect(
          skinSubtype({
            'details': {'type': 'Greatsword'}
          }),
          'Greatsword');
      expect(
          skinSubtype({
            'details': {'type': 'Coat', 'weight_class': 'Clothing'}
          }),
          'Coat');
      // weapons report a weight class of None
      expect(
          skinSubtype({
            'details': {'type': 'Shortbow', 'weight_class': 'None'}
          }),
          'Shortbow');
      expect(
          skinSubtype({
            'details': {'type': 'HelmAquatic', 'weight_class': 'Light'}
          }),
          'Helm Aquatic · Light');
      expect(
          skinSubtype({
            'details': {'type': 'LongBow'}
          }),
          'Longbow');
      expect(skinSubtype({'details': {}}), isNull);
      expect(skinSubtype(null), isNull);
    });
  });

  group('class icons', () {
    const guardian = ProfessionInfo(
      id: 'Guardian',
      name: 'Wächter',
      icon: 'core.png',
      iconBig: 'core_big.png',
      specializations: [
        {'id': 42, 'name': 'Zeal', 'elite': false},
        {
          'id': 27,
          'name': 'Dragonhunter',
          'elite': true,
          'profession_icon': 'dh.png',
          'profession_icon_big': 'dh_big.png'
        },
      ],
      weapons: {},
    );

    Map<String, dynamic> character(List<int> specs) => {
          'profession': 'Guardian',
          'build_tabs': [
            {
              'is_active': true,
              'build': {
                'specializations': [
                  for (final id in specs) {'id': id, 'traits': []},
                ],
              },
            },
          ],
        };

    test('an elite line in the active build gives its own icon', () {
      final c = character([42, 27]);
      expect(activeElite(c, guardian)?['name'], 'Dragonhunter');
      expect(classIcon(c, guardian), 'dh.png');
      expect(classIcon(c, guardian, big: true), 'dh_big.png');
    });

    test('a core build shows the profession icon', () {
      final c = character([42]);
      expect(activeElite(c, guardian), isNull);
      expect(classIcon(c, guardian), 'core.png');
      expect(classIcon(c, guardian, big: true), 'core_big.png');
    });

    test('nothing to show before the professions load', () {
      expect(classIcon(character([27]), null), isNull);
    });
  });

  test('world names come from all_worlds and skip unknown team ids', () {
    final match = {
      'all_worlds': {
        'red': [1001, 11001],
        'blue': [2002],
        'green': [12001],
      },
    };
    final worlds = {1001: 'Anvil Rock', 2002: 'Desolation'};
    expect(wvwWorldNames(match, 'red', worlds), ['Anvil Rock']);
    expect(wvwWorldNames(match, 'blue', worlds), ['Desolation']);
    expect(wvwWorldNames(match, 'green', worlds), isEmpty);
  });

  test('slots have a name in every language, unknown ones read as words', () {
    for (final lang in AppLang.values) {
      final s = S(lang);
      for (final slot in ['PowerCore', 'SensoryArray', 'ServiceChip', 'FishingRod', 'FishingBait', 'FishingLure']) {
        expect(slotLabel(s, slot), isNot(startsWith('slot_')), reason: '${lang.code} $slot');
      }
      expect(slotLabel(s, 'GatheringToolkit'), 'Gathering Toolkit');
    }
  });
}
