import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';
import 'community.dart';

/// an item whose price moved: what it sells for now, what it did then, and by how much (0.2 is a fifth up)
class MarketMove {
  const MarketMove({required this.itemId, required this.sell, required this.before, required this.change});

  final int itemId;
  final int sell;
  final int before;
  final double change;
}

/// what rose and what fell over a span of days
class MarketMovers {
  const MarketMovers(this.risers, this.fallers, this.updatedAt);

  final List<MarketMove> risers;
  final List<MarketMove> fallers;
  final DateTime? updatedAt;

  bool get isEmpty => risers.isEmpty && fallers.isEmpty;
}

List<MarketMove> _moves(dynamic list) => [
      if (list is List)
        for (final m in list)
          if (m is Map && asInt(m['item_id']) > 0)
            MarketMove(
              itemId: asInt(m['item_id']),
              sell: asInt(m['sell']),
              before: asInt(m['before']),
              change: (m['change'] as num?)?.toDouble() ?? 0,
            ),
    ];

/// the answer of `tp_movers`
MarketMovers parseMarketMovers(dynamic raw) {
  if (raw is! Map) return const MarketMovers([], [], null);
  return MarketMovers(_moves(raw['risers']), _moves(raw['fallers']), DateTime.tryParse('${raw['updated_at']}'));
}

/// the risers and fallers of the trading post over 1, 7 or 30 days, as the server ranks them from its history of prices
final marketMoversProvider = FutureProvider.autoDispose.family<MarketMovers, int>((ref, days) async {
  if (!communityReady) return const MarketMovers([], [], null);
  final raw = await Supabase.instance.client.rpc('tp_movers', params: {'p_days': days, 'p_limit': 30});
  return parseMarketMovers(raw);
});
