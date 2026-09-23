import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'account.dart';
import 'api.dart';
import 'settings.dart';

final goalItemsProvider = FutureProvider<Map<int, Json>>((ref) async {
  final api = accountApi(ref);
  final goals = ref.watch(goalsProvider);
  final ids = {for (final g in goals) for (final i in g.items) i.itemId};
  if (ids.isEmpty) return const {};
  return api.items(ids);
});

/// how many of each item the goal still needs, after counting what the
/// account already holds. an empty map means the goal is complete
Map<int, int> missingForGoal(List<Goal> goals, String goalId, Map<int, int> owned) {
  Goal? goal;
  for (final g in goals) {
    if (g.id == goalId) goal = g;
  }
  final missing = <int, int>{};
  if (goal == null) return missing;
  for (final item in goal.items) {
    final have = owned[item.itemId] ?? 0;
    if (have < item.need) missing[item.itemId] = item.need - have;
  }
  return missing;
}

/// what the missing part of a goal would cost at current sell listings
/// the cost is just the shopping list added up, no second round of lookups
final goalCostProvider = FutureProvider.family<int, String>((ref, goalId) async {
  final rows = await ref.watch(goalShoppingProvider(goalId).future);
  return rows.fold<int>(0, (sum, row) => sum + row.total);
});

class ShoppingRow {
  const ShoppingRow(this.itemId, this.item, this.missing, this.unitPrice);
  final int itemId;
  final Json? item;
  final int missing;
  final int unitPrice;

  int get total => missing * unitPrice;
  String get name => (item?['name'] as String?) ?? 'Item #$itemId';
}

/// missing pieces of a goal, cheapest total first, so the next purchase is
/// obvious. items with no listing end up at the bottom
final goalShoppingProvider = FutureProvider.family<List<ShoppingRow>, String>((ref, goalId) async {
  final api = accountApi(ref);
  final goals = ref.watch(goalsProvider);
  final totals = await ref.watch(accountTotalsProvider.future);
  final missing = missingForGoal(goals, goalId, totals);
  if (missing.isEmpty) return const [];

  final items = await api.items(missing.keys);
  final prices = await api.prices(missing.keys);
  final rows = <ShoppingRow>[];
  for (final e in missing.entries) {
    final sells = prices[e.key]?['sells'];
    rows.add(ShoppingRow(
      e.key,
      items[e.key],
      e.value,
      sells is Map ? asInt(sells['unit_price']) : 0,
    ));
  }
  rows.sort((a, b) {
    if ((a.total == 0) != (b.total == 0)) return a.total == 0 ? 1 : -1;
    return a.total.compareTo(b.total);
  });
  return rows;
});
