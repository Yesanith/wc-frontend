import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/collections.dart';

void main() {
  group('homestead categories', () {
    const names = {'6': 'Planters and Topiaries', '15': 'Crafted', '14': 'Other'};

    test('a decoration is in every category it lists, by name', () {
      expect(
        decorationGroups({
          'categories': [6, 15],
        }, names),
        ['Planters and Topiaries', 'Crafted'],
      );
      expect(
        decorationGroups({
          'categories': [14],
        }, names),
        ['Other'],
      );
    });

    test('a category the game gave no name is left out, no categories is none', () {
      expect(
        decorationGroups({
          'categories': [99, 14],
        }, names),
        ['Other'],
      );
      expect(decorationGroups({'name': 'x'}, names), isEmpty);
      expect(decorationGroups(null, names), isEmpty);
    });

    test('the categories are asked from the homestead', () {
      expect(homesteadCategoriesPath, '/homestead/decorations/categories');
    });
  });
}
