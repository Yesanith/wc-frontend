import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/services/recipe_book.dart';
import 'package:tyria_codex/state/crafting.dart';

BookRecipe recipe(int output, List<(int, int)> ingredients, {int count = 1, List<String> disciplines = const ['Weaponsmith']}) =>
    BookRecipe(
      output: output,
      outputCount: count,
      disciplines: disciplines,
      minRating: 0,
      ingredients: ingredients,
    );

RecipeBook bookOf(List<BookRecipe> recipes) {
  final byOutput = <int, List<BookRecipe>>{};
  for (final r in recipes) {
    byOutput.putIfAbsent(r.output, () => []).add(r);
  }
  return RecipeBook(byOutput);
}

void main() {
  test('regular crafting wins over the forge for the same item', () {
    final forge = recipe(1, [(9, 1)], disciplines: const [mysticForge]);
    final normal = recipe(1, [(8, 1)]);
    final book = bookOf([forge, normal]);
    expect(book.recipeFor(1), same(normal));
  });

  test('builds the whole tree from the book', () {
    // 1 needs 2x item 2 and 1x item 3, item 2 is itself made from 4x item 4
    final book = bookOf([
      recipe(1, [(2, 2), (3, 1)]),
      recipe(2, [(4, 4)]),
    ]);
    final tree = buildFromBook(book, 1, const {});
    expect(tree.children.map((c) => c.itemId), [2, 3]);
    expect(tree.children.first.children.single.itemId, 4);
    expect(tree.children.first.children.single.perRun, 4);
    expect(tree.children.last.isLeaf, isTrue);
    expect(bookTreeIds(book, 1), {1, 2, 3, 4});
  });

  test('a cycle stops instead of recursing forever', () {
    final book = bookOf([
      recipe(1, [(2, 1)]),
      recipe(2, [(1, 1)]),
    ]);
    final tree = buildFromBook(book, 1, const {});
    expect(tree.children.single.children.single.isLeaf, isTrue);
  });

  test('forge disciplines sort after the rest', () {
    final book = bookOf([
      recipe(1, [(2, 1)], disciplines: const [mysticForge]),
      recipe(3, [(2, 1)], disciplines: const ['Tailor', 'Armorsmith']),
    ]);
    expect(book.disciplines, ['Armorsmith', 'Tailor', mysticForge]);
  });
}
