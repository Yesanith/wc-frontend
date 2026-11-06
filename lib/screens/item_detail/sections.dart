part of '../item_detail_screen.dart';

/// how many the account has, and where each stack is
class _OwnedSection extends ConsumerWidget {
  const _OwnedSection({required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final places = ref.watch(ownedPlacesProvider).valueOrNull?[itemId];
    final total = places?.values.fold(0, (a, b) => a + b) ?? ref.watch(accountTotalsProvider).valueOrNull?[itemId] ?? 0;
    if (total == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Eyebrow(s.t('n_owned', {'n': fmtInt(total)})),
        if (places != null)
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final e in places.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Icon(placeIcon(e.key.kind), size: 18, color: AppColors.muted),
                        const SizedBox(width: 12),
                        Expanded(child: Text(placeLabel(s, e.key), style: const TextStyle(fontSize: 14))),
                        Text('×${fmtInt(e.value)}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// buy order and sell listing for the chosen quantity, and what flipping earns
class _PricePanel extends ConsumerWidget {
  const _PricePanel({required this.item, required this.itemId, required this.qty, required this.onQty});

  final Json? item;
  final int itemId;
  final int qty;
  final ValueChanged<int> onQty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final priced = ref.watch(priceProvider(itemId));
    // "not sold" only once the trading post has actually answered
    if (!priced.hasValue) return const SizedBox.shrink();
    final price = priced.value;
    final buys = price?['buys'];
    final sells = price?['sells'];
    final buy = buys is Map ? asInt(buys['unit_price']) : 0;
    final sell = sells is Map ? asInt(sells['unit_price']) : 0;
    final vendor = asInt(item?['vendor_value']);

    final stepper = Row(
      children: [
        Expanded(child: Kicker(s.t('quantity').toUpperCase(), color: AppColors.hint)),
        IconButton(
          // 1, 10 and 250 are the steps people trade in
          onPressed: qty > 1 ? () => onQty(qty == 250 ? 10 : (qty == 10 ? 1 : qty - 1)) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 44,
          child: Text('$qty',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        IconButton(
          onPressed: qty < 250 ? () => onQty(qty == 1 ? 10 : (qty == 10 ? 250 : qty + 1)) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );

    if (buy == 0 && sell == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('not_tradable'), style: TextStyle(fontSize: 14, color: AppColors.muted)),
            if (vendor > 0) ...[
              const SizedBox(height: 8),
              stepper,
              Row(
                children: [
                  Expanded(child: Text(s.t('vendor_value'), style: const TextStyle(fontSize: 14))),
                  CoinDots(vendor * qty),
                ],
              ),
            ],
          ],
        ),
      );
    }

    Widget side(String label, int unit, int count, String countLabel, Color accent) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 6),
                CoinDots(unit * qty, size: 16, weight: FontWeight.w800),
                const SizedBox(height: 6),
                Text('$countLabel ${compact(count)}', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        );

    // buy at the highest order, relist a copper under the lowest listing
    final flip = buy > 0 && sell > 0 ? afterTradingFees(sell - 1) - buy : 0;
    final margin = buy > 0 ? flip / buy : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stepper,
        const SizedBox(height: 4),
        Row(
          children: [
            side(s.t('highest_buy'), buy, buys is Map ? asInt(buys['quantity']) : 0, s.t('demand'), AppColors.blue),
            const SizedBox(width: 8),
            side(s.t('lowest_sell'), sell, sells is Map ? asInt(sells['quantity']) : 0, s.t('supply'), AppColors.gold),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('flip_profit'), style: const TextStyle(fontSize: 14)),
                  Text('${(margin * 100).round()}%', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            CoinDots(flip * qty, color: flip >= 0 ? AppColors.green : AppColors.red),
          ],
        ),
      ],
    );
  }
}

/// the equipped piece knows its chosen stats, otherwise fall back to the
/// fixed ones the item itself carries
List<Json> _attributes(Json? instance, Json? details) {
  final chosen = instance?['stats'];
  if (chosen is Map && chosen['attributes'] is Map) {
    final attributes = Map<String, dynamic>.from(chosen['attributes'] as Map);
    return [
      for (final e in attributes.entries) {'attribute': e.key, 'modifier': e.value},
    ];
  }
  final infix = details?['infix_upgrade'];
  if (infix is Map && infix['attributes'] is List) {
    return [
      for (final a in infix['attributes'] as List)
        if (a is Map) Map<String, dynamic>.from(a),
    ];
  }
  return const [];
}

class _UpgradeRow extends ConsumerWidget {
  const _UpgradeRow({required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemProvider(itemId)).valueOrNull;
    final name = (item?['name'] as String?) ?? s.t('item_n', {'id': itemId});
    final details = item?['details'] is Map ? Map<String, dynamic>.from(item!['details'] as Map) : null;
    final bonuses = [
      for (final b in (details?['bonuses'] as List?) ?? const []) '$b',
    ];
    final buff = details?['infix_upgrade'] is Map
        ? '${(details!['infix_upgrade'] as Map)['buff'] is Map ? ((details['infix_upgrade'] as Map)['buff'] as Map)['description'] ?? '' : ''}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => showItemDetails(context, itemId),
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  if (buff.isNotEmpty)
                    Text(buff.replaceAll(RegExp(r'<[^>]*>'), ''),
                        style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.muted)),
                  for (var i = 0; i < bonuses.length; i++)
                    Text('(${i + 1}) ${bonuses[i]}',
                        style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// the name of the stat combination, from the equipped piece or the item
String? _comboName(WidgetRef ref, Json? instance, Json? details) {
  final chosen = instance?['stats'];
  final infix = details?['infix_upgrade'];
  final id = chosen is Map ? asInt(chosen['id']) : (infix is Map ? asInt(infix['id']) : 0);
  if (id <= 0) return null;
  return ref.watch(itemStatsProvider).valueOrNull?[id];
}

/// what this item is an ingredient of. a few rows here, the rest a tap away
class _UsedInSection extends ConsumerWidget {
  const _UsedInSection({required this.itemId, required this.itemName});

  final int itemId;
  final String itemName;

  static const _preview = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rows = ref.watch(usedInProvider(itemId)).valueOrNull;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final preview = rows.take(_preview).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: s.t('used_in'), trailing: fmtInt(rows.length)),
          const SizedBox(height: 10),
          for (var i = 0; i < preview.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecipeOutputRow(entry: preview[i], chunkKey: chunkKeyFor(preview, i)),
            ),
          if (rows.length > _preview)
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecipeOutputsScreen(title: s.t('used_in_item', {'item': itemName}), entries: rows),
                ),
              ),
              child: Text(s.t('show_all_n', {'n': fmtInt(rows.length)})),
            ),
        ],
      ),
    );
  }
}
