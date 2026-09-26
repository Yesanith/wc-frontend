import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'api.dart';
import 'settings.dart';

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

/// gem exchange in both directions. key is "gems:100" or "coins:1000000"
final exchangeProvider = FutureProvider.autoDispose.family<int, String>((ref, key) async {
  final api = ref.watch(gw2ApiProvider);
  final parts = key.split(':');
  final amount = int.tryParse(parts.last) ?? 0;
  if (amount <= 0) return 0;
  return parts.first == 'gems' ? api.coinsForGems(amount) : api.gemsForCoins(amount);
});
