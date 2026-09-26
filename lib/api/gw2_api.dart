import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/cache.dart';
import '../util.dart';

/// what went wrong, so the interface can say it in the user's language
enum ApiErrorKind { offline, timeout, unauthorized, notFound, rateLimited, server, other }

class Gw2ApiException implements Exception {
  Gw2ApiException(this.message, [this.status, this._kind]);
  final String message;
  final int? status;
  final ApiErrorKind? _kind;

  ApiErrorKind get kind {
    final fixed = _kind;
    if (fixed != null) return fixed;
    final code = status ?? 0;
    if (code == 401 || code == 403) return ApiErrorKind.unauthorized;
    if (code == 404) return ApiErrorKind.notFound;
    if (code == 429) return ApiErrorKind.rateLimited;
    if (code >= 500) return ApiErrorKind.server;
    return ApiErrorKind.other;
  }

  @override
  String toString() => message;
}

/// client for https://api.guildwars2.com/v2
/// static data (items, currencies, specs) is cached in memory and fetched
/// in batches of 200 ids so we stay inside the rate limit
class Gw2Api {
  Gw2Api(
    this.apiKey, {
    this.lang = 'en',
    this.cache,
    this.onRevalidated,
    this.onBackground,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// fresh account data landed in the cache after a background refresh
  final void Function()? onRevalidated;

  /// +1 when a background refresh starts, -1 when it ends
  final void Function(int delta)? onBackground;

  /// upper bound per static cache (items, skills, ...) kept on disk
  static const _maxCachedPerKind = 6000;

  DateTime? _forceUntil;
  final Map<String, Future<dynamic>> _inFlight = {};

  /// the next few seconds of cached reads go to the network instead, which
  /// is what pull to refresh needs
  void forceNetwork([Duration window = const Duration(seconds: 8)]) {
    _forceUntil = DateTime.now().add(window);
  }

  /// releases the sockets of this instance, called when the provider that
  /// owns it is rebuilt for another key or language
  void close() => _client.close();

  bool get _forcing {
    final until = _forceUntil;
    return until != null && DateTime.now().isBefore(until);
  }

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
  final Map<String, Future<void>> _loading = {};
  final Set<String> _dirty = {};
  Timer? _saveTimer;

  /// static data lives on disk for a month, names only change with patches
  static const _cacheMaxAge = Duration(days: 30);

  /// every caller of the same kind waits on one disk read, otherwise a
  /// second request during start up would see an empty cache and refetch
  Future<void> _loadCache(String name) {
    if (cache == null) return Future.value();
    return _loading.putIfAbsent(name, () => _readCache(name));
  }

  Future<void> _readCache(String name) async {
    final store = cache;
    if (store == null) return;
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
    final names = _dirty.toList();
    _dirty.removeAll(names);
    for (final name in names) {
      final data = _caches[name];
      if (data == null) continue;
      // maps keep insertion order, so the oldest lookups are dropped first
      // once a cache outgrows what is worth keeping on disk
      if (data.length > _maxCachedPerKind) {
        final drop = data.keys.take(data.length - _maxCachedPerKind).toList();
        drop.forEach(data.remove);
      }
      await store.write('${name}_$lang', {for (final e in data.entries) '${e.key}': e.value});
    }
  }

  /// short stable id for the active key, so two accounts never read each
  /// other's cached data. only the hash is written to disk, never the key
  late final String _account = _fingerprint(apiKey ?? '');

  static String _fingerprint(String value) {
    if (value.isEmpty) return 'anon';
    // fnv-1a, deterministic across runs unlike String.hashCode
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(value)) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// account data, stale while revalidate. a cached copy is returned right
  /// away, and when it is older than [ttl] a refresh runs in the background
  /// and [onRevalidated] tells the app to re-read it. only an empty cache,
  /// [force] or a recent [forceNetwork] makes the caller wait on the network
  Future<dynamic> cachedGet(
    String path, {
    Map<String, String>? query,
    Duration ttl = const Duration(minutes: 30),
    bool force = false,
  }) async {
    final store = cache;
    if (store == null) return get(path, query);
    final suffix = query == null ? '' : '_${query.values.join('_')}';
    final name = 'acct_${_account}_${path.replaceAll('/', '_')}${suffix}_$lang';

    if (!force && !_forcing) {
      final cached = await store.readWithAge(name, maxAge: const Duration(days: 7));
      if (cached != null && cached.data.containsKey('value')) {
        if (cached.age > ttl) _revalidate(name, path, query);
        return cached.data['value'];
      }
    }

    try {
      return await _fetchAndStore(name, path, query);
    } catch (_) {
      final stale = await store.read(name, maxAge: const Duration(days: 7));
      if (stale != null && stale.containsKey('value')) return stale['value'];
      rethrow;
    }
  }

  /// one network request per cache entry at a time. the launch sync, a pull
  /// to refresh and a background revalidation asking for the same entry all
  /// share the request that is already running
  Future<dynamic> _fetchAndStore(String name, String path, Map<String, String>? query) {
    return _inFlight.putIfAbsent(name, () async {
      try {
        final value = await get(path, query);
        await cache?.write(name, {'value': value});
        return value;
      } finally {
        _inFlight.remove(name);
      }
    });
  }

  /// background refresh of one cached entry
  void _revalidate(String name, String path, Map<String, String>? query) {
    if (cache == null || _inFlight.containsKey(name)) return;
    // callbacks go through the event loop, never inside a provider build
    Future(() => onBackground?.call(1));
    () async {
      try {
        await _fetchAndStore(name, path, query);
        Future(() => onRevalidated?.call());
      } catch (_) {
        // the stale copy stays, the next read tries again
      } finally {
        Future(() => onBackground?.call(-1));
      }
    }();
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
      throw Gw2ApiException('The server did not respond, try again.', null, ApiErrorKind.timeout);
    } catch (_) {
      throw Gw2ApiException('Could not connect. Check your internet connection.', null, ApiErrorKind.offline);
    }
  }

  static List<Json> _list(dynamic raw) =>
      (raw as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  /// the api accepts at most 200 ids per request
  static Iterable<List<T>> _chunks<T>(List<T> ids) sync* {
    for (var i = 0; i < ids.length; i += 200) {
      yield ids.sublist(i, i + 200 > ids.length ? ids.length : i + 200);
    }
  }

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
    final out = <int, Json>{};
    for (final chunk in _chunks(ids.where((id) => id > 0).toSet().toList())) {
      try {
        final raw = await get('/commerce/prices', {'ids': chunk.join(',')});
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
  Future<List<Json>> transactions(String kind) async {
    // the api pages at 200 rows, history can go up to 90 days of trading
    final out = <Json>[];
    for (var page = 0; page < 15; page++) {
      final List<Json> rows;
      try {
        rows = _list(await get('/commerce/transactions/$kind', {'page_size': '200', 'page': '$page'}));
      } on Gw2ApiException catch (e) {
        // asking past the last page is a 400, that just means we are done
        if (page > 0 && (e.status == 400 || e.status == 404)) break;
        rethrow;
      }
      out.addAll(rows);
      if (rows.length < 200) break;
    }
    return out;
  }

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
    for (final chunk in _chunks(ids)) {
      out.addAll(await _detailChunk(path, chunk));
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

  Future<Map<int, Json>> specializations(Iterable<int> ids) => _batch('/specializations', ids, _specCache);

  Future<Map<int, Json>> achievements(Iterable<int> ids) => _batch('/achievements', ids, _achievementCache);

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
  Future<Json> profession(String name) async => Map<String, dynamic>.from(await get('/professions/$name') as Map);

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

  /// guild endpoints. most need the guilds permission and some also
  /// require the account to lead the guild
  Future<Json> guild(String id) async =>
      Map<String, dynamic>.from(await cachedGet('/guild/$id', ttl: const Duration(hours: 6)) as Map);

  Future<List<Json>> guildStash(String id) async => _list(await cachedGet('/guild/$id/stash'));

  Future<List<Json>> guildTreasury(String id) async => _list(await cachedGet('/guild/$id/treasury'));

  Future<List<Json>> guildLog(String id) async => _list(await cachedGet('/guild/$id/log'));

  /// every map of the game, static data
  Future<List<Json>> maps() async => _list(await get('/maps', {'ids': 'all'}));

  /// the floor entry of one map, this is where waypoints and their chat
  /// links live
  Future<Json> mapDetail(int continent, int floor, int region, int map) async =>
      Map<String, dynamic>.from(await get('/continents/$continent/floors/$floor/regions/$region/maps/$map') as Map);

  // ---------------------------------------------------------------------
  // static reference data, requested whole with ids=all

  /// every entry of a static endpoint that accepts ids=all
  Future<List<Json>> allOf(String path) async => _list(await get(path, {'ids': 'all'}));

  /// the current game build, changes with every patch
  Future<int> gameBuild() async {
    final raw = await get('/build');
    return raw is Map ? asInt(raw['id']) : 0;
  }

  // ---------------------------------------------------------------------
  // account extras

  /// recipe ids the account has learned. needs the unlocks permission
  Future<List<int>> learnedRecipes() async => [for (final v in (await cachedGet('/account/recipes') as List)) asInt(v)];

  /// luck, fractal augmentations and similar counters, as {id: value}
  Future<Map<String, int>> accountCounters(String path) async {
    final raw = await cachedGet(path);
    return {
      for (final row in (raw as List? ?? const []))
        if (row is Map) '${row['id']}': asInt(row['value']),
    };
  }

  /// the team and guild the account plays world vs world with
  Future<Json> accountWvw() async => Map<String, dynamic>.from(await cachedGet('/account/wvw') as Map);

  /// one part of a character, such as heropoints, sab, quests or training
  Future<dynamic> characterPart(String name, String part) =>
      cachedGet('/characters/${Uri.encodeComponent(name)}/$part');

  // ---------------------------------------------------------------------
  // wizard's vault

  Future<Json> vaultSeason() async => Map<String, dynamic>.from(await get('/wizardsvault') as Map);

  /// the astral reward shop with what this account already bought
  Future<List<Json>> vaultListings() async => _list(await cachedGet('/account/wizardsvault/listings'));

  // ---------------------------------------------------------------------
  // trading post

  /// full order book of one item, every price level with its quantity
  Future<Json?> listings(int itemId) async {
    try {
      return Map<String, dynamic>.from(await get('/commerce/listings/$itemId') as Map);
    } on Gw2ApiException catch (e) {
      // untradeable items answer 404
      if (e.status == 404) return null;
      rethrow;
    }
  }

  // ---------------------------------------------------------------------
  // guilds. members, ranks, storage and teams need a guild leader's key

  Future<List<Json>> guildPart(String id, String part) async => _list(await cachedGet('/guild/$id/$part'));

  /// upgrade ids the guild has built
  Future<List<int>> guildUpgradeIds(String id) async =>
      [for (final v in (await cachedGet('/guild/$id/upgrades') as List)) asInt(v)];

  // ---------------------------------------------------------------------
  // world vs world, live data is never cached

  Future<Json?> wvwMatch(int team) async {
    try {
      return Map<String, dynamic>.from(await get('/wvw/matches', {'world': '$team'}) as Map);
    } on Gw2ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// next lockout or team assignment per region, kind is lockout or teamAssignment
  Future<Json> wvwTimer(String kind) async => Map<String, dynamic>.from(await get('/wvw/timers/$kind') as Map);

  // ---------------------------------------------------------------------
  // pvp leaderboards

  /// the ladder of one season and region (na or eu)
  Future<List<Json>> pvpLadder(String seasonId, String region) async =>
      _list(await get('/pvp/seasons/$seasonId/leaderboards/ladder/$region'));

  Future<Json> pvpStats() async => Map<String, dynamic>.from(await cachedGet('/pvp/stats') as Map);

  /// the nine rank tiers, Rabbit through Dragon. static
  Future<List<Json>> pvpRanks() async => details('/pvp/ranks', await idList('/pvp/ranks'));

  /// pvp amulets with their attribute spreads. static
  Future<List<Json>> pvpAmulets() async => details('/pvp/amulets', await idList('/pvp/amulets'));

  /// the last matches the api remembers, newest last. the list endpoint gives
  /// ids and the details come from the same path. needs the pvp permission
  Future<List<Json>> pvpGames() async {
    final ids = await idList('/pvp/games');
    if (ids.isEmpty) return const [];
    return details('/pvp/games', ids);
  }

  /// league standing per season. needs the pvp permission
  Future<List<Json>> pvpStandings() async => _list(await cachedGet('/pvp/standings'));

  /// one season, which names the divisions a standing points at
  Future<Json?> pvpSeason(String id) async {
    if (id.isEmpty) return null;
    final rows = await details('/pvp/seasons', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  /// revenant legends, ids look like "Legend1"
  Future<List<Json>> legends(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return _list(await get('/legends', {'ids': ids.join(',')}));
  }

  /// daily crafts and map chests already collected today, both need the
  /// progression permission
  Future<List<String>> dailyDone(String path) async =>
      (await cachedGet('/account/$path', ttl: const Duration(minutes: 5)) as List).map((e) => '$e').toList();

  Future<List<String>> dailyAll(String path) async => idList('/$path');

  Future<List<Json>> accountAchievements() async => _list(await cachedGet('/account/achievements'));

  Future<List<Json>> accountMasteries() async => _list(await cachedGet('/account/masteries'));

  Future<Json> masteryPoints() async => Map<String, dynamic>.from(await cachedGet('/account/mastery/points') as Map);

  Future<List<Json>> legendaryArmory() async => _list(await cachedGet('/account/legendaryarmory'));

  /// stored build templates. the list endpoint gives ids, details come from
  /// the same path with an ids parameter
  Future<List<Json>> buildStorage() async {
    final ids = (await cachedGet('/account/buildstorage') as List).map((e) => '$e').toList();
    if (ids.isEmpty) return const [];
    final out = <Json>[];
    for (final chunk in _chunks(ids)) {
      out.addAll(_list(await get('/account/buildstorage', {'ids': chunk.join(',')})));
    }
    return out;
  }

  Future<Map<int, Json>> _batch(String path, Iterable<int> ids, Map<int, Json> store) async {
    final name = path.substring(1);
    await _loadCache(name);
    final wanted = ids.where((id) => id > 0).toSet();
    final missing = wanted.where((id) => !store.containsKey(id)).toList();
    for (final chunk in _chunks(missing)) {
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
