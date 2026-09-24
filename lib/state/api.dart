import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/gw2_api.dart';
import '../api/wiki_api.dart';
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

/// bumped whenever account data on disk changed behind the screens' back,
/// after a background refresh or a full sync
final accountRevisionProvider = StateProvider<int>((ref) => 0);

/// background refreshes currently running, drives the thin progress bar
final backgroundRefreshProvider = StateProvider<int>((ref) => 0);

final gw2ApiProvider = Provider<Gw2Api>((ref) {
  final lang = ref.watch(langProvider);
  // many entries refresh at once after a cold start, one re-read is enough
  Timer? pending;
  late final Gw2Api api;
  ref.onDispose(() {
    pending?.cancel();
    // a new key or language builds a new client, the old sockets go away
    api.close();
  });
  return api = Gw2Api(
    ref.watch(apiKeyProvider).valueOrNull,
    lang: lang.apiLang,
    cache: ref.watch(diskCacheProvider),
    onRevalidated: () {
      pending?.cancel();
      pending = Timer(const Duration(milliseconds: 400), () {
        ref.read(accountRevisionProvider.notifier).state++;
      });
    },
    onBackground: (delta) {
      final counter = ref.read(backgroundRefreshProvider.notifier);
      final next = counter.state + delta;
      counter.state = next < 0 ? 0 : next;
    },
  );
});

/// account providers read through this, so they re-read the cache whenever
/// fresher data arrived. static game data keeps using gw2ApiProvider
Gw2Api accountApi(Ref ref) {
  ref.watch(accountRevisionProvider);
  return ref.watch(gw2ApiProvider);
}

final wikiApiProvider = Provider<WikiApi>((ref) => WikiApi(ref.watch(langProvider).wikiBase));

final tokenInfoProvider = FutureProvider<Json>((ref) => ref.watch(gw2ApiProvider).tokenInfo());
