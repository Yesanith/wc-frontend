import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    () => api.idList(kind.staticPath),
  );
  return rows.map((e) => '$e').toList();
});

final collectionUnlockedProvider = FutureProvider.family<Set<String>, String>((ref, key) async {
  final api = accountApi(ref);
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
    () => api.details(kind.staticPath, ids),
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
    entries.add(CollectionEntry(id, name, byId[id]?['icon'] as String?, unlocked.contains(id)));
  }
  // unnamed entries go last instead of bunching up at the top
  entries.sort((a, b) {
    if (a.name.isEmpty != b.name.isEmpty) return a.name.isEmpty ? 1 : -1;
    return a.name.compareTo(b.name);
  });
  return entries;
});
