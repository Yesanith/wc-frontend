import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/cache.dart';
import '../util.dart';

class Gw2ApiException implements Exception {
  Gw2ApiException(this.message, [this.status]);
  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// client for https://api.guildwars2.com/v2
/// static data (items, currencies, specs) is cached in memory and fetched
/// in batches of 200 ids so we stay inside the rate limit
class Gw2Api {
  Gw2Api(this.apiKey, {this.lang = 'en', this.cache, http.Client? client}) : _client = client ?? http.Client();

  final String? apiKey;

  /// disk cache for static game data, null disables persistence
  final DiskCache? cache;

  /// en, de, fr, es or zh. item/skill names come back in this language
  final String lang;
  final http.Client _client;

  static const _base = 'https://api.guildwars2.com/v2';

  final Map<int, Json> _itemCache = {};
  final Map<int, Json> _currencyCache = {};
  final Map<int, Json> _specCache = {};
  final Map<int, Json> _achievementCache = {};
  final Map<int, Json> _masteryCache = {};
  final Map<int, Json> _traitCache = {};
  final Map<int, Json> _skillCache = {};
  final Map<int, Json> _petCache = {};
  final Map<int, Json> _recipeCache = {};
  late final Map<String, Map<int, Json>> _caches = {
    'items': _itemCache,
    'currencies': _currencyCache,
    'specializations': _specCache,
    'achievements': _achievementCache,
    'masteries': _masteryCache,
    'traits': _traitCache,
    'skills': _skillCache,
    'pets': _petCache,
    'recipes': _recipeCache,
  };
  final Set<String> _loaded = {};
  final Set<String> _dirty = {};
  Timer? _saveTimer;

  /// static data lives on disk for a month, names only change with patches
  static const _cacheMaxAge = Duration(days: 30);

  Future<void> _loadCache(String name) async {
    final store = cache;
    if (store == null || !_loaded.add(name)) return;
    final raw = await store.read('${name}_$lang', maxAge: _cacheMaxAge);
    if (raw == null) return;
    final target = _caches[name];
    if (target == null) return;
    raw.forEach((key, value) {
      final id = int.tryParse(key);
      if (id != null && value is Map) target.putIfAbsent(id, () => Map<String, dynamic>.from(value));
    });
  }

