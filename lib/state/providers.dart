import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/gw2_api.dart';
import '../api/wiki_api.dart';
import '../data/collections.dart';
import '../services/cache.dart';
import '../util.dart';
import 'settings.dart';

final storageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

/// one saved api key with the account name it belongs to
class StoredKey {
  const StoredKey(this.name, this.key);
  final String name;
  final String key;

  Map<String, dynamic> toJson() => {'name': name, 'key': key};

  static StoredKey fromJson(Map<String, dynamic> j) => StoredKey('${j['name'] ?? ''}', '${j['key'] ?? ''}');
}

/// every key the user added, in the order they were added
class KeysNotifier extends AsyncNotifier<List<StoredKey>> {
  static const _storageKey = 'gw2_api_keys';
  static const _legacyKey = 'gw2_api_key';

  @override
  Future<List<StoredKey>> build() async {
    final storage = ref.read(storageProvider);
    final raw = await storage.read(key: _storageKey);
    if (raw != null) {
      try {
        return (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => StoredKey.fromJson(Map<String, dynamic>.from(e)))
            .where((k) => k.key.isNotEmpty)
            .toList();
      } catch (_) {
        return const [];
      }
    }
    // migrate the single key older versions stored
    final legacy = await storage.read(key: _legacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      final migrated = [StoredKey('', legacy)];
      await _persist(migrated);
      await storage.delete(key: _legacyKey);
      return migrated;
    }
    return const [];
  }

  Future<void> _persist(List<StoredKey> keys) async {
    await ref
        .read(storageProvider)
        .write(key: _storageKey, value: jsonEncode(keys.map((k) => k.toJson()).toList()));
  }

  Future<void> add(String key, String name) async {
    final current = state.valueOrNull ?? const <StoredKey>[];
    final next = [...current.where((k) => k.key != key), StoredKey(name, key)];
    await _persist(next);
    state = AsyncData(next);
    await ref.read(activeKeyProvider.notifier).set(next.length - 1);
  }

  Future<void> removeAt(int index) async {
    final current = [...(state.valueOrNull ?? const <StoredKey>[])];
    if (index < 0 || index >= current.length) return;
    current.removeAt(index);
    await _persist(current);
    state = AsyncData(current);
    if (ref.read(activeKeyProvider) >= current.length) {
      await ref.read(activeKeyProvider.notifier).set(current.isEmpty ? 0 : current.length - 1);
    }
  }
}

final keysProvider = AsyncNotifierProvider<KeysNotifier, List<StoredKey>>(KeysNotifier.new);

class ActiveKeyNotifier extends Notifier<int> {
  static const _key = 'active_key';

  @override
  int build() => ref.read(prefsProvider).getInt(_key) ?? 0;

  Future<void> set(int index) async {
    state = index;
    await ref.read(prefsProvider).setInt(_key, index);
  }
}

final activeKeyProvider = NotifierProvider<ActiveKeyNotifier, int>(ActiveKeyNotifier.new);

/// the key every request uses, derived from the list and the active index
final apiKeyProvider = Provider<AsyncValue<String?>>((ref) {
  final keys = ref.watch(keysProvider);
  final index = ref.watch(activeKeyProvider);
  return keys.whenData((list) {
    if (list.isEmpty) return null;
    final safe = index < 0 || index >= list.length ? list.length - 1 : index;
    return list[safe].key;
  });
});

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

/// track is daily, weekly or special
final vaultTrackProvider =
    FutureProvider.family<Json, String>((ref, track) => ref.watch(gw2ApiProvider).vault(track));

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

/// stored equipment templates of a character
List<Json> equipmentTabs(Json c) => [
      for (final t in (c['equipment_tabs'] as List?) ?? const [])
        if (t is Map) Map<String, dynamic>.from(t),
    ];

