import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/item_index.dart';
import '../util.dart';
import 'api.dart';
import '../services/gunzip.dart';

/// one item the trading post lists, with what the filters need. ships with
/// the app, built by the data workflow from every tradable item
class MarketEntry {
  const MarketEntry(this.id, this.type, this.subtype, this.rarity, this.level);

  final int id;
  final String type;
  final String subtype;
  final String rarity;
  final int level;
}

List<MarketEntry> parseMarketIndex(String raw) {
  final out = <MarketEntry>[];
  for (final line in const LineSplitter().convert(raw)) {
    final f = line.split('\t');
    if (f.length < 5) continue;
    final id = int.tryParse(f[0]);
    if (id == null) continue;
    out.add(MarketEntry(id, f[1], f[2], f[3], int.tryParse(f[4]) ?? 0));
  }
  return out;
}

List<MarketEntry> _unpack(List<int> gz) => parseMarketIndex(utf8.decode(gunzip(gz)));

final marketIndexProvider = FutureProvider<List<MarketEntry>>((ref) async {
  try {
    final data = await rootBundle.load('assets/data/market_index.txt.gz');
    return await compute(_unpack, data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  } catch (_) {
    // a build from before the index existed, the tab says so
    return const [];
  }
});

/// buy and sell side of one listing
class TpPrice {
  const TpPrice(this.buy, this.sell, this.demand, this.supply);

  factory TpPrice.fromJson(Json j) {
    final b = j['buys'] is Map ? j['buys'] as Map : const {};
    final s = j['sells'] is Map ? j['sells'] as Map : const {};
    return TpPrice(asInt(b['unit_price']), asInt(s['unit_price']), asInt(b['quantity']), asInt(s['quantity']));
  }

  final int buy;
  final int sell;
  final int demand;
  final int supply;

  /// buying at the top order and relisting a copper under the lowest listing,
  /// after the 5% listing fee and the 10% sale fee
  int get flip {
    if (buy <= 0 || sell <= 1) return 0;
    final price = sell - 1;
    return price - (price * 0.05).ceil() - (price * 0.10).ceil() - buy;
  }

  double get margin => buy <= 0 ? 0 : flip / buy;
}

/// how old the server's list may be and still be the prices now: it reads all of the trading post every ten minutes
const marketSnapshotMaxAge = Duration(minutes: 30);

/// whether a list the server made at [at] is recent enough
bool snapshotFresh(DateTime at, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(at);
  // a clock a few minutes ahead is not a reason to distrust it
  return age < marketSnapshotMaxAge && age > const Duration(minutes: -5);
}

/// the server's list of the prices of every item, and when it read them. null when it is not a list
({DateTime at, Map<int, TpPrice> prices})? parseServerSnapshot(dynamic raw) {
  if (raw is! Map) return null;
  final at = DateTime.tryParse('${raw['updated_at']}');
  final rows = raw['rows'];
  if (at == null || rows is! List || rows.isEmpty) return null;
  return (at: at, prices: decodeMarketPrices(rows));
}

/// the whole list of prices as the server read it: one request where the game takes a hundred and forty. anybody has it, signed in or
/// not. null when the server cannot be reached or has nothing yet
Future<({DateTime at, Map<int, TpPrice> prices})?> fetchServerSnapshot() async {
  final SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    return null;
  }
  return parseServerSnapshot(await client.rpc('tp_snapshot'));
}

/// how far the price download is, 0 to 1
final marketPricesProgressProvider = StateProvider<double>((ref) => 0);

/// how long the full price list is reused before the browse tab fetches it
/// again. about 140 requests each time, too many to repeat on every visit
const marketPricesTtl = Duration(minutes: 10);

/// the price of every tradable item: the server's list in one request, else the game's, a few requests at a time. refreshed by
/// pull to refresh only: an automatic timer kept downloading several
/// megabytes every few minutes while the tab sat behind another section.
/// released when the browse tab closes
final allPricesProvider = FutureProvider.autoDispose<Map<int, TpPrice>>((ref) async {
  final entries = await ref.watch(marketIndexProvider.future);
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  // a recent copy opens the tab instantly, pull to refresh skips it
  if (!api.forcing) {
    final cached = await cache?.read('market_prices', maxAge: marketPricesTtl);
    final rows = cached?['rows'];
    if (rows is List && rows.isNotEmpty) return decodeMarketPrices(rows);
  }
  // the server has read all of it lately: one request instead of a hundred and forty. the game is asked only when it has not
  try {
    final snapshot = await fetchServerSnapshot();
    if (snapshot != null && snapshotFresh(snapshot.at)) {
      Future(() => ref.read(marketPricesProgressProvider.notifier).state = 1);
      await cache?.write('market_prices', {'rows': encodeMarketPrices(snapshot.prices)});
      return snapshot.prices;
    }
  } catch (_) {
    // the server is a shortcut, never a need
  }
  final ids = [for (final e in entries) e.id];
  final chunks = [
    for (var i = 0; i < ids.length; i += 200) ids.sublist(i, i + 200 > ids.length ? ids.length : i + 200)
  ];
  final progress = ref.read(marketPricesProgressProvider.notifier);
  Future(() => progress.state = 0);
  final pool = TaskPool(6);
  var done = 0;
  final parts = await Future.wait(chunks.map((chunk) => pool.run(() async {
        final prices = await api.prices(chunk);
        done++;
        progress.state = done / chunks.length;
        return prices;
      })));
  final out = <int, TpPrice>{};
  for (final part in parts) {
    for (final e in part.entries) {
      out[e.key] = TpPrice.fromJson(e.value);
    }
  }
  await cache?.write('market_prices', {'rows': encodeMarketPrices(out)});
  return out;
});