  /// batched so a screen that fetches 300 items only writes once
  void _scheduleSave(String name) {
    if (cache == null) return;
    _dirty.add(name);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 3), _flush);
  }

  Future<void> _flush() async {
    final store = cache;
    if (store == null) return;
    for (final name in _dirty.toList()) {
      final data = _caches[name];
      if (data == null) continue;
      await store.write('${name}_$lang', {for (final e in data.entries) '${e.key}': e.value});
    }
    _dirty.clear();
  }

  /// account data with a short lived disk copy. the cached value is used
  /// while it is fresh and also as a fallback when the request fails, so the
  /// app still shows something without a connection
  Future<dynamic> cachedGet(
    String path, {
    Map<String, String>? query,
    Duration ttl = const Duration(minutes: 3),
  }) async {
    final store = cache;
    if (store == null) return get(path, query);
    final suffix = query == null ? '' : '_${query.values.join('_')}';
    final name = 'acct_' + path.replaceAll('/', '_') + suffix + '_' + lang;
    final fresh = await store.read(name, maxAge: ttl);
    if (fresh != null && fresh.containsKey('value')) return fresh['value'];
    try {
      final value = await get(path, query);
      await store.write(name, {'value': value});
      return value;
    } catch (_) {
      final stale = await store.read(name, maxAge: const Duration(days: 7));
      if (stale != null && stale.containsKey('value')) return stale['value'];
      rethrow;
    }
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) async {
    final params = <String, String>{
      ...?query,
      'v': 'latest',
      'lang': lang,
    };
    final key = apiKey;
    if (key != null && key.isNotEmpty) params['access_token'] = key;

    final uri = Uri.parse('$_base$path').replace(queryParameters: params);
    final res = await _send(uri);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }

    var msg = 'API error (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['text'] is String) msg = body['text'] as String;
    } catch (_) {}
    if (res.statusCode == 401 || res.statusCode == 403) {
      msg = 'Not authorized: $msg';
    }
    throw Gw2ApiException(msg, res.statusCode);
  }

  Future<http.Response> _send(Uri uri) async {
    try {
      return await _client.get(uri).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Gw2ApiException('The server did not respond, try again.');
    } catch (_) {
      throw Gw2ApiException('Could not connect. Check your internet connection.');
    }
  }

  static List<Json> _list(dynamic raw) =>
      (raw as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<Json> tokenInfo() async => Map<String, dynamic>.from(await get('/tokeninfo') as Map);

  Future<Json> account() async => Map<String, dynamic>.from(await cachedGet('/account') as Map);

  Future<List<Json>> characters() async => _list(await cachedGet('/characters', query: {'ids': 'all'}));

  Future<List<Json>> wallet() async => _list(await cachedGet('/account/wallet'));

  Future<List<Json>> materials() async => _list(await cachedGet('/account/materials'));

  Future<List<Json?>> bank() async {
    final raw = await cachedGet('/account/bank') as List;
    return raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : null).toList();
  }

  Future<List<Json?>> sharedInventory() async {
    final raw = await get('/account/inventory') as List;
    return raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : null).toList();
  }

  /// trading post buy/sell listings, keyed by item id. not cached, prices move
  Future<Map<int, Json>> prices(Iterable<int> ids) async {
    final list = ids.where((id) => id > 0).toSet().toList();
    final out = <int, Json>{};
    for (var i = 0; i < list.length; i += 200) {
      final end = (i + 200 > list.length) ? list.length : i + 200;
      try {
        final raw = await get('/commerce/prices', {'ids': list.sublist(i, end).join(',')});
        for (final e in _list(raw)) {
          out[asInt(e['id'])] = e;
        }
      } on Gw2ApiException catch (e) {
        // 404 = none of these items are tradeable
        if (e.status != 404) rethrow;
      }
    }
    return out;
  }

  /// needs the tradingpost permission. kind is current/buys, current/sells,
  /// history/buys or history/sells. history only goes back 90 days
  Future<List<Json>> transactions(String kind) async =>
      _list(await get('/commerce/transactions/$kind', {'page_size': '200'}));

  /// coins and items waiting to be picked up at a trading post npc
  Future<Json> delivery() async => Map<String, dynamic>.from(await get('/commerce/delivery') as Map);

  /// how many coins you get for [gems] gems
  Future<int> coinsForGems(int gems) async {
    final r = await get('/commerce/exchange/gems', {'quantity': '$gems'}) as Map;
    return asInt(r['quantity']);
  }

  /// how many gems you get for [coins] copper
  Future<int> gemsForCoins(int coins) async {
    final r = await get('/commerce/exchange/coins', {'quantity': '$coins'}) as Map;
    return asInt(r['quantity']);
  }

  /// daily, weekly or special objectives of the wizard's vault
  Future<Json> vault(String track) async =>
      Map<String, dynamic>.from(await cachedGet('/account/wizardsvault/$track') as Map);

  /// plain id list of a static endpoint, ids can be ints or strings
  Future<List<String>> idList(String path) async {
    final raw = await get(path) as List;
    return raw.map((e) => '$e').toList();
  }

  /// account unlock list. entries are ids or objects with an id field
  Future<List<String>> unlockedIds(String path) async {
    final raw = await get(path) as List;
    return raw.map((e) => e is Map ? '${e['id']}' : '$e').toList();
  }

  /// details for a static endpoint, in batches of 200. a batch that fails
  /// because one id is unknown gets split instead of dropped, otherwise a
  /// single bad id would cost 200 names
  Future<List<Json>> details(String path, List<String> ids) async {
    final out = <Json>[];
    for (var i = 0; i < ids.length; i += 200) {
      final end = (i + 200 > ids.length) ? ids.length : i + 200;
      out.addAll(await _detailChunk(path, ids.sublist(i, end)));
    }
    return out;
  }

  Future<List<Json>> _detailChunk(String path, List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      return _list(await get(path, {'ids': ids.join(',')}));
    } on Gw2ApiException catch (e) {
      if (e.status != 404 && e.status != 400) rethrow;
      if (ids.length == 1) return const [];
      final middle = ids.length ~/ 2;
      return [
        ...await _detailChunk(path, ids.sublist(0, middle)),
        ...await _detailChunk(path, ids.sublist(middle)),
      ];
    }
  }

  Future<Map<int, Json>> items(Iterable<int> ids) => _batch('/items', ids, _itemCache);

  Future<Map<int, Json>> currencies(Iterable<int> ids) => _batch('/currencies', ids, _currencyCache);

  Future<Map<int, Json>> specializations(Iterable<int> ids) =>
      _batch('/specializations', ids, _specCache);

  Future<Map<int, Json>> achievements(Iterable<int> ids) =>
      _batch('/achievements', ids, _achievementCache);

  Future<Map<int, Json>> masteries(Iterable<int> ids) => _batch('/masteries', ids, _masteryCache);

  Future<Map<int, Json>> traits(Iterable<int> ids) => _batch('/traits', ids, _traitCache);

  Future<Map<int, Json>> skills(Iterable<int> ids) => _batch('/skills', ids, _skillCache);

  Future<Map<int, Json>> pets(Iterable<int> ids) => _batch('/pets', ids, _petCache);

  Future<Map<int, Json>> recipes(Iterable<int> ids) => _batch('/recipes', ids, _recipeCache);

  /// recipe ids that produce this item, empty when it cannot be crafted
  Future<List<int>> recipesForOutput(int itemId) async {
    try {
      final raw = await get('/recipes/search', {'output': '$itemId'}) as List;
      return raw.map(asInt).toList();
    } on Gw2ApiException catch (e) {
      if (e.status == 404) return const [];
      rethrow;
    }
  }

  /// weapons, palettes and skill lists of a profession
  Future<Json> profession(String name) async =>
      Map<String, dynamic>.from(await get('/professions/$name') as Map);

  /// raid encounters cleared this week and the wing layout
  Future<List<String>> accountRaids() async => (await cachedGet('/account/raids') as List).map((e) => '$e').toList();

  Future<List<Json>> raidWings() async {
    final ids = await idList('/raids');
    if (ids.isEmpty) return const [];
    return details('/raids', ids);
  }

  /// dungeon paths cleared today
  Future<List<String>> accountDungeons() async =>
      (await cachedGet('/account/dungeons') as List).map((e) => '$e').toList();

  Future<List<Json>> dungeons() async {
    final ids = await idList('/dungeons');
    if (ids.isEmpty) return const [];
    return details('/dungeons', ids);
  }

  Future<Json> pvpStats() async => Map<String, dynamic>.from(await cachedGet('/pvp/stats') as Map);

  /// revenant legends, ids look like "Legend1"
  Future<List<Json>> legends(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return _list(await get('/legends', {'ids': ids.join(',')}));
  }

  /// daily crafts and map chests already collected today, both need the
  /// progression permission
  Future<List<String>> dailyDone(String path) async =>
      (await cachedGet('/account/$path', ttl: const Duration(minutes: 5)) as List)
          .map((e) => '$e')
          .toList();

  Future<List<String>> dailyAll(String path) async => idList('/$path');

  Future<List<Json>> accountAchievements() async => _list(await cachedGet('/account/achievements'));

  Future<List<Json>> accountMasteries() async => _list(await cachedGet('/account/masteries'));

  Future<Json> masteryPoints() async =>
      Map<String, dynamic>.from(await cachedGet('/account/mastery/points') as Map);

  Future<List<Json>> legendaryArmory() async => _list(await cachedGet('/account/legendaryarmory'));

  /// stored build templates. the list endpoint gives ids, details come from
  /// the same path with an ids parameter
  Future<List<Json>> buildStorage() async {
    final ids = (await cachedGet('/account/buildstorage') as List).map((e) => '$e').toList();
    if (ids.isEmpty) return const [];
    final out = <Json>[];
    for (var i = 0; i < ids.length; i += 200) {
      final end = (i + 200 > ids.length) ? ids.length : i + 200;
      out.addAll(_list(await get('/account/buildstorage', {'ids': ids.sublist(i, end).join(',')})));
    }
    return out;
  }

  Future<Map<int, Json>> _batch(String path, Iterable<int> ids, Map<int, Json> store) async {
    final name = path.substring(1);
    await _loadCache(name);
    final wanted = ids.where((id) => id > 0).toSet();
    final missing = wanted.where((id) => !store.containsKey(id)).toList();
    for (var i = 0; i < missing.length; i += 200) {
      final end = (i + 200 > missing.length) ? missing.length : i + 200;
      final chunk = missing.sublist(i, end);
      try {
        final raw = await get(path, {'ids': chunk.join(',')});
        for (final e in _list(raw)) {
          store[asInt(e['id'])] = e;
        }
        _scheduleSave(name);
      } on Gw2ApiException catch (e) {
        // 404 = none of the ids exist, skip them instead of failing the whole screen
        if (e.status != 404) rethrow;
      }
    }
    return {
      for (final id in wanted)
        if (store.containsKey(id)) id: store[id]!,
    };
  }
}