/// equipment of one template, or of the active one when [tab] is null
List<Json> equipmentForTab(Json c, int? tab) {
  final eq = (c['equipment'] as List?) ?? const [];
  final wanted = tab ?? c['active_equipment_tab'];
  return [
    for (final e in eq)
      if (e is Map &&
          (wanted == null || e['tabs'] is! List || (e['tabs'] as List).contains(wanted)))
        Map<String, dynamic>.from(e),
  ];
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

  // the game string table returns "((208738))" for entries that have no
  // name yet, usually unreleased content
  final placeholder = RegExp(r'^\(\(\d+\)\)$');
  final byId = {for (final r in rows) '${r['id']}': r};

  // mount types carry no icon, so borrow the one of their default skin
  if (kind.key == 'mounts') {
    final skinIds = [
      for (final r in rows)
        if (r['default_skin'] != null) '${asInt(r['default_skin'])}',
    ];
    if (skinIds.isNotEmpty) {
      try {
        final skins = await api.details('/mounts/skins', skinIds);
        final iconBySkin = {for (final skin in skins) asInt(skin['id']): skin['icon']};
        for (final row in rows) {
          row['icon'] ??= iconBySkin[asInt(row['default_skin'])];
        }
      } catch (_) {
        // no icons is better than no list
      }
    }
  }
  final entries = <CollectionEntry>[];
  for (final id in ids) {
    var name = (byId[id]?['name'] as String?) ?? (byId[id]?['hint'] as String?) ?? titleCase(id);
    if (name.isEmpty || placeholder.hasMatch(name)) name = '';
    entries.add(CollectionEntry(id, name, byId[id]?['icon'] as String?, unlocked.contains(id)));
  }
  // unnamed entries go last instead of bunching up at the top
  entries.sort((a, b) {
    if (a.name.isEmpty != b.name.isEmpty) return a.name.isEmpty ? 1 : -1;
    return a.name.compareTo(b.name);
  });
  return entries;
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

/// everything a build refers to: both trait rows of each specialization,
/// land and water skills, chained and toolbelt skills, pets and legends
class BuildDetail {
  const BuildDetail({
    required this.specs,
    required this.traits,
    required this.skills,
    required this.pets,
    required this.legends,
    required this.profession,
  });

  final Map<int, Json> specs;
  final Map<int, Json> traits;
  final Map<int, Json> skills;
  final Map<int, Json> pets;
  final List<Json> legends;
  final Json? profession;
}

List<int> intList(dynamic raw) => [
      for (final v in (raw as List?) ?? const [])
        if (v != null) asInt(v),
    ];

/// pets come as a list on stored builds and as {terrestrial, aquatic} on
/// characters, so accept both shapes
List<int> petIds(Json build, String water) {
  final pets = build['pets'];
  if (pets is List) return intList(pets);
  if (pets is Map) return intList(pets[water]);
  return const [];
}

Json? skillSet(Json build, {required bool aquatic}) {
  final raw = build[aquatic ? 'aquatic_skills' : 'skills'];
  return raw is Map ? Map<String, dynamic>.from(raw) : null;
}

List<int> skillIdsOf(Json? set) {
  if (set == null) return const [];
  return [
    asInt(set['heal']),
    ...intList(set['utilities']),
    asInt(set['elite']),
  ].where((id) => id > 0).toList();
}

final buildDetailProvider = FutureProvider.family<BuildDetail, String>((ref, encoded) async {
  final api = ref.watch(gw2ApiProvider);
  final build = Map<String, dynamic>.from(jsonDecode(encoded) as Map);

  final specIds = <int>[];
  for (final spec in (build['specializations'] as List?) ?? const []) {
    if (spec is Map && spec['id'] != null) specIds.add(asInt(spec['id']));
  }
  final specs = await api.specializations(specIds);

  // every trait of those lines, not just the chosen ones
  final traitIds = <int>{};
  for (final spec in specs.values) {
    traitIds.addAll(intList(spec['major_traits']));
    traitIds.addAll(intList(spec['minor_traits']));
  }
  final traits = await api.traits(traitIds);

  final legendIds = [
    for (final l in (build['legends'] as List?) ?? const [])
      if (l != null) '$l',
  ];
  final legends = legendIds.isEmpty ? <Json>[] : await api.legends(legendIds);

  final skillIds = <int>{
    ...skillIdsOf(skillSet(build, aquatic: false)),
    ...skillIdsOf(skillSet(build, aquatic: true)),
  };
  for (final legend in legends) {
    skillIds.addAll([asInt(legend['swap']), asInt(legend['heal']), asInt(legend['elite'])]);
    skillIds.addAll(intList(legend['utilities']));
  }
  skillIds.removeWhere((id) => id <= 0);
  var skills = await api.skills(skillIds);

  // a second pass for toolbelt skills and chained attacks
  final extra = <int>{};
  for (final skill in skills.values) {
    final toolbelt = asInt(skill['toolbelt_skill']);
    if (toolbelt > 0) extra.add(toolbelt);
    final chain = asInt(skill['next_chain']);
    if (chain > 0) extra.add(chain);
  }
  extra.removeWhere(skills.containsKey);
  if (extra.isNotEmpty) {
    skills = {...skills, ...await api.skills(extra)};
  }

  final pets = <int>{...petIds(build, 'terrestrial'), ...petIds(build, 'aquatic')};
  final professionName = '${build['profession'] ?? ''}';
  Json? profession;
  if (professionName.isNotEmpty) {
    try {
      profession = await api.profession(professionName);
    } catch (_) {
      profession = null;
    }
  }

  return BuildDetail(
    specs: specs,
    traits: traits,
    skills: skills,
    pets: pets.isEmpty ? const {} : await api.pets(pets),
    legends: legends,
    profession: profession,
  );
});

final skillProvider = FutureProvider.family<Json?, int>((ref, id) async {
  final skills = await ref.watch(gw2ApiProvider).skills([id]);
  return skills[id];
});

class DailyProgress {
  const DailyProgress(this.done, this.total);
  final int done;
  final int total;
}

/// daily crafts and map chests: how many of today's are already collected
final dailyProgressProvider = FutureProvider.family<DailyProgress, String>((ref, path) async {
  final api = ref.watch(gw2ApiProvider);
  final all = await api.dailyAll(path);
  try {
    final done = await api.dailyDone(path);
    return DailyProgress(done.where(all.contains).length, all.length);
  } catch (_) {
    return DailyProgress(0, all.length);
  }
});

class RaidEncounter {
  const RaidEncounter(this.id, this.type, this.done);
  final String id;
  final String type;
  final bool done;

  String get label => titleCase(id);
}

class RaidWing {
  const RaidWing(this.id, this.encounters);
  final String id;
  final List<RaidEncounter> encounters;

  String get label => titleCase(id);
  int get done => encounters.where((e) => e.done).length;
}

/// raid wings with this week's clears marked
final raidsProvider = FutureProvider<List<RaidWing>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final wings = await api.raidWings();
  Set<String> cleared;
  try {
    cleared = (await api.accountRaids()).toSet();
  } catch (_) {
    cleared = <String>{};
  }
  final out = <RaidWing>[];
  for (final raid in wings) {
    for (final wing in (raid['wings'] as List?) ?? const []) {
      if (wing is! Map) continue;
      final encounters = <RaidEncounter>[];
      for (final event in (wing['events'] as List?) ?? const []) {
        if (event is! Map) continue;
        final id = '${event['id']}';
        encounters.add(RaidEncounter(id, '${event['type'] ?? ''}', cleared.contains(id)));
      }
      out.add(RaidWing('${wing['id']}', encounters));
    }
  }
  return out;
});

