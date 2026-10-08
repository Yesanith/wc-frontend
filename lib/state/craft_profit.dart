import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/recipe_book.dart';
import 'account.dart';
import 'market.dart';

/// what making one recipe and selling the result comes to, from the prices of the trading post now
class CraftProfit {
  const CraftProfit({
    required this.recipe,
    required this.cost,
    required this.revenue,
    required this.demand,
    required this.supply,
  });

  final BookRecipe recipe;

  /// the materials, each bought at the lowest listing
  final int cost;

  /// what the result brings after the fees, listed a copper under the lowest listing
  final int revenue;

  /// how many are wanted at the top buy order and how many are for sale, of the result
  final int demand;
  final int supply;

  int get itemId => recipe.output;
  int get profit => revenue - cost;

  /// the profit as a part of what was spent
  double get returnOnCost => cost <= 0 ? 0 : profit / cost;
}

/// what a listing at [price] copper brings after the fees: 5% to list it and 10% when it sells
int afterFees(int price) => price - (price * 0.05).ceil() - (price * 0.10).ceil();

/// the recipes ranked by what they earn. the cost counts only the materials of the recipe itself, each at the
/// lowest listing, so an intermediate that could be made cheaper is priced as it is sold. a recipe whose
/// materials or result have no listing is left out, as are forge and legendary ones and those nobody is buying
///
/// [discipline] keeps one craft, [learned] keeps recipes the account knows when it is given, [minDemand] leaves out
/// results that nobody puts a buy order on
List<CraftProfit> rankCrafts(
  RecipeBook book,
  Map<int, TpPrice> prices, {
  String? discipline,
  Set<int>? learned,
  int minDemand = 20,
  bool byReturn = false,
  int limit = 200,
}) {
  final out = <CraftProfit>[];
  for (final list in book.byOutput.values) {
    for (final recipe in list) {
      if (recipe.id <= 0 || recipe.isForge || recipe.legendary || recipe.ingredients.isEmpty) continue;
      if (discipline != null && !recipe.disciplines.contains(discipline)) continue;
      if (learned != null && !learned.contains(recipe.id)) continue;
      final result = prices[recipe.output];
      if (result == null || result.sell <= 1 || result.demand < minDemand) continue;
      var cost = 0;
      var priced = true;
      for (final (id, count) in recipe.ingredients) {
        final ingredient = prices[id];
        if (ingredient == null || ingredient.sell <= 0) {
          priced = false;
          break;
        }
        cost += ingredient.sell * count;
      }
      if (!priced || cost <= 0) continue;
      out.add(CraftProfit(
        recipe: recipe,
        cost: cost,
        revenue: afterFees(result.sell - 1) * recipe.outputCount,
        demand: result.demand,
        supply: result.supply,
      ));
    }
  }
  out.removeWhere((c) => c.profit <= 0);
  out.sort((a, b) {
    final by = byReturn ? b.returnOnCost.compareTo(a.returnOnCost) : b.profit.compareTo(a.profit);
    return by != 0 ? by : a.itemId.compareTo(b.itemId);
  });
  return out.take(math.max(0, limit)).toList();
}

/// the ranking for the recipes the account has learned: the recipes it knows, empty without the unlocks permission
final learnedForProfitProvider = Provider.autoDispose<Set<int>?>((ref) {
  final learned = ref.watch(learnedRecipesProvider).valueOrNull;
  return learned == null || learned.isEmpty ? null : learned;
});
