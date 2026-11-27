import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/recipe_book.dart';
import '../util.dart';
import 'account.dart';
import 'api.dart';
import 'crafting.dart';

/// how far the account is from one legendary: what its materials still cost to buy, what they are worth in all, and how many of them
/// the trading post does not sell (gifts of a map, of battle, clovers) that are still missing
class LegendaryDistance {
  const LegendaryDistance({
    required this.itemId,
    required this.item,
    required this.missingCost,
    required this.totalValue,
    required this.unpricedMissing,
  });

  final int itemId;
  final Json? item;
  final int missingCost;
  final int totalValue;
  final int unpricedMissing;

  /// how much of the value of its materials the account has, 0 to 1
  double get progress => totalValue <= 0 ? 0 : (1 - missingCost / totalValue).clamp(0.0, 1.0);
}

/// how far the account is from [root] with [owned], at [prices] (the lowest sell listing per unit)
LegendaryDistance distanceTo(CraftNode root, Map<int, int> owned, Map<int, int> prices) {
  // what is still needed, with the parts the account has taken out, against what the whole of it is worth
  final leaves = craftLeaves(planWithStock(root, 1, owned));
  var missing = 0;
  var unpriced = 0;
  for (final e in leaves.entries) {
    final need = e.value;
    final have = owned[e.key] ?? 0;
    final short = have >= need ? 0 : need - have;
    final unit = prices[e.key] ?? 0;
    if (unit > 0) {
      missing += unit * short;
    } else if (short > 0) {
      unpriced += short;
    }
  }
  var total = 0;
  for (final e in craftLeaves(planFor(root, 1)).entries) {
    total += (prices[e.key] ?? 0) * e.value;
  }
  return LegendaryDistance(
    itemId: root.itemId,
    item: root.item,
    missingCost: missing,
    totalValue: total,
    unpricedMissing: unpriced,
  );
}

/// every legendary of the recipe book the account does not have yet, the closest first: by what is still to buy, then by what the trading
/// post does not sell
final legendaryProximityProvider = FutureProvider.autoDispose<List<LegendaryDistance>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final book = await ref.watch(recipeBookProvider.future);
  final owned = await ref.watch(accountTotalsProvider.future);
  final candidates = [
    for (final e in book.byOutput.entries)
      if (e.value.any((r) => r.legendary)) e.key,
  ];
  final heads = await api.items(candidates);
  // the legendaries themselves, not the gifts and precursors on the way to them
  final roots = [
    for (final id in candidates)
      if (heads[id]?['rarity'] == 'Legendary' && (owned[id] ?? 0) == 0) id,
  ];
  final ids = <int>{};
  for (final id in roots) {
    ids.addAll(bookTreeIds(book, id));
  }
  final items = await api.items(ids);
  final trees = [for (final id in roots) buildFromBook(book, id, items)];
  final leafIds = <int>{};
  for (final t in trees) {
    leafIds.addAll(craftLeaves(planFor(t, 1)).keys);
  }
  final prices = await sellPrices(api, leafIds);
  final out = [for (final t in trees) distanceTo(t, owned, prices)]..sort((a, b) => a.missingCost != b.missingCost
      ? a.missingCost.compareTo(b.missingCost)
      : a.unpricedMissing.compareTo(b.unpricedMissing));
  return out;
});
