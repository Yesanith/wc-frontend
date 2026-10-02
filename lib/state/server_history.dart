import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'price_history.dart';
import 'server_prices.dart';

/// what the server has kept of the prices of an item. it starts when somebody first asks for the item, so a new item has a few days
final serverHistoryProvider = FutureProvider.autoDispose.family<List<PricePoint>, int>((ref, id) async {
  try {
    return await fetchServerHistory(id);
  } catch (_) {
    // the device's own history is still there
    return const [];
  }
});
