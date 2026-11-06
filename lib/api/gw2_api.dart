import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../services/cache.dart';
import '../util.dart';

part 'endpoints/account.dart';
part 'endpoints/guilds_wvw.dart';
part 'endpoints/pvp.dart';
part 'endpoints/reference.dart';
part 'endpoints/trading.dart';

/// what went wrong, so the interface can say it in the user's language
enum ApiErrorKind { offline, timeout, unauthorized, notFound, rateLimited, server, noKey, other }

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

/// the address of a request. a browser cannot send the key in a header: the
/// game's api answers no CORS preflight, so there it goes in the address as the
/// api documents for browsers. everywhere else it stays out of the address, so
/// it never ends up in a proxy log or a crash report that records the request
Uri gw2Uri(
  String base,
  String path, {
  Map<String, String>? query,
  required String lang,
  String? key,
  bool web = false,
}) {
  return Uri.parse('$base$path').replace(
    queryParameters: {
      ...?query,
      'v': 'latest',
      'lang': lang,
      if (web && key != null && key.isNotEmpty) 'access_token': key,
    },
  );
}

/// the headers of a request, the key in one unless it is in the address
Map<String, String>? gw2Headers(String? key, {bool web = false}) =>
    !web && key != null && key.isNotEmpty ? {'Authorization': 'Bearer $key'} : null;

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
    this.serverPrices,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// fresh account data landed in the cache after a background refresh
  final void Function()? onRevalidated;

  /// +1 when a background refresh starts, -1 when it ends
  final void Function(int delta)? onBackground;

  /// the prices the server has read, for these items. the game is asked for the ones it has not, or has not read lately
  final Future<List<Json>> Function(List<int> ids)? serverPrices;

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

  /// true for a few seconds after pull to refresh asked for fresh data
  bool get forcing => _forcing;

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

  /// forgets every static entry held in memory, after a patch cleared the
  /// disk copy. otherwise the next save would write the old data straight
  /// back and keep it for another month
  void clearStaticCaches() {
    _saveTimer?.cancel();
    _dirty.clear();
    _loading.clear();
    for (final data in _caches.values) {
      data.clear();
    }
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
  /// [notBefore] is for data that resets, daily or weekly: a copy saved
  /// before it belongs to the previous period and is never shown, not even
  /// when the api cannot be reached
  Future<dynamic> cachedGet(
    String path, {
    Map<String, String>? query,
    Duration ttl = const Duration(minutes: 30),
    bool force = false,
    DateTime? notBefore,
  }) async {
    final store = cache;
    if (store == null) return get(path, query);
    final suffix = query == null ? '' : '_${query.values.join('_')}';
    final name = 'acct_${_account}_${path.replaceAll('/', '_')}${suffix}_$lang';
    // how old a copy may be and still belong to the current period
    final maxAge = copyMaxAge(notBefore, DateTime.now());

    if (!force && !_forcing) {
      final cached = await store.readWithAge(name, maxAge: maxAge);
      if (cached != null && cached.data.containsKey('value')) {
        if (cached.age > ttl) _revalidate(name, path, query);
        return cached.data['value'];
      }
    }

    try {
      return await _fetchAndStore(name, path, query);
    } catch (_) {
      final stale = await store.read(name, maxAge: maxAge);
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

  /// the raw body of a request, for responses big enough that decoding them
  /// belongs in a background isolate rather than on the ui thread
  Future<String> getText(String path, [Map<String, String>? query]) async {
    final params = <String, String>{...?query, 'v': 'latest', 'lang': lang};
    final uri = Uri.parse('$_base$path').replace(queryParameters: params);
    final res = await _send(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) return utf8.decode(res.bodyBytes);
    throw Gw2ApiException('API error (${res.statusCode})', res.statusCode);
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) async {
    final key = apiKey;
    final uri = gw2Uri(_base, path, query: query, lang: lang, key: key, web: kIsWeb);
    final res = await _send(uri, gw2Headers(key, web: kIsWeb));

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

  /// every request of the app passes this gate: at most [maxParallel] at
  /// once across all clients, so opening a busy page does not fire dozens of
  /// requests together and trip the api's rate limit
  static const maxParallel = 6;
  static final TaskPool _gate = TaskPool(maxParallel);

  /// a rate limit answer or a passing gateway error is tried again after a
  /// pause instead of failing the page, up to three times
  static const _retryable = {429, 502, 503, 504};

  /// how long to wait before asking again after "Invalid access token"
  static Duration invalidTokenPause = const Duration(seconds: 1);

  /// whether there is an api key. without one the app runs as a guest
  bool get hasKey => (apiKey ?? '').isNotEmpty;

  Future<http.Response> _send(Uri uri, [Map<String, String>? headers]) {
    // a guest asking for account data gets its answer here, without a request
    // that could only come back as 401
    if (!hasKey && pathNeedsKey(uri.path)) {
      return Future.error(Gw2ApiException('An API key is needed for this.', null, ApiErrorKind.noKey));
    }
    return _gate.run(() async {
      var askedAgainForToken = false;
      for (var attempt = 0; ; attempt++) {
        final res = await _sendOnce(uri, headers);
        // the api now and then calls a good key invalid for a moment. one
        // more try tells that apart from a key that really is wrong
        if (res.statusCode == 401 && !askedAgainForToken && hasKey && res.body.contains('Invalid access token')) {
          askedAgainForToken = true;
          await Future<void>.delayed(invalidTokenPause);
          continue;
        }
        if (!_retryable.contains(res.statusCode) || attempt >= 3) return res;
        // the slot stays taken while waiting, which slows the whole app
        // down a little right when the api asks for exactly that
        await Future<void>.delayed(retryDelay(res.headers['retry-after'], attempt));
      }
    });
  }

  Future<http.Response> _sendOnce(Uri uri, Map<String, String>? headers) async {
    try {
      return await _client.get(uri, headers: headers).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Gw2ApiException('The server did not respond, try again.', null, ApiErrorKind.timeout);
    } catch (_) {
      throw Gw2ApiException('Could not connect. Check your internet connection.', null, ApiErrorKind.offline);
    }
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

List<Json> _list(dynamic raw) => (raw as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

/// one object of a response, copied so it can be kept
Json _object(dynamic raw) => Map<String, dynamic>.from(raw as Map);

/// the api accepts at most 200 ids per request
Iterable<List<T>> _chunks<T>(List<T> ids) sync* {
  for (var i = 0; i < ids.length; i += 200) {
    yield ids.sublist(i, i + 200 > ids.length ? ids.length : i + 200);
  }
}

/// how long to wait before retrying: what the server asked for in
/// Retry-After, otherwise 1, 2 and 4 seconds, never more than ten
Duration retryDelay(String? retryAfter, int attempt) {
  final asked = int.tryParse(retryAfter?.trim() ?? '');
  final seconds = asked ?? (1 << attempt);
  return Duration(seconds: seconds.clamp(1, 10));
}

/// how old a cached copy may be: a week, or less when it has to be newer
/// than [notBefore], the last reset of data that resets
Duration copyMaxAge(DateTime? notBefore, DateTime now) {
  const week = Duration(days: 7);
  if (notBefore == null) return week;
  final since = now.toUtc().difference(notBefore.toUtc());
  if (since.isNegative) return Duration.zero;
  return since < week ? since : week;
}

/// whether the api answers this path only to a key: the account, its
/// characters, the trading post's own orders and deliveries, the player's own
/// pvp record and what a guild keeps for its members. everything else is
/// public: items, prices, maps, the wiki, the wvw and the guild's name
bool pathNeedsKey(String path) {
  final p = path.startsWith('/v2') ? path.substring(3) : path;
  if (p == '/account' || p.startsWith('/account/')) return true;
  if (p == '/characters' || p.startsWith('/characters/')) return true;
  if (p == '/tokeninfo' || p.startsWith('/createsubtoken')) return true;
  if (p.startsWith('/commerce/transactions') || p.startsWith('/commerce/delivery')) return true;
  if (p.startsWith('/pvp/stats') || p.startsWith('/pvp/games') || p.startsWith('/pvp/standings')) return true;
  return RegExp(r'^/guild/[0-9A-Fa-f-]{36}/(log|members|ranks|stash|storage|teams|treasury|upgrades)').hasMatch(p);
}

/// how old a price of the server may be, and still be taken for the price now: it reads every ten minutes
const serverPriceMaxAge = Duration(minutes: 25);

/// whether a price the server gives was read lately enough
bool serverPriceFresh(Json row, {DateTime? now}) {
  final at = DateTime.tryParse('${row['updated_at']}');
  if (at == null) return false;
  final age = (now ?? DateTime.now()).difference(at);
  // a clock a few minutes ahead is not a reason to distrust a price
  return age < serverPriceMaxAge && age > const Duration(minutes: -5);
}