class DungeonPath {
  const DungeonPath(this.id, this.type, this.done);
  final String id;
  final String type;
  final bool done;
}

class Dungeon {
  const Dungeon(this.id, this.paths);
  final String id;
  final List<DungeonPath> paths;

  String get label => titleCase(id);
  int get done => paths.where((p) => p.done).length;
}

/// dungeon paths, reset daily
final dungeonsProvider = FutureProvider<List<Dungeon>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final all = await api.dungeons();
  Set<String> cleared;
  try {
    cleared = (await api.accountDungeons()).toSet();
  } catch (_) {
    cleared = <String>{};
  }
  return [
    for (final d in all)
      Dungeon('${d['id']}', [
        for (final p in (d['paths'] as List?) ?? const [])
          if (p is Map)
            DungeonPath('${p['id']}', '${p['type'] ?? ''}', cleared.contains('${p['id']}')),
      ]),
  ];
});

final pvpStatsProvider = FutureProvider<Json>((ref) => ref.watch(gw2ApiProvider).pvpStats());

class TradeStats {
  const TradeStats(this.soldValue, this.boughtValue, this.soldCount, this.boughtCount, this.topSold);

  /// what sales brought in after the 15% trading post cut
  final int soldValue;
  final int boughtValue;
  final int soldCount;
  final int boughtCount;
  final List<MapEntry<String, int>> topSold;

