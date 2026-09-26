part of '../trading_screen.dart';

class TradingItemScreen extends ConsumerWidget {
  const TradingItemScreen({super.key, required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemProvider(itemId)).valueOrNull;
    final price = ref.watch(priceProvider(itemId));
    final totals = ref.watch(accountTotalsProvider);
    final watched = ref.watch(watchlistProvider).contains(itemId);
    final name = (item?['name'] as String?) ?? s.t('item_n', {'id': itemId});
    final rarity = item?['rarity'] as String?;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('trading_post'), style: display(20)),
        actions: [
          IconButton(
            tooltip: s.t('price_alert'),
            onPressed: () => showPriceAlertDialog(context, ref, itemId, name),
            icon: Icon(
              ref.watch(priceAlertsProvider).containsKey(itemId) ? Icons.notifications_active : Icons.notifications_none,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () => refreshProviders(ref, [priceProvider(itemId)]),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                ItemIcon(url: item?['icon'] as String?, rarity: rarity, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        [if (rarity != null) rarity, if (item?['type'] != null) '${item?['type']}'].join(' · '),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: rarityColor(rarity)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AsyncView<Json?>(
              value: price,
              onRetry: () => ref.invalidate(priceProvider(itemId)),
              builder: (p) => p == null
                  ? Panel(child: Text(s.t('not_tradeable'), style: const TextStyle(color: AppColors.muted)))
                  : _PricePanel(p),
            ),
            const SizedBox(height: 12),
            _OrderBook(itemId: itemId),
            const SizedBox(height: 12),
            Panel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.t('you_own'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
                  ),
                  totals.when(
                    data: (t) => Text(fmtInt(t[itemId] ?? 0),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.gold)),
                    loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => const Text('-'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => ref.read(watchlistProvider.notifier).toggle(itemId),
                    icon: Icon(watched ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    label: Text(watched ? s.t('unwatch') : s.t('watch')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openWikiPage(context, ref, name),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(s.t('wiki')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(s.t('tp_note'), style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.hint)),
          ],
        ),
      ),
    );
  }
}

class _PricePanel extends ConsumerWidget {
  const _PricePanel(this.p);

  final Json p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final buys = p['buys'] is Map ? p['buys'] as Map : const {};
    final sells = p['sells'] is Map ? p['sells'] as Map : const {};
    final buy = asInt(buys['unit_price']);
    final sell = asInt(sells['unit_price']);
    // the tp keeps 15% of the sale (5% listing + 10% exchange)
    final profit = (sell * 0.85).floor() - buy;

    Widget col(String label, int value, int qty) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 4),
              CoinText(value, size: 20),
              const SizedBox(height: 2),
              Text(s.t('n_listed', {'n': fmtInt(qty)}), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        );

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              col(s.t('highest_buy'), buy, asInt(buys['quantity'])),
              col(s.t('lowest_sell'), sell, asInt(sells['quantity'])),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.track, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(s.t('flip_profit'), style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
              ),
              CoinText(profit, size: 15),
            ],
          ),
        ],
      ),
    );
  }
}

/// the first price levels on both sides of the market, with the quantity
/// waiting at each price
final _listingsProvider = FutureProvider.autoDispose.family<Json?, int>((ref, id) => ref.watch(gw2ApiProvider).listings(id));

class _OrderBook extends ConsumerWidget {
  const _OrderBook({required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final book = ref.watch(_listingsProvider(itemId)).valueOrNull;
    if (book == null) return const SizedBox.shrink();
    List<Json> side(String key) => [
          for (final row in (book[key] as List?) ?? const [])
            if (row is Map) Map<String, dynamic>.from(row),
        ].take(5).toList();
    final sells = side('sells');
    final buys = side('buys');
    if (sells.isEmpty && buys.isEmpty) return const SizedBox.shrink();

    Widget column(String title, List<Json> rows, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.muted)),
              const SizedBox(height: 6),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: CoinText(asInt(r['unit_price']), size: 12)),
                      Text(fmtInt(asInt(r['quantity'])),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                    ],
                  ),
                ),
            ],
          ),
        );

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('order_book').toUpperCase()),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column(s.t('sell_orders'), sells, AppColors.red),
              const SizedBox(width: 16),
              column(s.t('buy_orders'), buys, AppColors.green),
            ],
          ),
        ],
      ),
    );
  }
}


/// set or clear the price alert of one item, prices typed in gold
Future<void> showPriceAlertDialog(BuildContext context, WidgetRef ref, int itemId, String name) async {
  final s = ref.read(stringsProvider);
  final current = ref.read(priceAlertsProvider)[itemId];
  final sell = TextEditingController(text: current?.sellBelow == null ? '' : copperToGold(current!.sellBelow!));
  final buy = TextEditingController(text: current?.buyAbove == null ? '' : copperToGold(current!.buyAbove!));
  final result = await showDialog<PriceAlert?>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(s.t('price_alert')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: sell,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: fieldDecoration(s.t('alert_sell_below')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: buy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: fieldDecoration(s.t('alert_buy_above')),
          ),
          const SizedBox(height: 8),
          Text(s.t('alert_in_gold'), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
      actions: [
        if (current != null)
          TextButton(onPressed: () => Navigator.of(ctx).pop(const PriceAlert()), child: Text(s.t('remove'))),
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.t('cancel'))),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(
            PriceAlert(sellBelow: goldToCopper(sell.text), buyAbove: goldToCopper(buy.text)),
          ),
          child: Text(s.t('save_alert')),
        ),
      ],
    ),
  );
  sell.dispose();
  buy.dispose();
  // null means cancelled, an empty alert means remove
  if (result != null) await ref.read(priceAlertsProvider.notifier).set(itemId, result);
}
