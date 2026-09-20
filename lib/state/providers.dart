import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/gw2_api.dart';
import '../api/wiki_api.dart';
import '../data/collections.dart';
import '../services/cache.dart';
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

/// overridden in main() once the cache directory is ready
final diskCacheProvider = Provider<DiskCache?>((ref) => null);

final gw2ApiProvider = Provider<Gw2Api>((ref) {
  final lang = ref.watch(langProvider);
  return Gw2Api(
    ref.watch(apiKeyProvider).valueOrNull,
    lang: lang.apiLang,
    cache: ref.watch(diskCacheProvider),
  );
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

class TxRow {
  const TxRow(this.tx, this.item);
  final Json tx;
  final Json? item;
}

final transactionsProvider = FutureProvider.family<List<TxRow>, String>((ref, kind) async {
  final api = ref.watch(gw2ApiProvider);
  final txs = await api.transactions(kind);
  final items = await api.items(txs.map((t) => asInt(t['item_id'])));
  return [for (final t in txs) TxRow(t, items[asInt(t['item_id'])])];
});

class Delivery {
  const Delivery(this.coins, this.items);
  final int coins;
  final List<ItemSlot> items;
}

final deliveryProvider = FutureProvider<Delivery>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final raw = await api.delivery();
  final slots = ((raw['items'] as List?) ?? const []).whereType<Map>().toList();
  final items = await api.items(slots.map((e) => asInt(e['id'])));
  return Delivery(asInt(raw['coins']), [
    for (final e in slots) ItemSlot(asInt(e['id']), asInt(e['count']), items[asInt(e['id'])]),
  ]);
});

class GemRates {
  const GemRates(this.coinsFor100Gems, this.gemsFor100Gold);
  final int coinsFor100Gems;
  final int gemsFor100Gold;
}

final gemRatesProvider = FutureProvider<GemRates>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final coins = await api.coinsForGems(100);
  // 100 gold = 1,000,000 copper
  final gems = await api.gemsForCoins(1000000);
  return GemRates(coins, gems);
});

/// world bosses, daily crafts and map chests already done today.
/// needs the progression permission, empty when it is missing
final doneTodayProvider = FutureProvider.family<Set<String>, String>((ref, path) async {
  final api = ref.watch(gw2ApiProvider);
  try {
    return (await api.get('/account/$path') as List).map((e) => '$e').toSet();
  } catch (_) {
    return <String>{};
  }
});

class CollectionProgress {
  const CollectionProgress(this.unlocked, this.total);
  final int unlocked;
  final int total;

  double get ratio => total == 0 ? 0 : unlocked / total;
}

/// all ids of a static collection endpoint, kept on disk for a month
final collectionIdsProvider = FutureProvider.family<List<String>, String>((ref, key) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final kind = collectionKinds.firstWhere((k) => k.key == key);
  final name = 'collection_ids_${kind.key}';
  final cached = await cache?.read(name, maxAge: const Duration(days: 30));
  final cachedIds = cached?['ids'];
  if (cachedIds is List && cachedIds.isNotEmpty) return cachedIds.map((e) => '$e').toList();
  final ids = await api.idList(kind.staticPath);
  await cache?.write(name, {'ids': ids});
  return ids;
});

final collectionUnlockedProvider = FutureProvider.family<Set<String>, String>((ref, key) async {
  final api = ref.watch(gw2ApiProvider);
  final kind = collectionKinds.firstWhere((k) => k.key == key);
  return (await api.unlockedIds(kind.accountPath)).toSet();
});

final collectionProgressProvider = FutureProvider.family<CollectionProgress, String>((ref, key) async {
  final ids = ref.watch(collectionIdsProvider(key).future);
  final unlocked = ref.watch(collectionUnlockedProvider(key).future);
  final all = await ids;
  final owned = await unlocked;
  return CollectionProgress(owned.where(all.contains).length, all.length);
});

class CollectionEntry {
  const CollectionEntry(this.id, this.name, this.icon, this.unlocked);
  final String id;
  final String name;
  final String? icon;
  final bool unlocked;
}