  int get net => soldValue - boughtValue;
}

/// rough profit and loss over the 90 days the api keeps
final tradeStatsProvider = FutureProvider<TradeStats>((ref) async {
  final sells = await ref.watch(transactionsProvider('history/sells').future);
  final buys = await ref.watch(transactionsProvider('history/buys').future);

  var soldValue = 0;
  var soldCount = 0;
  final perItem = <String, int>{};
  for (final row in sells) {
    final value = asInt(row.tx['price']) * asInt(row.tx['quantity']);
    soldValue += (value * 0.85).floor();
    soldCount += asInt(row.tx['quantity']);
    final name = (row.item?['name'] as String?) ?? 'Item #${row.tx['item_id']}';
    perItem[name] = (perItem[name] ?? 0) + (value * 0.85).floor();
  }
  var boughtValue = 0;
  var boughtCount = 0;
  for (final row in buys) {
    boughtValue += asInt(row.tx['price']) * asInt(row.tx['quantity']);
    boughtCount += asInt(row.tx['quantity']);
  }
  final top = perItem.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return TradeStats(soldValue, boughtValue, soldCount, boughtCount, top.take(8).toList());
});

/// one step of a crafting tree, independent of how many you want to make.
/// [perRun] is how many the parent recipe needs for a single run of itself
class CraftNode {
  const CraftNode({
    required this.itemId,
    required this.item,
    required this.perRun,
    required this.outputCount,
    required this.children,
    required this.disciplines,
  });

  final int itemId;
  final Json? item;
  final int perRun;

  /// how many the recipe makes in one craft
  final int outputCount;
  final List<CraftNode> children;
  final List<String> disciplines;

  bool get isLeaf => children.isEmpty;
  String get name => (item?['name'] as String?) ?? 'Item #$itemId';
}

/// the same tree with real amounts filled in for a given quantity
class CraftLine {
  const CraftLine(this.node, this.count, this.children);

  final CraftNode node;
  final int count;
  final List<CraftLine> children;

  bool get isLeaf => children.isEmpty;
  int get itemId => node.itemId;
  String get name => node.name;
}

/// scaling happens on device, so changing the quantity never refetches
CraftLine planFor(CraftNode node, int count) {
  final runs = node.outputCount <= 0 ? count : (count / node.outputCount).ceil();
  return CraftLine(
    node,
    count,
    [for (final child in node.children) planFor(child, child.perRun * runs)],
  );
}

/// keyed by item id only
final craftTreeProvider = FutureProvider.family<CraftNode, int>((ref, rootId) async {
  final api = ref.watch(gw2ApiProvider);

  Future<CraftNode> expand(int itemId, int perRun, Set<int> seen, int depth) async {
    final items = await api.items([itemId]);
    final item = items[itemId];
    CraftNode leaf() => CraftNode(
          itemId: itemId,
          item: item,
          perRun: perRun,
          outputCount: 1,
          children: const [],
          disciplines: const [],
        );
    if (depth >= 6 || seen.contains(itemId)) return leaf();

    final recipeIds = await api.recipesForOutput(itemId);
    if (recipeIds.isEmpty) return leaf();
    final recipes = await api.recipes(recipeIds);
    final recipe = recipes[recipeIds.first];
    if (recipe == null) return leaf();

    final output = asInt(recipe['output_item_count']);
    final children = <CraftNode>[];
    for (final ingredient in (recipe['ingredients'] as List?) ?? const []) {
      if (ingredient is! Map) continue;
      final id = asInt(ingredient['item_id'] ?? ingredient['id']);
      if (id <= 0) continue;
      children.add(await expand(id, asInt(ingredient['count']), {...seen, itemId}, depth + 1));
    }
    return CraftNode(
      itemId: itemId,
      item: item,
      perRun: perRun,
      outputCount: output <= 0 ? 1 : output,
      children: children,
      disciplines: [for (final d in (recipe['disciplines'] as List?) ?? const []) '$d'],
    );
  }

  return expand(rootId, 1, <int>{}, 0);
});