/// compact rows for the disk copy: [id, buy, sell, demand, supply]
List<List<int>> encodeMarketPrices(Map<int, TpPrice> prices) => [
      for (final e in prices.entries) [e.key, e.value.buy, e.value.sell, e.value.demand, e.value.supply],
    ];

Map<int, TpPrice> decodeMarketPrices(List<dynamic> rows) => {
      for (final r in rows)
        if (r is List && r.length >= 5) asInt(r[0]): TpPrice(asInt(r[1]), asInt(r[2]), asInt(r[3]), asInt(r[4])),
    };

enum MarketSort { sellHigh, sellLow, supply, demand, flip, name }

class MarketFilter {
  const MarketFilter({
    this.query = '',
    this.type,
    this.subtype,
    this.rarities = const {},
    this.minLevel = 0,
    this.maxLevel = 80,
    this.sort = MarketSort.demand,
    this.minSupply = 0,
  });

  final String query;
  final String? type;
  final String? subtype;
  final Set<String> rarities;
  final int minLevel;
  final int maxLevel;
  final MarketSort sort;

  /// leaves out listings nobody can buy from
  final int minSupply;

  MarketFilter copyWith({
    String? query,
    String? Function()? type,
    String? Function()? subtype,
    Set<String>? rarities,
    int? minLevel,
    int? maxLevel,
    MarketSort? sort,
    int? minSupply,
  }) =>
      MarketFilter(
        query: query ?? this.query,
        type: type == null ? this.type : type(),
        subtype: subtype == null ? this.subtype : subtype(),
        rarities: rarities ?? this.rarities,
        minLevel: minLevel ?? this.minLevel,
        maxLevel: maxLevel ?? this.maxLevel,
        sort: sort ?? this.sort,
        minSupply: minSupply ?? this.minSupply,
      );
}

/// the ids that pass the filter, in the chosen order. prices may still be
/// loading, then the price sorts fall back to the name
List<int> filterMarket(
  List<MarketEntry> entries,
  MarketFilter f, {
  required String? Function(int id) nameOf,
  Map<int, TpPrice>? prices,
}) {
  final words = f.query.trim().toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final hits = <MarketEntry>[];
  for (final e in entries) {
    if (f.type != null && e.type != f.type) continue;
    if (f.subtype != null && e.subtype != f.subtype) continue;
    if (f.rarities.isNotEmpty && !f.rarities.contains(e.rarity)) continue;
    if (e.level < f.minLevel || e.level > f.maxLevel) continue;
    if (words.isNotEmpty) {
      final name = (nameOf(e.id) ?? '').toLowerCase();
      if (!words.every(name.contains)) continue;
    }
    if (prices != null && f.minSupply > 0 && (prices[e.id]?.supply ?? 0) < f.minSupply) continue;
    hits.add(e);
  }
  String name(MarketEntry e) => nameOf(e.id) ?? '';

  /// items without a price, or without the side being sorted on, go last
  /// whichever way the list runs
  int by(int Function(TpPrice p) pick, MarketEntry a, MarketEntry b, {bool descending = true}) {
    final pa = prices?[a.id];
    final pb = prices?[b.id];
    final va = pa == null ? 0 : pick(pa);
    final vb = pb == null ? 0 : pick(pb);
    if ((va > 0) != (vb > 0)) return va > 0 ? -1 : 1;
    return descending ? vb.compareTo(va) : va.compareTo(vb);
  }

  final sort = prices == null && f.sort != MarketSort.name ? MarketSort.name : f.sort;
  hits.sort((a, b) => switch (sort) {
        MarketSort.sellHigh => by((p) => p.sell, a, b),
        MarketSort.sellLow => by((p) => p.sell, a, b, descending: false),
        MarketSort.supply => by((p) => p.supply, a, b),
        MarketSort.demand => by((p) => p.demand, a, b),
        MarketSort.flip => by((p) => p.flip, a, b),
        MarketSort.name => name(a).compareTo(name(b)),
      });
  return [for (final e in hits) e.id];
}

/// the item names to search with, from the index the app already ships
String? Function(int) namesFrom(ItemIndex? index) => (id) => index?.nameOf(id);
