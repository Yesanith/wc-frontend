import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gw2_api.dart';
import '../data/collections.dart';
import '../services/cache.dart';
import '../util.dart';
import 'api.dart';
import 'settings.dart';

class CollectionProgress {
  const CollectionProgress(this.unlocked, this.total);
  final int unlocked;
  final int total;

  double get ratio => total == 0 ? 0 : unlocked / total;
}

/// all ids of a static collection endpoint, kept on disk for a month
final collectionIdsProvider = FutureProvider.family<List<String>, String>((ref, key) async {
  final api = accountApi(ref);
  final cache = ref.watch(diskCacheProvider);
  final kind = collectionKinds.firstWhere((k) => k.key == key);
  final rows = await cachedList(
    cache,
    'collection_ids_${kind.key}',
    'ids',
    () async => kind.key == 'pvp_heroes'
        ? [for (final skin in await _heroSkins(api)) '${skin['id']}']
        : await api.idList(kind.staticPath),
  );
  return rows.map((e) => '$e').toList();
});

/// pvp heroes carry their skins inline, the account unlocks skins
Future<List<Json>> _heroSkins(Gw2Api api) async {
  final heroes = await api.details('/pvp/heroes', await api.idList('/pvp/heroes'));
  return [
    for (final hero in heroes)
      for (final skin in (hero['skins'] as List?) ?? const [])
        if (skin is Map) Map<String, dynamic>.from(skin),
  ];
}

final collectionUnlockedProvider = FutureProvider.family<Set<String>, String>((ref, key) async {
  final api = accountApi(ref);
  final kind = collectionKinds.firstWhere((k) => k.key == key);
  return (await api.unlockedIds(kind.accountPath)).toSet();
});

final collectionProgressProvider = FutureProvider.autoDispose.family<CollectionProgress, String>((ref, key) async {
  final ids = ref.watch(collectionIdsProvider(key).future);
  final unlocked = ref.watch(collectionUnlockedProvider(key).future);
  final all = await ids;
  final owned = await unlocked;
  return CollectionProgress(owned.where(all.contains).length, all.length);
});

class CollectionEntry {
  const CollectionEntry(this.id, this.name, this.icon, this.unlocked, {this.rarity, this.type, this.subtype});
  final String id;
  final String name;
  final String? icon;
  final bool unlocked;
  final String? rarity;

  /// wardrobe skins only: Armor, Weapon, Back or Gathering
  final String? type;

  /// wardrobe skins only: the slot or weapon, such as Helm or Greatsword,
  /// with the weight class for armour ("Helm · Heavy")
  final String? subtype;
}

/// the few fields a wardrobe skin needs. there are well over ten thousand,
/// the full entries would make the cache several times larger
Json compactSkin(Json raw) {
  final details = raw['details'] is Map ? raw['details'] as Map : const {};
  return {
    'id': raw['id'],
    'name': raw['name'],
    'icon': raw['icon'],
    'rarity': raw['rarity'],
    'type': raw['type'],
    'details': {
      if (details['type'] != null) 'type': details['type'],
      if (details['weight_class'] != null) 'weight_class': details['weight_class'],
    },
  };
}

/// "Helm · Heavy", "Greatsword", or null when a skin carries no details
String? skinSubtype(Json? raw) {
  final details = raw?['details'];
  if (details is! Map || details['type'] == null) return null;
  final weight = details['weight_class'];
  // HelmAquatic -> Helm Aquatic, LongBow -> Longbow
  final slot =
      professionWeaponKey('${details['type']}').replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => ' ${m[1]}');
  // weapons carry a weight class of None, outfits and town clothes Clothing
  return weight == null || weight == 'None' || weight == 'Clothing' ? slot : '$slot · $weight';
}

/// every entry of a collection with its unlock state. details are cached
/// on disk because they only change with a patch
final collectionEntriesProvider = FutureProvider.autoDispose.family<List<CollectionEntry>, String>((ref, key) async {
  final api = accountApi(ref);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);
  final kind = collectionKinds.firstWhere((k) => k.key == key);
  final idsFuture = ref.watch(collectionIdsProvider(key).future);
  final unlockedFuture = ref.watch(collectionUnlockedProvider(key).future);
  final ids = await idsFuture;
  final unlocked = await unlockedFuture;

  final raw = await cachedList(
    cache,
    'collection_${kind.key}_${lang.apiLang}',
    'rows',
    () async => switch (kind.key) {
      'pvp_heroes' => await _heroSkins(api),
      'wardrobe' => [for (final r in await api.details(kind.staticPath, ids)) compactSkin(r)],
      _ => await api.details(kind.staticPath, ids),
    },
  );
  final rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

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
    final row = byId[id];
    entries.add(CollectionEntry(
      id,
      name,
      row?['icon'] as String?,
      unlocked.contains(id),
      rarity: row?['rarity'] as String?,
      type: kind.key == 'wardrobe' ? (row?['type'] as String?) : null,
      subtype: kind.key == 'wardrobe' ? skinSubtype(row) : null,
    ));
  }
  // unnamed entries go last instead of bunching up at the top
  entries.sort((a, b) {
    if (a.name.isEmpty != b.name.isEmpty) return a.name.isEmpty ? 1 : -1;
    return a.name.compareTo(b.name);
  });
  return entries;
});