/// everything at the bottom of a plan, with quantities summed
Map<int, int> craftLeaves(CraftLine line) {
  final out = <int, int>{};
  void walk(CraftLine l) {
    if (l.isLeaf) {
      out[l.itemId] = (out[l.itemId] ?? 0) + l.count;
      return;
    }
    for (final child in l.children) {
      walk(child);
    }
  }

  for (final child in line.children) {
    walk(child);
  }
  return out;
}

/// sell listing price per unit for every item in the tree, fetched once
final craftPricesProvider = FutureProvider.family<Map<int, int>, int>((ref, rootId) async {
  final api = ref.watch(gw2ApiProvider);
  final root = await ref.watch(craftTreeProvider(rootId).future);
  final ids = <int>{};
  void collect(CraftNode n) {
    ids.add(n.itemId);
    for (final child in n.children) {
      collect(child);
    }
  }

  collect(root);
  final prices = await api.prices(ids);
  return {
    for (final e in prices.entries)
      if (e.value['sells'] is Map) e.key: asInt((e.value['sells'] as Map)['unit_price']),
  };
});

/// gem exchange in both directions. key is "gems:100" or "coins:1000000"
final exchangeProvider = FutureProvider.family<int, String>((ref, key) async {
  final api = ref.watch(gw2ApiProvider);
  final parts = key.split(':');
  final amount = int.tryParse(parts.last) ?? 0;
  if (amount <= 0) return 0;
  return parts.first == 'gems' ? api.coinsForGems(amount) : api.gemsForCoins(amount);
});

/// guild ids the account belongs to, plus the ones it leads
final guildIdsProvider = FutureProvider<List<String>>((ref) async {
  final account = await ref.watch(accountProvider.future);
  return [
    for (final g in (account['guilds'] as List?) ?? const []) '$g',
  ];
});

final guildProvider = FutureProvider.family<Json, String>((ref, id) => ref.watch(gw2ApiProvider).guild(id));

class GuildStashSlot {
  const GuildStashSlot(this.tabName, this.slots, this.coins, this.note);
  final String tabName;
  final List<ItemSlot> slots;
  final int coins;
  final String note;
}

final guildStashProvider = FutureProvider.family<List<GuildStashSlot>, String>((ref, id) async {
  final api = ref.watch(gw2ApiProvider);
  final tabs = await api.guildStash(id);
  final ids = <int>{};
  for (final tab in tabs) {
    for (final slot in (tab['inventory'] as List?) ?? const []) {
      if (slot is Map) ids.add(asInt(slot['id']));
    }
  }
  final items = await api.items(ids);
  return [
    for (final tab in tabs)
      GuildStashSlot(
        '${tab['note'] ?? ''}'.trim().isEmpty ? '#${tab['upgrade_id']}' : '${tab['note']}',
        [
          for (final slot in (tab['inventory'] as List?) ?? const [])
            if (slot is Map)
              ItemSlot(asInt(slot['id']), asInt(slot['count']), items[asInt(slot['id'])]),
        ],
        asInt(tab['coins']),
        '${tab['note'] ?? ''}',
      ),
  ];
});

class TreasuryRow {
  const TreasuryRow(this.item, this.count, this.needed);
  final Json? item;
  final int count;
  final int needed;

  String get name => (item?['name'] as String?) ?? '-';
  double get ratio => needed == 0 ? 1 : count / needed;
}

/// what the guild has stored against what its upgrades still need
final guildTreasuryProvider = FutureProvider.family<List<TreasuryRow>, String>((ref, id) async {
  final api = ref.watch(gw2ApiProvider);
  final rows = await api.guildTreasury(id);
  final items = await api.items(rows.map((r) => asInt(r['item_id'])));
  final out = <TreasuryRow>[];
  for (final row in rows) {
    var needed = 0;
    for (final upgrade in (row['needed_by'] as List?) ?? const []) {
      if (upgrade is Map) needed += asInt(upgrade['count']);
    }
    out.add(TreasuryRow(items[asInt(row['item_id'])], asInt(row['count']), needed));
  }
  out.sort((a, b) => a.ratio.compareTo(b.ratio));
  return out;
});

final guildLogProvider = FutureProvider.family<List<Json>, String>((ref, id) async {
  final log = await ref.watch(gw2ApiProvider).guildLog(id);
  log.sort((a, b) => asInt(b['id']).compareTo(asInt(a['id'])));
  return log.take(50).toList();
});
