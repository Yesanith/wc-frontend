import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/gw2_api.dart';
import '../api/wiki_api.dart';
import '../util.dart';
import 'settings.dart';

final storageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

class ApiKeyNotifier extends AsyncNotifier<String?> {
  static const _storageKey = 'gw2_api_key';

  @override
  Future<String?> build() => ref.read(storageProvider).read(key: _storageKey);

  Future<void> save(String key) async {
    await ref.read(storageProvider).write(key: _storageKey, value: key);
    state = AsyncData(key);
  }

  Future<void> clear() async {
    await ref.read(storageProvider).delete(key: _storageKey);
    state = const AsyncData(null);
  }
}

final apiKeyProvider = AsyncNotifierProvider<ApiKeyNotifier, String?>(ApiKeyNotifier.new);

final gw2ApiProvider = Provider<Gw2Api>((ref) {
  final lang = ref.watch(langProvider);
  return Gw2Api(ref.watch(apiKeyProvider).valueOrNull, lang: lang.apiLang);
});

final wikiApiProvider = Provider<WikiApi>((ref) => WikiApi(ref.watch(langProvider).wikiBase));

final tokenInfoProvider = FutureProvider<Json>((ref) => ref.watch(gw2ApiProvider).tokenInfo());

final accountProvider = FutureProvider<Json>((ref) => ref.watch(gw2ApiProvider).account());

final vaultProvider = FutureProvider<Json>((ref) => ref.watch(gw2ApiProvider).vaultDaily());

final charactersProvider = FutureProvider<List<Json>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final list = await api.characters();
  list.sort((a, b) => '${b['last_modified'] ?? ''}'.compareTo('${a['last_modified'] ?? ''}'));
  return list;
});

Json? characterByName(List<Json> chars, String name) {
  for (final c in chars) {
    if (c['name'] == name) return c;
  }
  return null;
}

List<Json> activeEquipment(Json c) {
  final eq = (c['equipment'] as List?) ?? const [];
  final active = c['active_equipment_tab'];
  return [
    for (final e in eq)
      if (e is Map &&
          (active == null || e['tabs'] is! List || (e['tabs'] as List).contains(active)))
        Map<String, dynamic>.from(e),
  ];
}

List<Json?> bagSlots(Json c) {
  final out = <Json?>[];
  for (final bag in (c['bags'] as List?) ?? const []) {
    if (bag is! Map) continue;
    for (final s in (bag['inventory'] as List?) ?? const []) {
      out.add(s is Map ? Map<String, dynamic>.from(s) : null);
    }
  }
  return out;
}

Json? activeBuild(Json c) {
  for (final t in (c['build_tabs'] as List?) ?? const []) {
    if (t is Map && t['is_active'] == true && t['build'] is Map) {
      return Map<String, dynamic>.from(t['build'] as Map);
    }
  }
  return null;
}

final characterItemsProvider = FutureProvider.family<Map<int, Json>, String>((ref, name) async {
  final api = ref.watch(gw2ApiProvider);
  final chars = await ref.watch(charactersProvider.future);
  final c = characterByName(chars, name);
  if (c == null) return <int, Json>{};
  final ids = <int>{
    for (final e in activeEquipment(c)) asInt(e['id']),
    for (final s in bagSlots(c))
      if (s != null) asInt(s['id']),
  };
  return api.items(ids);
});

final characterSpecsProvider = FutureProvider.family<List<Json>, String>((ref, name) async {
  final api = ref.watch(gw2ApiProvider);
  final chars = await ref.watch(charactersProvider.future);
  final c = characterByName(chars, name);
  final build = c == null ? null : activeBuild(c);
  if (build == null) return <Json>[];
  final ids = <int>[
    for (final s in (build['specializations'] as List?) ?? const [])
      if (s is Map && s['id'] != null) asInt(s['id']),
  ];
  final specs = await api.specializations(ids);
  return [
    for (final id in ids)
      if (specs[id] != null) specs[id]!,
  ];
});

final walletProvider = FutureProvider<List<WalletEntry>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
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
  final api = ref.watch(gw2ApiProvider);
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

final materialsProvider = FutureProvider<List<ItemSlot>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final raw = await api.materials();
  final owned = raw.where((m) => asInt(m['count']) > 0).toList()
    ..sort((a, b) => asInt(b['count']).compareTo(asInt(a['count'])));
  final top = owned.take(80).toList();
  final items = await api.items(top.map((m) => asInt(m['id'])));
  return [
    for (final m in top) ItemSlot(asInt(m['id']), asInt(m['count']), items[asInt(m['id'])]),
  ];
});

final itemProvider = FutureProvider.family<Json?, int>((ref, id) async {
  final items = await ref.watch(gw2ApiProvider).items([id]);
  return items[id];
});

final priceProvider = FutureProvider.family<Json?, int>((ref, id) async {
  final prices = await ref.watch(gw2ApiProvider).prices([id]);
  return prices[id];
});

class WatchedItem {
  const WatchedItem(this.id, this.item, this.price);
  final int id;
  final Json? item;
  final Json? price;
}

final watchlistPricesProvider = FutureProvider<List<WatchedItem>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final ids = ref.watch(watchlistProvider);
  if (ids.isEmpty) return const [];
  final items = await api.items(ids);
  final prices = await api.prices(ids);
  return [for (final id in ids) WatchedItem(id, items[id], prices[id])];
});

/// how many of each item the account owns: bank + material storage +
/// shared slots + every character's bags. used by goals and the tp screen
final accountTotalsProvider = FutureProvider<Map<int, int>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
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
  ]);
  for (final list in results) {
    for (final slot in list) {
      add(slot);
    }
  }
  final chars = await charsFuture;
  for (final c in chars) {
    for (final slot in bagSlots(c)) {
      add(slot);
    }
  }
  return totals;
});

final goalItemsProvider = FutureProvider<Map<int, Json>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final goals = ref.watch(goalsProvider);
  final ids = {for (final g in goals) for (final i in g.items) i.itemId};
  if (ids.isEmpty) return const {};
  return api.items(ids);
});
