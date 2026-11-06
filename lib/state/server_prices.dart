import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';
import 'price_history.dart';

/// the prices the server has read of items, in the shape the game gives them, each with when it was read. none when nobody is signed in or
/// the server cannot be reached: it is a shortcut, the game is asked for what it does not have. the server reads an item from the
/// first time it is asked for, so the first time an item is asked for it is not there yet
Future<List<Json>> fetchServerPrices(List<int> ids) async {
  final SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    return const [];
  }
  if (client.auth.currentSession == null || ids.isEmpty) return const [];
  return parseServerPrices(await client.rpc('tp_prices', params: {'p_ids': ids}));
}

/// the rows of the server's answer that are prices
List<Json> parseServerPrices(dynamic raw) => [
  for (final e in (raw is List ? raw : const []))
    if (e is Map && e['id'] != null) Map<String, dynamic>.from(e),
];

/// the history the server keeps of an item, one point a day, oldest first. none when nobody is signed in or the server cannot be reached
Future<List<PricePoint>> fetchServerHistory(int itemId, {int days = 180}) async {
  final SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    return const [];
  }
  if (client.auth.currentSession == null) return const [];
  return parseServerHistory(await client.rpc('tp_history', params: {'p_id': itemId, 'p_days': days}));
}

/// the points of the server's answer, in the order of the days
List<PricePoint> parseServerHistory(dynamic raw) {
  final points = [
    for (final e in (raw is List ? raw : const []))
      if (e is Map && '${e['d']}'.length >= 10) PricePoint('${e['d']}'.substring(0, 10), asInt(e['b']), asInt(e['s'])),
  ];
  points.sort((a, b) => a.day.compareTo(b.day));
  return points;
}
