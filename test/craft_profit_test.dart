import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/services/recipe_book.dart';
import 'package:wondrous_compass/state/craft_profit.dart';
import 'package:wondrous_compass/state/market.dart';

BookRecipe recipe(
  int id,
  int output,
  List<(int, int)> ingredients, {
  int outputCount = 1,
  List<String> disciplines = const ['Weaponsmith'],
  bool legendary = false,
}) => BookRecipe(
  id: id,
  output: output,
  outputCount: outputCount,
  disciplines: disciplines,
  minRating: 0,
  ingredients: ingredients,
  legendary: legendary,
);

RecipeBook book(List<BookRecipe> recipes) {
  final byOutput = <int, List<BookRecipe>>{};
  for (final r in recipes) {
    byOutput.putIfAbsent(r.output, () => []).add(r);
  }
  return RecipeBook(byOutput);
}

// buy, sell, demand, supply
TpPrice price(int sell, {int buy = 1, int demand = 100, int supply = 100}) => TpPrice(buy, sell, demand, supply);

void main() {
  group('afterFees', () {
    test('takes 5% and 10%, each rounded up', () {
      expect(afterFees(1000), 850);
      expect(afterFees(101), 101 - 6 - 11);
      expect(afterFees(1), 1 - 1 - 1);
    });
  });

  group('rankCrafts', () {
    // one result (10) made of 2 x item 1 and 1 x item 2
    final base = book([
      recipe(100, 10, [(1, 2), (2, 1)]),
    ]);

    test('prices the materials at the lowest listing and the result a copper under its own', () {
      final prices = {1: price(100), 2: price(50), 10: price(1001)};
      final ranked = rankCrafts(base, prices);
      expect(ranked, hasLength(1));
      expect(ranked.single.cost, 250);
      // listed at 1000: 1000 - 50 - 100
      expect(ranked.single.revenue, 850);
      expect(ranked.single.profit, 600);
      expect(ranked.single.returnOnCost, closeTo(2.4, 1e-9));
    });

    test('multiplies the revenue by what one craft makes', () {
      final many = book([
        recipe(100, 10, [(1, 1)], outputCount: 5),
      ]);
      final ranked = rankCrafts(many, {1: price(100), 10: price(201)});
      expect(ranked.single.revenue, afterFees(200) * 5);
    });

    test('leaves out what does not earn', () {
      final prices = {1: price(1000), 2: price(1000), 10: price(500)};
      expect(rankCrafts(base, prices), isEmpty);
    });

    test('leaves out a recipe with a material nobody sells, or a result nobody lists', () {
      expect(rankCrafts(base, {1: price(100), 10: price(5000)}), isEmpty, reason: 'item 2 has no price');
      expect(rankCrafts(base, {1: price(100), 2: price(0), 10: price(5000)}), isEmpty, reason: 'item 2 has no listing');
      expect(rankCrafts(base, {1: price(100), 2: price(100)}), isEmpty, reason: 'the result has no price');
    });

    test('leaves out results that nobody puts a buy order on', () {
      final prices = {1: price(100), 2: price(50), 10: price(1001, demand: 5)};
      expect(rankCrafts(base, prices), isEmpty);
      expect(rankCrafts(base, prices, minDemand: 0), hasLength(1));
    });

    test('leaves out forge and legendary recipes and those with no api id', () {
      final odd = book([
        recipe(0, 11, [(1, 1)]),
        recipe(101, 12, [(1, 1)], disciplines: const [mysticForge]),
        recipe(102, 13, [(1, 1)], legendary: true),
      ]);
      final prices = {1: price(10), 11: price(10000), 12: price(10000), 13: price(10000)};
      expect(rankCrafts(odd, prices), isEmpty);
    });

    test('keeps one discipline and the recipes an account has learned', () {
      final two = book([
        recipe(100, 10, [(1, 1)], disciplines: const ['Weaponsmith']),
        recipe(200, 20, [(1, 1)], disciplines: const ['Tailor']),
      ]);
      final prices = {1: price(10), 10: price(1001), 20: price(1001)};
      expect(rankCrafts(two, prices), hasLength(2));
      expect(rankCrafts(two, prices, discipline: 'Tailor').single.itemId, 20);
      expect(rankCrafts(two, prices, learned: {100}).single.itemId, 10);
    });

    test('sorts by profit, or by return', () {
      final two = book([
        // earns a lot, spends a lot
        recipe(100, 10, [(1, 10)]),
        // earns less, spends very little
        recipe(200, 20, [(2, 1)]),
      ]);
      final prices = {1: price(100), 2: price(10), 10: price(5001), 20: price(301)};
      expect(rankCrafts(two, prices).map((c) => c.itemId), [10, 20]);
      expect(rankCrafts(two, prices, byReturn: true).map((c) => c.itemId), [20, 10]);
    });

    test('keeps no more than the limit', () {
      final many = book([
        for (var i = 0; i < 10; i++) recipe(100 + i, 10 + i, [(1, 1)]),
      ]);
      final prices = {1: price(10), for (var i = 0; i < 10; i++) 10 + i: price(1001)};
      expect(rankCrafts(many, prices, limit: 3), hasLength(3));
    });
  });

  group('parseCraftProfit', () {
    Map<String, dynamic> row({
      int recipe = 100,
      int item = 10,
      int count = 1,
      List<String> disciplines = const ['Weaponsmith'],
      int cost = 250,
      int revenue = 850,
    }) => {
      'recipe_id': recipe,
      'item_id': item,
      'count': count,
      'disciplines': disciplines,
      'cost': cost,
      'revenue': revenue,
      'demand': 100,
      'supply': 50,
    };

    test('reads the rows of the server, in its order, with when it read the prices', () {
      final answer = parseCraftProfit({
        'updated_at': '2026-10-08T06:00:00+00:00',
        'rows': [row(recipe: 200, item: 20, count: 5), row()],
      })!;
      expect(answer.rows.map((r) => r.itemId), [20, 10]);
      expect(answer.rows.first.count, 5);
      expect(answer.rows.last.profit, 600);
      expect(answer.rows.last.disciplines, ['Weaponsmith']);
      expect(answer.rows.last.recipeId, 100);
      expect(answer.updatedAt, DateTime.utc(2026, 10, 8, 6));
    });

    test('is nothing when it is not an answer, or has nothing to rank yet', () {
      expect(parseCraftProfit(null), isNull);
      expect(parseCraftProfit('x'), isNull);
      expect(parseCraftProfit(<String, dynamic>{'rows': <dynamic>[]}), isNull);
      expect(parseCraftProfit(<String, dynamic>{'rows': 'x'}), isNull);
      expect(
        parseCraftProfit({
          'rows': [
            'nope',
            {'item_id': 0},
          ],
        }),
        isNull,
      );
    });

    test('leaves out a row that is not one and keeps the others', () {
      final answer = parseCraftProfit({
        'updated_at': null,
        'rows': ['nope', row(item: 0), row(item: 30)],
      })!;
      expect(answer.rows.map((r) => r.itemId), [30]);
      expect(answer.updatedAt, isNull);
    });

    test('a count of nothing is one', () {
      final answer = parseCraftProfit({
        'rows': [row(count: 0)],
      })!;
      expect(answer.rows.single.count, 1);
    });
  });
}
