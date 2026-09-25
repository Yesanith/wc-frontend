import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'api.dart';
import 'characters.dart';
import 'reference.dart';

final accountProvider = FutureProvider<Json>((ref) => accountApi(ref).account());

/// track is daily, weekly or special
final vaultTrackProvider =
    FutureProvider.family<Json, String>((ref, track) => accountApi(ref).vault(track));

final walletProvider = FutureProvider<List<WalletEntry>>((ref) async {
  final api = accountApi(ref);
  final raw = await api.wallet();
  final cur = await api.currencies(raw.map((e) => asInt(e['id'])));
  final list = <WalletEntry>[];
  for (final e in raw) {
    final id = asInt(e['id']);
    final c = cur[id];
    list.add(WalletEntry(
      id,
      asInt(e['value']),
      (c?['name'] as String?) ?? 'Currency #$id',
      c?['icon'] as String?,
      c == null ? 9999 : asInt(c['order']),
    ));
  }
  list.sort((a, b) => a.order.compareTo(b.order));
  return list;
});

final bankProvider = FutureProvider<List<ItemSlot?>>((ref) async {
  final api = accountApi(ref);
  final raw = await api.bank();
  final items = await api.items(<int>[
    for (final s in raw)
      if (s != null) asInt(s['id']),
  ]);
  return <ItemSlot?>[
    for (final s in raw)
      s == null ? null : ItemSlot(asInt(s['id']), asInt(s['count']), items[asInt(s['id'])]),
  ];
});

/// how many of each item the account owns: bank + material storage +
/// shared slots + every character's bags. shown as "you own" on item,
/// trading post and crafting screens
final accountTotalsProvider = FutureProvider<Map<int, int>>((ref) async {
  final api = accountApi(ref);
  final charsFuture = ref.watch(charactersProvider.future);
  final totals = <int, int>{};
  void add(Json? slot) {
    if (slot == null) return;
    final id = asInt(slot['id']);
    if (id <= 0) return;
    totals[id] = (totals[id] ?? 0) + (slot['count'] == null ? 1 : asInt(slot['count']));
  }

  final results = await Future.wait([
    api.bank(),
    api.materials(),
    api.sharedInventory().catchError((_) => <Json?>[]),
    // legendaries in the armory count as owned too, the api needs unlocks for it
    api.legendaryArmory().catchError((_) => <Json>[]),
  ]);
  for (final list in results) {
    for (final slot in list) {
      add(slot);
    }
  }
  // armory legendaries show up in equipment as well, count them only once
  final armory = {for (final row in results[3]) if (row != null) asInt(row['id'])};
  final chars = await charsFuture;
  for (final c in chars) {
    for (final slot in bagSlots(c)) {
      add(slot);
    }
    // gear being worn, every entry is one physical item no matter how many
    // templates use it
    for (final piece in (c['equipment'] as List?) ?? const []) {
      if (piece is Map && !armory.contains(asInt(piece['id']))) add({'id': piece['id'], 'count': 1});
    }
  }
  return totals;
});


// -------------------------------------------------------------------------
// extras

/// recipe ids this account has learned
final learnedRecipesProvider = FutureProvider<Set<int>>((ref) async => (await accountApi(ref).learnedRecipes()).toSet());

/// {'luck': n}
final accountLuckProvider = FutureProvider<Map<String, int>>((ref) => accountApi(ref).accountCounters('/account/luck'));

/// fractal augmentations and similar account wide counters
final accountProgressionProvider =
    FutureProvider<Map<String, int>>((ref) => accountApi(ref).accountCounters('/account/progression'));

final accountWvwProvider = FutureProvider<Json>((ref) => accountApi(ref).accountWvw());

class MaterialGroup {
  const MaterialGroup(this.name, this.slots);
  final String name;
  final List<ItemSlot> slots;
}

/// material storage grouped by the game's categories, every owned stack
final materialGroupsProvider = FutureProvider<List<MaterialGroup>>((ref) async {
  final api = accountApi(ref);
  final categoriesFuture = ref.watch(materialCategoriesProvider.future);
  final raw = await api.materials();
  final owned = raw.where((m) => asInt(m['count']) > 0).toList();
  final items = await api.items(owned.map((m) => asInt(m['id'])));
  final categories = await categoriesFuture;

  final byCategory = <int, List<ItemSlot>>{};
  for (final m in owned) {
    byCategory
        .putIfAbsent(asInt(m['category']), () => [])
        .add(ItemSlot(asInt(m['id']), asInt(m['count']), items[asInt(m['id'])]));
  }
  final groups = <MaterialGroup>[];
  for (final c in categories) {
    final slots = byCategory.remove(asInt(c['id']));
    if (slots == null || slots.isEmpty) continue;
    slots.sort((a, b) => b.count.compareTo(a.count));
    groups.add(MaterialGroup('${c['name'] ?? ''}', slots));
  }
  // anything in a category the reference data does not know yet
  for (final slots in byCategory.values) {
    slots.sort((a, b) => b.count.compareTo(a.count));
    groups.add(MaterialGroup('?', slots));
  }
  return groups;
});
