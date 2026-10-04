part of '../gw2_api.dart';

/// the trading post: prices, order books, the account's orders and the gem exchange
extension Gw2TradingApi on Gw2Api {
  /// trading post buy/sell listings, keyed by item id. not cached, prices move. the server's, when it has read them lately, else the
  /// game's
  Future<Map<int, Json>> prices(Iterable<int> ids) async {
    final wanted = ids.where((id) => id > 0).toSet().toList();
    final out = <int, Json>{};
    final server = serverPrices;
    if (server != null && wanted.isNotEmpty) {
      try {
        for (final chunk in _chunks(wanted)) {
          for (final row in await server(chunk)) {
            if (serverPriceFresh(row)) out[asInt(row['id'])] = row;
          }
        }
      } catch (_) {
        // the server is a shortcut, never a need: the game is asked for all of it
        out.clear();
      }
    }
    for (final chunk in _chunks([
      for (final id in wanted)
        if (!out.containsKey(id)) id
    ])) {
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
        // each page is kept on disk like the rest of the account, so the
        // history and stats tabs open from it and refresh in the background
        rows = _list(await cachedGet(
          '/commerce/transactions/$kind',
          query: {'page_size': '200', 'page': '$page'},
          ttl: const Duration(minutes: 10),
        ));
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

  /// the newest page of one side of the history (history/sells or history/buys), as it is now and not from the disk: what a look for what completed needs.
  /// needs the tradingpost permission
  Future<List<Json>> recentTransactions(String kind) async =>
      _list(await get('/commerce/transactions/$kind', {'page_size': '200', 'page': '0'}));

  /// coins and items waiting to be picked up at a trading post npc
  Future<Json> delivery() async => _object(await get('/commerce/delivery'));

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

  /// full order book of one item, every price level with its quantity
  Future<Json?> listings(int itemId) async {
    try {
      return _object(await get('/commerce/listings/$itemId'));
    } on Gw2ApiException catch (e) {
      // untradeable items answer 404
      if (e.status == 404) return null;
      rethrow;
    }
  }
}
