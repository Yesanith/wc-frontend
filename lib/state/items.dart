import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'api.dart';
import 'price_history.dart';

final itemProvider = FutureProvider.autoDispose.family<Json?, int>((ref, id) async {
  final items = await ref.watch(gw2ApiProvider).items([id]);
  return items[id];
});

final priceProvider = FutureProvider.autoDispose.family<Json?, int>((ref, id) async {
  final history = ref.read(priceHistoryProvider.notifier);
  final prices = await ref.watch(gw2ApiProvider).prices([id]);
  // an item page adds today's point too, the history keeps it a month
  Future(() => history.record(prices));
  return prices[id];
});

/// details for a group of items at once, keyed by their ids joined with
/// commas. the api client caches them on disk, so this is paid once
final itemBatchProvider = FutureProvider.autoDispose.family<Map<int, Json>, String>((ref, key) async {
  final ids = [
    for (final part in key.split(','))
      if (int.tryParse(part) != null) int.parse(part),
  ];
  if (ids.isEmpty) return const {};
  return ref.watch(gw2ApiProvider).items(ids);
});

/// prices for a group of items, keyed like [itemBatchProvider]. not cached,
/// prices move
final priceBatchProvider = FutureProvider.autoDispose.family<Map<int, Json>, String>((ref, key) async {
  final ids = [
    for (final part in key.split(','))
      if (int.tryParse(part) != null) int.parse(part),
  ];
  if (ids.isEmpty) return const {};
  return ref.watch(gw2ApiProvider).prices(ids);
});

/// the ids around [index] in pages of [size], joined into a batch key. a long
/// list asks for its items a page at a time instead of one by one
String pageKey(List<int> ids, int index, [int size = 40]) {
  final start = index ~/ size * size;
  final end = start + size > ids.length ? ids.length : start + size;
  return ids.sublist(start, end).join(',');
}
