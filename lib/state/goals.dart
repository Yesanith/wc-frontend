import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account.dart';
import 'api.dart';
import 'crafting.dart';
import 'settings.dart';

/// something the player wants to have made: an item and how many
class Goal {
  const Goal(this.itemId, this.quantity);

  final int itemId;
  final int quantity;

  /// kept on the device as "itemId:quantity"
  String get stored => '$itemId:$quantity';

  static Goal? parse(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final id = int.tryParse(parts[0]);
    final count = int.tryParse(parts[1]);
    if (id == null || count == null || id <= 0 || count <= 0) return null;
    return Goal(id, count);
  }
}

/// the most goals kept, so the list stays something a person can read
const maxGoals = 30;

/// the most of one item a goal can ask for
const maxGoalQuantity = 999;

class GoalsNotifier extends Notifier<List<Goal>> {
  static const _key = 'goals';

  @override
  List<Goal> build() {
    final raw = ref.read(prefsProvider).getStringList(_key) ?? const [];
    final seen = <int>{};
    return [
      for (final line in raw)
        if (Goal.parse(line) case final goal? when seen.add(goal.itemId)) goal,
    ];
  }

  bool has(int itemId) => state.any((g) => g.itemId == itemId);

  /// a goal for an item that is already on the list asks for that many more
  Future<void> add(int itemId, int quantity) async {
    final more = quantity.clamp(1, maxGoalQuantity);
    if (has(itemId)) {
      await setQuantity(itemId, state.firstWhere((g) => g.itemId == itemId).quantity + more);
      return;
    }
    if (state.length >= maxGoals) return;
    await _save([...state, Goal(itemId, more)]);
  }

  Future<void> setQuantity(int itemId, int quantity) async {
    final count = quantity.clamp(1, maxGoalQuantity);
    await _save([for (final g in state) g.itemId == itemId ? Goal(itemId, count) : g]);
  }

  Future<void> remove(int itemId) => _save([
        for (final g in state)
          if (g.itemId != itemId) g
      ]);

  Future<void> clear() => _save(const []);

  Future<void> _save(List<Goal> goals) async {
    state = goals;
    await ref.read(prefsProvider).setStringList(_key, [for (final g in goals) g.stored]);
  }
}

final goalsProvider = NotifierProvider<GoalsNotifier, List<Goal>>(GoalsNotifier.new);

/// one material the goals need together
class ShoppingRow {
  const ShoppingRow({required this.itemId, required this.need, required this.have, required this.unitPrice});

  final int itemId;
  final int need;
  final int have;

  /// the lowest sell listing, 0 when the item has none
  final int unitPrice;

  int get missing => math.max(0, need - have);
  bool get done => have >= need;
  int get missingCost => unitPrice * missing;
}

/// what all the goals use up, as one list
class ShoppingList {
  const ShoppingList(this.rows);

  /// what is missing first, the dearest first, then what is already in hand
  final List<ShoppingRow> rows;

  int get missingCost => rows.fold(0, (sum, r) => sum + r.missingCost);

  /// the worth of what is owned and counts towards the goals
  int get ownedValue => rows.fold(0, (sum, r) => sum + r.unitPrice * math.min(r.have, r.need));

  /// materials still to get that have no trading post price, left out of the sums
  int get unpriced => rows.where((r) => !r.done && r.unitPrice == 0).length;

  bool get isEmpty => rows.isEmpty;
  bool get complete => rows.isNotEmpty && rows.every((r) => r.done);
}

/// the materials at the bottom of every plan, added up, set against what the account owns
ShoppingList buildShoppingList(List<CraftLine> plans, Map<int, int> owned, Map<int, int> prices) {
  final need = <int, int>{};
  for (final plan in plans) {
    craftLeaves(plan).forEach((id, count) => need[id] = (need[id] ?? 0) + count);
  }
  final rows = [
    for (final e in need.entries)
      ShoppingRow(itemId: e.key, need: e.value, have: owned[e.key] ?? 0, unitPrice: prices[e.key] ?? 0),
  ];
  rows.sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final byCost = b.missingCost.compareTo(a.missingCost);
    return byCost != 0 ? byCost : a.itemId.compareTo(b.itemId);
  });
  return ShoppingList(rows);
}

/// the crafting trees of the goals, in the order of the list. an item whose tree cannot be had is left out,
/// the others still count
final goalTreesProvider = FutureProvider.autoDispose<List<(Goal, CraftNode)>>((ref) async {
  final goals = ref.watch(goalsProvider);
  final trees = await Future.wait([
    for (final g in goals)
      ref.watch(craftTreeProvider(g.itemId).future).then<CraftNode?>((node) => node).catchError((_) => null),
  ]);
  return [
    for (var i = 0; i < goals.length; i++)
      if (trees[i] != null) (goals[i], trees[i]!),
  ];
});

/// the lowest sell listing of every item in every goal, fetched once for the whole list
final goalPricesProvider = FutureProvider.autoDispose<Map<int, int>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final trees = await ref.watch(goalTreesProvider.future);
  final ids = <int>{};
  for (final (_, node) in trees) {
    collectTreeIds(node, ids);
  }
  if (ids.isEmpty) return const {};
  return sellPrices(api, ids);
});

/// the plans of the goals from what the account owns, which is nothing for a visitor without a key
final goalPlansProvider = Provider.autoDispose<List<(Goal, CraftLine)>>((ref) {
  final trees = ref.watch(goalTreesProvider).valueOrNull ?? const [];
  final owned = ref.watch(accountTotalsProvider).valueOrNull ?? const <int, int>{};
  final plans = planGoals([for (final (goal, node) in trees) (node, goal.quantity)], owned);
  return [for (var i = 0; i < trees.length; i++) (trees[i].$1, plans[i])];
});