/// every entry of a collection with its unlock state. details are cached
/// on disk because they only change with a patch
final collectionEntriesProvider = FutureProvider.family<List<CollectionEntry>, String>((ref, key) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);
  final kind = collectionKinds.firstWhere((k) => k.key == key);
  final idsFuture = ref.watch(collectionIdsProvider(key).future);
  final unlockedFuture = ref.watch(collectionUnlockedProvider(key).future);
  final ids = await idsFuture;
  final unlocked = await unlockedFuture;

  final name = 'collection_${kind.key}_${lang.apiLang}';
  var rows = <Json>[];
  final cached = await cache?.read(name, maxAge: const Duration(days: 30));
  final cachedRows = cached?['rows'];
  if (cachedRows is List && cachedRows.isNotEmpty) {
    rows = cachedRows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  } else {
    rows = await api.details(kind.staticPath, ids);
    await cache?.write(name, {'rows': rows});
  }

  final byId = {for (final r in rows) '${r['id']}': r};
  return [
    for (final id in ids)
      CollectionEntry(
        id,
        (byId[id]?['name'] as String?) ?? id.replaceAll('_', ' '),
        byId[id]?['icon'] as String?,
        unlocked.contains(id),
      ),
  ]..sort((a, b) => a.name.compareTo(b.name));
});

/// what the missing part of a goal would cost at current sell listings.
/// returns null while prices are still loading
final goalCostProvider = FutureProvider.family<int, String>((ref, goalId) async {
  final api = ref.watch(gw2ApiProvider);
  final goals = ref.watch(goalsProvider);
  final totalsFuture = ref.watch(accountTotalsProvider.future);
  Goal? goal;
  for (final g in goals) {
    if (g.id == goalId) goal = g;
  }
  if (goal == null || goal.items.isEmpty) return 0;
  final totals = await totalsFuture;
  final missing = <int, int>{};
  for (final item in goal.items) {
    final have = totals[item.itemId] ?? 0;
    if (have < item.need) missing[item.itemId] = item.need - have;
  }
  if (missing.isEmpty) return 0;
  final prices = await api.prices(missing.keys);
  var total = 0;
  for (final e in missing.entries) {
    final sells = prices[e.key]?['sells'];
    if (sells is Map) total += asInt(sells['unit_price']) * e.value;
  }
  return total;
});

class AchievementRow {
  const AchievementRow(this.id, this.detail, this.current, this.max, this.done);
  final int id;
  final Json? detail;
  final int current;
  final int max;
  final bool done;

  String get name => (detail?['name'] as String?) ?? 'Achievement #$id';
  int get points => asInt(detail?['point_cap']);
  double get ratio => max == 0 ? 0 : current / max;
}

/// achievements the account has started but not finished, most complete first
final achievementsProvider = FutureProvider<List<AchievementRow>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final rows = await api.accountAchievements();
  final started = [
    for (final r in rows)
      if (r['done'] != true && asInt(r['current']) > 0) r,
  ];
  started.sort((a, b) {
    final ra = asInt(a['max']) == 0 ? 0.0 : asInt(a['current']) / asInt(a['max']);
    final rb = asInt(b['max']) == 0 ? 0.0 : asInt(b['current']) / asInt(b['max']);
    return rb.compareTo(ra);
  });
  final top = started.take(150).toList();
  final details = await api.achievements(top.map((r) => asInt(r['id'])));
  return [
    for (final r in top)
      AchievementRow(
        asInt(r['id']),
        details[asInt(r['id'])],
        asInt(r['current']),
        asInt(r['max']),
        r['done'] == true,
      ),
  ];
});

final achievementsDoneProvider = FutureProvider<int>((ref) async {
  final rows = await ref.watch(gw2ApiProvider).accountAchievements();
  return rows.where((r) => r['done'] == true).length;
});

class MasteryRow {
  const MasteryRow(this.id, this.detail, this.level);
  final int id;
  final Json? detail;

  /// how many levels of this track are done
  final int level;

  String get name => (detail?['name'] as String?) ?? 'Mastery #$id';
  String get region => (detail?['region'] as String?) ?? '';
  int get total => ((detail?['levels'] as List?) ?? const []).length;
}

final masteriesProvider = FutureProvider<List<MasteryRow>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final owned = await api.accountMasteries();
  final byId = {for (final m in owned) asInt(m['id']): asInt(m['level'])};
  final details = await api.masteries(byId.keys);
  final rows = [
    for (final e in byId.entries) MasteryRow(e.key, details[e.key], e.value + 1),
  ];
  rows.sort((a, b) => '${a.region}${a.name}'.compareTo('${b.region}${b.name}'));
  return rows;
});

final masteryPointsProvider = FutureProvider<List<Json>>((ref) async {
  final raw = await ref.watch(gw2ApiProvider).masteryPoints();
  return ((raw['totals'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
});

final armoryProvider = FutureProvider<List<ItemSlot>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final rows = await api.legendaryArmory();
  final items = await api.items(rows.map((r) => asInt(r['id'])));
  final out = [
    for (final r in rows)
      ItemSlot(asInt(r['id']), asInt(r['count']), items[asInt(r['id'])]),
  ];
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
});

final buildStorageProvider = FutureProvider<List<Json>>((ref) async {
  return ref.watch(gw2ApiProvider).buildStorage();
});
