import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'api.dart';

final itemProvider = FutureProvider.autoDispose.family<Json?, int>((ref, id) async {
  final items = await ref.watch(gw2ApiProvider).items([id]);
  return items[id];
});

final priceProvider = FutureProvider.autoDispose.family<Json?, int>((ref, id) async {
  final prices = await ref.watch(gw2ApiProvider).prices([id]);
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
