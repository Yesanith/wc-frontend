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
                            Text(s.t('gems_to_gold'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            const SizedBox(height: 4),
                            CoinText(r.coinsFor100Gems, size: 17),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.t('gold_to_gems'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
                      return Text(s.t('delivery_empty'), style: const TextStyle(color: AppColors.muted));
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
                        Text(s.t('pickup_note'), style: const TextStyle(fontSize: 12, color: AppColors.hint)),
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
                    child: Text(s.t('watchlist_empty'), style: const TextStyle(color: AppColors.muted, height: 1.5)))
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
            prefixIcon: const Icon(Icons.search, color: AppColors.gold),
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed: () {
                      _ctrl.clear();
                      _search('');
                    },
                  ),
          ),
        ),
        if (index.isLoading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2, color: AppColors.gold),
        ],
        if (index.valueOrNull?.isEmpty ?? false) ...[
          const SizedBox(height: 8),
          Text(s.t('no_item_index'), style: const TextStyle(fontSize: 12, color: AppColors.hint)),
        ],
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SearchResults(ids: [for (final item in _results.take(20)) item.id]),
        ],
      ],
    );
  }
}

/// two way gem exchange for any amount
class _GemCalculator extends ConsumerStatefulWidget {
  const _GemCalculator();

  @override
  ConsumerState<_GemCalculator> createState() => _GemCalculatorState();
}

class _GemCalculatorState extends ConsumerState<_GemCalculator> {
  final _gems = TextEditingController(text: '400');
  final _gold = TextEditingController(text: '100');
  int _gemAmount = 400;
  int _goldAmount = 100;

  /// typing 10000 would ask the exchange five times, the last number is enough
  Timer? _debounce;

  void _later(void Function() update) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(update);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _gems.dispose();
    _gold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final coins = ref.watch(exchangeProvider('gems:$_gemAmount'));
    final gems = ref.watch(exchangeProvider('coins:${_goldAmount * 10000}'));

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('gem_calculator').toUpperCase()),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _gems,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (v) => setState(() => _gemAmount = int.tryParse(v) ?? 0),
                  onChanged: (v) => _later(() => _gemAmount = int.tryParse(v) ?? 0),
                  decoration: fieldDecoration(s.t('gems')),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward, size: 18, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: coins.when(
                  data: (value) => CoinText(value, size: 16),
                  loading: () => const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                  ),
                  error: (_, __) => const Text('-', style: TextStyle(color: AppColors.muted)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _gold,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (v) => setState(() => _goldAmount = int.tryParse(v) ?? 0),
                  onChanged: (v) => _later(() => _goldAmount = int.tryParse(v) ?? 0),
                  decoration: fieldDecoration(s.t('gold')),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward, size: 18, color: AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: gems.when(
                  data: (value) => Text(s.t('n_gems', {'n': fmtInt(value)}),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  loading: () => const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                  ),
                  error: (_, __) => const Text('-', style: TextStyle(color: AppColors.muted)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.t('exchange_note'), style: const TextStyle(fontSize: 11, color: AppColors.hint)),
        ],
      ),
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
                            Text('${s.t('buy_short')} ', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
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

/// a month of what 100 gems cost and bring, from the shared recording
class _GemHistoryChart extends ConsumerWidget {
  const _GemHistoryChart();

  static const _buyColor = AppColors.gold;
  static const _sellColor = Color(0xFF6FB7E0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final points = ref.watch(gemHistoryProvider).valueOrNull ?? const <GemPoint>[];
    Widget legend(Color color, String label, int value) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 3, color: color),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(width: 6),
            CoinText(value, size: 12),
          ],
        );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(s.t('gem_history_title').toUpperCase()),
          const SizedBox(height: 12),
          if (points.length < 2)
            Text(s.t('gem_history_collecting'),
                style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted))
          else ...[
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(painter: _GemChartPainter(points, _buyColor, _sellColor)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(_shortDate(points.first.at), style: const TextStyle(fontSize: 10, color: AppColors.hint)),
                const Spacer(),
                Text(_shortDate(points.last.at), style: const TextStyle(fontSize: 10, color: AppColors.hint)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                legend(_buyColor, s.t('gem_buy_100'), points.last.buy),
                legend(_sellColor, s.t('gem_sell_100'), points.last.sell),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.t('gem_range', {
                'lo': fmtGold(points.map((p) => p.buy).reduce((a, b) => a < b ? a : b)),
                'hi': fmtGold(points.map((p) => p.buy).reduce((a, b) => a > b ? a : b)),
              }),
              style: const TextStyle(fontSize: 11, color: AppColors.hint),
            ),
          ],
        ],
      ),
    );
  }
}

String _shortDate(DateTime d) {
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}';
}

/// whole gold with one decimal, enough for a range line
String fmtGold(int copper) => (copper / 10000).toStringAsFixed(1);

class _GemChartPainter extends CustomPainter {
  const _GemChartPainter(this.points, this.buyColor, this.sellColor);

  final List<GemPoint> points;
  final Color buyColor;
  final Color sellColor;

  @override
  void paint(Canvas canvas, Size size) {
    var lo = points.first.sell;
    var hi = points.first.buy;
    for (final p in points) {
      if (p.sell < lo) lo = p.sell;
      if (p.buy < lo) lo = p.buy;
      if (p.buy > hi) hi = p.buy;
      if (p.sell > hi) hi = p.sell;
    }
    final span = (hi - lo) == 0 ? 1 : hi - lo;
    final first = points.first.at.millisecondsSinceEpoch;
    final range = (points.last.at.millisecondsSinceEpoch - first).clamp(1, 9007199254740991);
    final grid = Paint()
      ..color = AppColors.track
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), grid);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), grid);
    // a little air above and below the lines
    double y(int v) => size.height - 4 - (v - lo) / span * (size.height - 8);
    double x(GemPoint p) => size.width * (p.at.millisecondsSinceEpoch - first) / range;
    void line(int Function(GemPoint) pick, Color color) {
      final path = Path()..moveTo(x(points.first), y(pick(points.first)));
      for (final p in points.skip(1)) {
        path.lineTo(x(p), y(pick(p)));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    line((p) => p.sell, sellColor);
    line((p) => p.buy, buyColor);
  }

  @override
  bool shouldRepaint(covariant _GemChartPainter old) => old.points != points;
}
