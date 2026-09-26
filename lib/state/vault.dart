import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'api.dart';

/// the running wizard's vault season: title and dates
final vaultSeasonProvider = FutureProvider<Json>((ref) => ref.watch(gw2ApiProvider).vaultSeason());

class VaultListing {
  const VaultListing({
    required this.itemId,
    required this.count,
    required this.type,
    required this.cost,
    required this.purchased,
    required this.limit,
    required this.item,
  });

  final int itemId;
  final int count;

  /// Featured, Normal or Legacy
  final String type;
  final int cost;
  final int purchased;

  /// 0 means unlimited
  final int limit;
  final Json? item;

  bool get soldOut => limit > 0 && purchased >= limit;
  String get name => (item?['name'] as String?) ?? 'Item #$itemId';
}

const _typeOrder = {'Featured': 0, 'Normal': 1, 'Legacy': 2};

/// the astral reward shop with this account's purchases, featured first
final vaultListingsProvider = FutureProvider<List<VaultListing>>((ref) async {
  final api = accountApi(ref);
  final rows = await api.vaultListings();
  final items = await api.items(rows.map((r) => asInt(r['item_id'])));
  final out = [
    for (final r in rows)
      VaultListing(
        itemId: asInt(r['item_id']),
        count: asInt(r['item_count']) <= 0 ? 1 : asInt(r['item_count']),
        type: '${r['type'] ?? 'Normal'}',
        cost: asInt(r['cost']),
        purchased: asInt(r['purchased']),
        limit: asInt(r['purchase_limit']),
        item: items[asInt(r['item_id'])],
      ),
  ];
  return sortVaultListings(out);
});

/// featured first, then the regular rewards, then legacy ones, each by price
List<VaultListing> sortVaultListings(List<VaultListing> listings) {
  return [...listings]
    ..sort((a, b) {
      final byType = (_typeOrder[a.type] ?? 9).compareTo(_typeOrder[b.type] ?? 9);
      return byType != 0 ? byType : a.cost.compareTo(b.cost);
    });
}
