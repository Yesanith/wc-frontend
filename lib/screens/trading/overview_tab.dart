part of '../trading_screen.dart';

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rates = ref.watch(gemRatesProvider);
    final delivery = ref.watch(deliveryProvider);
    final watch = ref.watch(watchlistPricesProvider);

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () =>
          refreshProviders(ref, [triggeredAlertsProvider, gemRatesProvider, deliveryProvider, watchlistPricesProvider]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const ItemSearchField(),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(s.t('gem_exchange').toUpperCase()),
                const SizedBox(height: 12),
                AsyncView<GemRates>(
                  value: rates,
                  onRetry: () => ref.invalidate(gemRatesProvider),
                  builder: (r) => Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t('gems_to_gold'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            const SizedBox(height: 4),
                            CoinText(r.coinsFor100Gems, size: 17),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t('gold_to_gems'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            const SizedBox(height: 4),
                            Text(s.t('n_gems', {'n': fmtInt(r.gemsFor100Gold)}),
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _GemHistoryChart(),
          const SizedBox(height: 14),
          const _GemCalculator(),
          const SizedBox(height: 14),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(s.t('delivery').toUpperCase()),
                const SizedBox(height: 12),
                AsyncView<Delivery>(
                  permission: 'tradingpost',
                  value: delivery,
                  onRetry: () => ref.invalidate(deliveryProvider),
                  builder: (d) {
                    if (d.coins == 0 && d.items.isEmpty) {
                      return Text(s.t('delivery_empty'), style: TextStyle(color: AppColors.muted));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CoinText(d.coins, size: 20),
                        if (d.items.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final it in d.items)
                                GestureDetector(
                                  onTap: () => showItemSheet(
                                    context,
                                    id: it.id,
                                    name: it.name,
                                    icon: it.icon,
                                    rarity: it.rarity,
                                    type: it.type,
                                    count: it.count,
                                  ),
                                  child: ItemIcon(url: it.icon, rarity: it.rarity, count: it.count, size: 42),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(s.t('pickup_note'), style: TextStyle(fontSize: 12, color: AppColors.hint)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: s.t('watchlist')),
          const SizedBox(height: 10),
          AsyncView<List<WatchedItem>>(
            value: watch,
            onRetry: () => ref.invalidate(watchlistPricesProvider),
            builder: (items) => items.isEmpty
                ? Panel(
                    child: Text(s.t('watchlist_empty'), style: TextStyle(color: AppColors.muted, height: 1.5)))
                : Column(
                    children: [
                      for (final w in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: WatchRow(w)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// item search over the shipped index, the api cannot search by name
class ItemSearchField extends ConsumerStatefulWidget {
  const ItemSearchField({super.key});

  @override
  ConsumerState<ItemSearchField> createState() => _ItemSearchFieldState();
}

class _ItemSearchFieldState extends ConsumerState<ItemSearchField> {
  final _ctrl = TextEditingController();
  List<IndexedItem> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Timer? _debounce;

  // typing fast should not scan the whole index on every key
  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final index = ref.read(itemIndexProvider).valueOrNull ?? ItemIndex.empty;
      setState(() => _results = index.search(q, limit: 20));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final index = ref.watch(itemIndexProvider);

    return Column(
      children: [
        TextField(
          controller: _ctrl,
          onChanged: _search,
          decoration: fieldDecoration(
            s.t('search_items'),
            prefixIcon: Icon(Icons.search, color: AppColors.gold),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close, color: AppColors.muted),
                    onPressed: () {
                      _ctrl.clear();
                      _search('');
                    },
                  ),
          ),
        ),
        if (index.isLoading) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(minHeight: 2, color: AppColors.gold),
        ],
        if (index.valueOrNull?.isEmpty ?? false) ...[
          const SizedBox(height: 8),
          Text(s.t('no_item_index'), style: TextStyle(fontSize: 12, color: AppColors.hint)),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SearchResults(ids: [for (final item in _results.take(20)) item.id]),
        ],
      ],
    );
  }
}

/// search hits with their icon and current price, fetched together
class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.ids});

  final List<int> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final key = ids.join(',');
    final items = ref.watch(itemBatchProvider(key)).valueOrNull ?? const <int, Json>{};
    final prices = ref.watch(priceBatchProvider(key)).valueOrNull ?? const <int, Json>{};
    final index = ref.watch(itemIndexProvider).valueOrNull;
    return Column(
      children: [
        for (final id in ids)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ItemTile(
              itemId: id,
              item: items[id],
              title: (items[id]?['name'] as String?) ?? index?.nameOf(id) ?? s.t('item_n', {'id': id}),
              trailing: prices[id] == null
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CoinText(TpPrice.fromJson(prices[id]!).sell, size: 14),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${s.t('buy_short')} ', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                            CoinText(TpPrice.fromJson(prices[id]!).buy, size: 11),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}
