import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'api.dart';

final itemProvider = FutureProvider.family<Json?, int>((ref, id) async {
  final items = await ref.watch(gw2ApiProvider).items([id]);
  return items[id];
});

final priceProvider = FutureProvider.family<Json?, int>((ref, id) async {
  final prices = await ref.watch(gw2ApiProvider).prices([id]);
  return prices[id];
});
