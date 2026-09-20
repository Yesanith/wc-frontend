import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/gw2_api.dart';
import '../api/wiki_api.dart';
import '../util.dart';

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

final gw2ApiProvider = Provider<Gw2Api>((ref) => Gw2Api(ref.watch(apiKeyProvider).valueOrNull));

final wikiApiProvider = Provider<WikiApi>((ref) => WikiApi());

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
      (c?['name'] as String?) ?? 'Para birimi #$id',
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
