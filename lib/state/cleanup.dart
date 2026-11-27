import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'api.dart';
import 'characters.dart';

/// what to do with a stack: sell it to a merchant, sell it on the trading post, salvage it, or put it in material storage
enum CleanupAction { junk, sell, salvage, deposit }

/// a stack the advice is about: the item, how many, and where it lies (the bank, the shared slots, or a character's bags)
class CleanupStack {
  const CleanupStack(this.slot, this.where);

  final ItemSlot slot;

  /// null for the bank, '' for the shared slots, else the character's name
  final String? where;
}

class CleanupEntry {
  const CleanupEntry(this.stack, this.action, this.value, {this.ectos = 0});

  final CleanupStack stack;
  final CleanupAction action;

  /// what it brings in copper: what a merchant pays, what the trading post pays at once after its fees, or what the ectoplasm of
  /// salvaging is worth. nothing for a deposit
  final int value;

  /// the ectoplasm salvaging is expected to give
  final double ectos;
}

/// the plan for the account's stacks, each action's in the order of what it brings
class CleanupPlan {
  const CleanupPlan(this.entries);

  final List<CleanupEntry> entries;

  List<CleanupEntry> of(CleanupAction a) => [
        for (final e in entries)
          if (e.action == a) e
      ]..sort((x, y) => y.value.compareTo(x.value));

  int valueOf(CleanupAction a) => of(a).fold(0, (n, e) => n + e.value);
  double get ectos => entries.fold(0.0, (n, e) => n + e.ectos);
  bool get isEmpty => entries.isEmpty;
}

/// the ectoplasm a rare weapon or piece of armour of level 68 or more gives on average with a master's or a mystic kit
const ectosPerRare = 0.875;
const ectoplasmId = 19721;

/// the trading post keeps 15 % of a sale: 5 % to list, 10 % when it sells
int afterFees(int copper) => copper - (copper * 0.15).ceil();

const _gear = {'Weapon', 'Armor', 'Trinket', 'Back'};
const _sellable = {..._gear, 'UpgradeComponent'};
const _kept = {'Ascended', 'Legendary'};

/// what to do with each stack. [buyPrices] is what the trading post pays for each item at once (its highest buy order), [ecto] that of
/// a glob of ectoplasm. bound items, ascended and legendary ones are kept and not listed
CleanupPlan planCleanup(Iterable<CleanupStack> stacks, Map<int, int> buyPrices, int ecto) {
  final out = <CleanupEntry>[];
  for (final st in stacks) {
    final item = st.slot.item;
    if (item == null || st.slot.count <= 0) continue;
    final rarity = '${item['rarity'] ?? ''}';
    final type = '${item['type'] ?? ''}';
    final flags = {for (final f in (item['flags'] as List?) ?? const []) '$f'};
    final count = st.slot.count;
    if (rarity == 'Junk') {
      if (!flags.contains('NoSell')) out.add(CleanupEntry(st, CleanupAction.junk, asInt(item['vendor_value']) * count));
      continue;
    }
    // a material in the bank or the bags has a place of its own, which every character reaches
    if (type == 'CraftingMaterial') {
      out.add(CleanupEntry(st, CleanupAction.deposit, 0));
      continue;
    }
    final bound = st.slot.binding != null || flags.contains('AccountBound') || flags.contains('SoulbindOnAcquire');
    if (bound || _kept.contains(rarity) || !_sellable.contains(type)) continue;
    final buy = buyPrices[st.slot.id] ?? 0;
    final sale = buy > 0 ? afterFees(buy) * count : 0;
    final salvageable = rarity == 'Rare' &&
        (type == 'Weapon' || type == 'Armor') &&
        asInt(item['level']) >= 68 &&
        !flags.contains('NoSalvage');
    if (salvageable && ecto > 0) {
      final ectos = ectosPerRare * count;
      final worth = (afterFees(ecto) * ectos).round();
      if (worth >= sale) {
        out.add(CleanupEntry(st, CleanupAction.salvage, worth, ectos: ectos));
        continue;
      }
    }
    if (sale > 0) out.add(CleanupEntry(st, CleanupAction.sell, sale));
  }
  return CleanupPlan(out);
}

/// the plan for the account: the bank, the shared slots and every character's bags, with the prices of the trading post
final cleanupProvider = FutureProvider.autoDispose<CleanupPlan>((ref) async {
  final api = accountApi(ref);
  final charsFuture = ref.watch(charactersProvider.future);
  final bank = await api.bank();
  final shared = await api.sharedInventory().catchError((_) => <Json?>[]);
  final chars = await charsFuture;
  final raw = <(Json, String?)>[
    for (final s in bank)
      if (s != null) (s, null),
    for (final s in shared)
      if (s != null) (s, ''),
    for (final c in chars)
      for (final s in bagSlots(c))
        if (s != null) (s, '${c['name'] ?? ''}'),
  ];
  final ids = {for (final (s, _) in raw) asInt(s['id'])}..remove(0);
  final items = await api.items(ids);
  final stacks = [
    for (final (s, where) in raw)
      CleanupStack(
        ItemSlot(asInt(s['id']), s['count'] == null ? 1 : asInt(s['count']), items[asInt(s['id'])],
            binding: s['binding'] as String?, boundTo: s['bound_to'] as String?),
        where,
      ),
  ];
  // only what could be sold or salvaged is priced
  final priced = {
    for (final st in stacks)
      if (_sellable.contains(st.slot.type) && st.slot.binding == null) st.slot.id,
    ectoplasmId,
  };
  final prices = await api.prices(priced).catchError((_) => <int, Json>{});
  int buyOf(Json p) => p['buys'] is Map ? asInt((p['buys'] as Map)['unit_price']) : 0;
  final buys = {for (final e in prices.entries) e.key: buyOf(e.value)};
  return planCleanup(stacks, buys, buys[ectoplasmId] ?? 0);
});
