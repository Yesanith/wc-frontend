part of '../trading_screen.dart';

// -------------------------------------------------------------------------
// the trading post on a site

/// a small line of how a price went, drawn without axes
class _Spark extends StatelessWidget {
  const _Spark({required this.values});

  final List<int> values;

  static const width = 110.0;
  static const height = 28.0;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox(width: width, height: height);
    return CustomPaint(size: const Size(width, height), painter: _SparkPainter(values, AppColors.gold));
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce((a, b) => a < b ? a : b).toDouble();
    final hi = values.reduce((a, b) => a > b ? a : b).toDouble();
    final span = hi - lo == 0 ? 1.0 : hi - lo;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - 2 - (values[i] - lo) / span * (size.height - 4);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values || old.color != color;
}

Widget _kicker(String text) => Text(text.caps,
    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.muted));

/// a box of a figure under its label, in a row of boxes
Widget _statBox(String label, Widget value, [String note = '']) => Expanded(
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker(label),
            const SizedBox(height: 4),
            value,
            if (note.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(note,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ],
        ),
      ),
    );

/// the heading row of a table on a site, tinted
Widget _tableHead(List<(String, double?)> columns) => Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: Color.alphaBlend(AppColors.track.withValues(alpha: 0.5), AppColors.surface),
      child: Row(
        children: [
          for (final (label, width) in columns)
            width == null
                ? Expanded(child: _kicker(label))
                : SizedBox(width: width, child: Align(alignment: Alignment.centerRight, child: _kicker(label))),
        ],
      ),
    );

/// the overview: what waits for pickup and the watchlist with how its prices went at the left, the exchange and the orders at the right
class _OverviewSite extends ConsumerWidget {
  const _OverviewSite();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final delivery = ref.watch(deliveryProvider);
    final watch = ref.watch(watchlistPricesProvider);
    final rates = ref.watch(gemRatesProvider);
    final buying = ref.watch(transactionsProvider('current/buys')).valueOrNull;
    final selling = ref.watch(transactionsProvider('current/sells')).valueOrNull;
    final history = ref.watch(priceHistoryProvider);

    final pickup = Panel(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('delivery'), style: display(18)),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kicker(s.t('coin_waiting')),
                          const SizedBox(height: 4),
                          CoinText(d.coins, size: 26)
                        ],
                      ),
                      if (d.items.isNotEmpty) ...[
                        const SizedBox(width: 24),
                        Container(width: 1, height: 44, color: AppColors.line),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final it in d.items.take(8))
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
                                  child: ItemIcon(url: it.icon, rarity: it.rarity, count: it.count, size: 44),
                                ),
                              if (d.items.length > 8)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text('+${d.items.length - 8}', style: TextStyle(color: AppColors.muted)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(s.t('pickup_note'), style: TextStyle(fontSize: 12, color: AppColors.hint)),
                ],
              );
            },
          ),
        ],
      ),
    );

    final watchlist = Panel(
      padding: EdgeInsets.zero,
      child: AsyncView<List<WatchedItem>>(
        value: watch,
        onRetry: () => ref.invalidate(watchlistPricesProvider),
        builder: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
              child: Row(
                children: [
                  Expanded(child: Text(s.t('watchlist'), style: display(18))),
                  Text(s.t('n_items', {'n': items.length}), style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                child: Text(s.t('watchlist_empty'), style: TextStyle(color: AppColors.muted, height: 1.5)),
              )
            else ...[
              _tableHead([
                (s.t('item'), null),
                (s.t('days_30'), 130),
                (s.t('tp_col_sell'), 120),
                (s.t('tp_col_buy'), 120),
                (s.t('day'), 90)
              ]),
              for (final w in items)
                Builder(builder: (context) {
                  final sells = w.price?['sells'] is Map ? w.price!['sells'] as Map : const {};
                  final buys = w.price?['buys'] is Map ? w.price!['buys'] as Map : const {};
                  final month = lastDays(history[w.id] ?? const <PricePoint>[], 30);
                  // the change of a day: from yesterday's point to today's (the points of the last day alone are only today's one)
                  final change = percentChange(lastDays(history[w.id] ?? const <PricePoint>[], 2), (p) => p.sell);
                  return InkWell(
                    onTap: () => openPanel(context, (_) => TradingItemScreen(itemId: w.id)),
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                ItemIcon(
                                    url: w.item?['icon'] as String?, rarity: w.item?['rarity'] as String?, size: 34),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text((w.item?['name'] as String?) ?? s.t('item_n', {'id': w.id}),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                              width: 130,
                              child: Align(
                                  alignment: Alignment.centerRight,
                                  child: _Spark(values: [for (final p in month) p.sell].where((v) => v > 0).toList()))),
                          _siteCell(CoinText(asInt(sells['unit_price']), size: 13.5), 120),
                          _siteCell(CoinText(asInt(buys['unit_price']), size: 13.5), 120),
                          _siteCell(
                              Text(
                                  change == null
                                      ? '–'
                                      : '${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(1)}%',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: change == null
                                          ? AppColors.muted
                                          : (change >= 0 ? AppColors.green : AppColors.red))),
                              90),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );

    final exchange = Panel(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('gem_exchange'), style: display(18)),
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
          const SizedBox(height: 14),
          const _GemCalculator(),
        ],
      ),
    );

    final orders = Panel(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('orders'), style: display(18)),
          const SizedBox(height: 12),
          Row(
            children: [
              _statBox(s.t('buying'), Text(buying == null ? '–' : '${buying.length}', style: display(26))),
              const SizedBox(width: 12),
              _statBox(s.t('selling'), Text(selling == null ? '–' : '${selling.length}', style: display(26))),
            ],
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const ItemSearchField(),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            exchange,
            const SizedBox(height: 16),
            const _GemHistoryChart(),
            const SizedBox(height: 16),
            orders
          ]);
          final left = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [pickup, const SizedBox(height: 16), watchlist]);
          if (box.maxWidth < 960) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 16), right]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(flex: 3, child: left), const SizedBox(width: 16), Expanded(flex: 2, child: right)],
          );
        }),
      ],
    );
  }
}

/// what is being bought and what is being sold, two lists side by side with their totals above
class _OrdersSite extends ConsumerWidget {
  const _OrdersSite();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final buys = ref.watch(transactionsProvider('current/buys'));
    final sells = ref.watch(transactionsProvider('current/sells'));
    int total(List<TxRow>? rows) =>
        (rows ?? const <TxRow>[]).fold<int>(0, (n, r) => n + asInt(r.tx['price']) * asInt(r.tx['quantity']));

    Widget list(String title, AsyncValue<List<TxRow>> value, String kind) => Panel(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: display(18))),
                  Text(s.t('n_orders', {'n': value.valueOrNull?.length ?? 0}),
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 6),
              AsyncView<List<TxRow>>(
                permission: 'tradingpost',
                value: value,
                onRetry: () => ref.invalidate(transactionsProvider(kind)),
                builder: (rows) => rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(s.t('nothing_here'), style: TextStyle(color: AppColors.muted)),
                      )
                    : Column(
                        children: [
                          for (final r in rows)
                            InkWell(
                              onTap: () => openPanel(context, (_) => TradingItemScreen(itemId: asInt(r.tx['item_id']))),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
                                child: Row(
                                  children: [
                                    ItemIcon(
                                        url: r.item?['icon'] as String?,
                                        rarity: r.item?['rarity'] as String?,
                                        size: 36),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              (r.item?['name'] as String?) ??
                                                  s.t('item_n', {'id': asInt(r.tx['item_id'])}),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                          Row(
                                            children: [
                                              Text('${fmtInt(asInt(r.tx['quantity']))} × ',
                                                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                              CoinText(asInt(r.tx['price']), size: 12),
                                              Text(
                                                  ' · ${('${r.tx['created'] ?? ''}').length >= 10 ? '${r.tx['created']}'.substring(0, 10) : ''}',
                                                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            _statBox(s.t('orders_committed'), CoinText(total(buys.valueOrNull), size: 22)),
            const SizedBox(width: 14),
            _statBox(s.t('orders_selling_for'), CoinText(total(sells.valueOrNull), size: 22)),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          final a = list(s.t('buying'), buys, 'current/buys');
          final b = list(s.t('selling'), sells, 'current/sells');
          if (box.maxWidth < 800) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 16), b]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)],
          );
        }),
      ],
    );
  }
}

/// what was sold or bought, one at a time, with a search and the total of each line
class _HistorySite extends ConsumerStatefulWidget {
  const _HistorySite();

  @override
  ConsumerState<_HistorySite> createState() => _HistorySiteState();
}

class _HistorySiteState extends ConsumerState<_HistorySite> {
  var _sold = true;
  var _query = '';

  /// ninety days can be thousands of rows: they are shown a hundred at a time, and the search waits for a pause in the
  /// typing, so a key pressed does not build all of them again
  static const _page = 100;
  var _shown = _page;
  Timer? _typing;

  @override
  void dispose() {
    _typing?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final kind = _sold ? 'history/sells' : 'history/buys';
    final value = ref.watch(transactionsProvider(kind));
    final q = _query.trim().toLowerCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
                label: Text(s.t('sold')),
                selected: _sold,
                onSelected: (_) => setState(() {
                      _sold = true;
                      _shown = _page;
                    })),
            ChoiceChip(
                label: Text(s.t('bought')),
                selected: !_sold,
                onSelected: (_) => setState(() {
                      _sold = false;
                      _shown = _page;
                    })),
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: (v) {
                  _typing?.cancel();
                  _typing = Timer(const Duration(milliseconds: 250), () {
                    if (mounted) {
                      setState(() {
                        _query = v;
                        _shown = _page;
                      });
                    }
                  });
                },
                decoration: fieldDecoration(s.t('search'), prefixIcon: Icon(Icons.search, color: AppColors.muted)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Panel(
          padding: EdgeInsets.zero,
          child: AsyncView<List<TxRow>>(
            permission: 'tradingpost',
            value: value,
            onRetry: () => ref.invalidate(transactionsProvider(kind)),
            builder: (all) {
              final rows = [
                for (final r in all)
                  if (q.isEmpty || '${r.item?['name'] ?? ''}'.toLowerCase().contains(q)) r,
              ];
              if (rows.isEmpty) {
                return Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(s.t('nothing_here'), style: TextStyle(color: AppColors.muted)));
              }
              return Column(
                children: [
                  _tableHead([
                    (s.t('item'), null),
                    (s.t('tp_col_date'), 130),
                    (s.t('tp_col_qty'), 90),
                    (s.t('price_each'), 130),
                    (s.t('total'), 150)
                  ]),
                  for (final r in rows.take(_shown))
                    InkWell(
                      onTap: () => openPanel(context, (_) => TradingItemScreen(itemId: asInt(r.tx['item_id']))),
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  ItemIcon(
                                      url: r.item?['icon'] as String?, rarity: r.item?['rarity'] as String?, size: 32),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                        (r.item?['name'] as String?) ?? s.t('item_n', {'id': asInt(r.tx['item_id'])}),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                            _siteCell(
                                Text(
                                    '${r.tx['purchased'] ?? r.tx['created'] ?? ''}'.length >= 10
                                        ? '${r.tx['purchased'] ?? r.tx['created']}'.substring(0, 10)
                                        : '',
                                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                                130),
                            _siteCell(
                                Text(fmtInt(asInt(r.tx['quantity'])), style: const TextStyle(fontSize: 13.5)), 90),
                            _siteCell(CoinText(asInt(r.tx['price']), size: 13.5), 130),
                            _siteCell(CoinText(asInt(r.tx['price']) * asInt(r.tx['quantity']), size: 13.5), 150),
                          ],
                        ),
                      ),
                    ),
                  if (rows.length > _shown)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: TextButton(
                        onPressed: () => setState(() => _shown += _page),
                        child: Text('${s.t('show_more')} (${rows.length - _shown})'),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(s.t('history_note'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}

/// ninety days of money: what was sold and bought and the net, the sales of each day as bars, and the best sellers
class _StatsSite extends ConsumerWidget {
  const _StatsSite();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final stats = ref.watch(tradeStatsProvider);
    final sells = ref.watch(transactionsProvider('history/sells')).valueOrNull ?? const <TxRow>[];
    // what was sold on each of the last thirty days, in copper
    final now = DateTime.now();
    final days = <String, int>{};
    for (var i = 29; i >= 0; i--) {
      days[dayKey(now.subtract(Duration(days: i)))] = 0;
    }
    for (final r in sells) {
      final raw = '${r.tx['purchased'] ?? ''}';
      if (raw.length < 10) continue;
      final key = dayKey(DateTime.tryParse(raw)?.toLocal() ?? now);
      if (days.containsKey(key)) days[key] = days[key]! + asInt(r.tx['price']) * asInt(r.tx['quantity']);
    }
    final peak = days.values.fold<int>(1, (a, b) => a > b ? a : b);
    return AsyncView<TradeStats>(
      permission: 'tradingpost',
      value: stats,
      onRetry: () => ref.invalidate(tradeStatsProvider),
      builder: (data) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              _statBox(
                  s.t('sold_for'), CoinText(data.soldValue, size: 22), s.t('n_items', {'n': fmtInt(data.soldCount)})),
              const SizedBox(width: 14),
              _statBox(s.t('spent_on_buys'), CoinText(data.boughtValue, size: 22),
                  s.t('n_items', {'n': fmtInt(data.boughtCount)})),
              const SizedBox(width: 14),
              _statBox(s.t('net'), CoinText(data.net, size: 22), s.t('after_fee')),
              const SizedBox(width: 14),
              _statBox(s.t('last_90_days'), Text(fmtInt(sells.length), style: display(28)), s.t('sales')),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            final chart = Panel(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(s.t('sold_per_day'), style: display(18))),
                      Text(s.t('last_30_days'), style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 150,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final v in days.values)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Tooltip(
                                message: _words(v),
                                child: Container(
                                  height: v == 0 ? 2 : 6 + 144 * v / peak,
                                  decoration: BoxDecoration(
                                    color: v == 0 ? AppColors.track : AppColors.gold,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
            final top = Panel(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('top_sellers'), style: display(18)),
                  const SizedBox(height: 6),
                  for (var i = 0; i < data.topSold.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
                      child: Row(
                        children: [
                          SizedBox(width: 24, child: Text('${i + 1}', style: TextStyle(color: AppColors.muted))),
                          Expanded(
                            child: Text(data.topSold[i].key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          CoinText(data.topSold[i].value, size: 14),
                        ],
                      ),
                    ),
                ],
              ),
            );
            if (box.maxWidth < 900) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [chart, const SizedBox(height: 16), top]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(flex: 3, child: chart), const SizedBox(width: 16), Expanded(flex: 2, child: top)],
            );
          }),
        ],
      ),
    );
  }
}

/// "2s 40c" as words, for a tooltip
String _words(int copper) {
  final c = Coins(copper);
  return [
    if (c.gold > 0) '${fmtInt(c.gold)}g',
    if (c.silver > 0) '${c.silver}s',
    if (c.copper > 0 || copper == 0) '${c.copper}c',
  ].join(' ');
}

/// an item on the trading post, on a site: what it is, four boxes of its prices, the chart and the order book at the left, and what to do with it at the right
class _ItemSite extends ConsumerWidget {
  const _ItemSite({
    required this.itemId,
    required this.item,
    required this.name,
    required this.rarity,
    required this.price,
    required this.watched,
  });

  final int itemId;
  final Json? item;
  final String name;
  final String? rarity;
  final AsyncValue<Json?> price;
  final bool watched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final totals = ref.watch(accountTotalsProvider).valueOrNull;
    final alert = ref.watch(priceAlertsProvider)[itemId];
    final p = price.valueOrNull;
    final buys = p?['buys'] is Map ? p!['buys'] as Map : const {};
    final sells = p?['sells'] is Map ? p!['sells'] as Map : const {};
    final buy = asInt(buys['unit_price']);
    final sell = asInt(sells['unit_price']);
    final profit = buy > 0 && sell > 0 ? afterTradingFees(sell - 1) - buy : 0;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PriceHistoryPanel(itemId: itemId),
        const SizedBox(height: 16),
        _OrderBook(itemId: itemId),
        ItemFacts(itemId: itemId),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _kicker(s.t('price_alert')),
              const SizedBox(height: 10),
              Text(
                alert == null
                    ? s.t('alert_none')
                    : [
                        if (alert.sellBelow != null) '${s.t('alert_sell_below')}: ${_words(alert.sellBelow!)}',
                        if (alert.buyAbove != null) '${s.t('alert_buy_above')}: ${_words(alert.buyAbove!)}',
                      ].join('\n'),
                style: TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSoft),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => showPriceAlertDialog(context, ref, itemId, name),
                icon: Icon(alert == null ? Icons.notifications_none : Icons.notifications_active, size: 18),
                label: Text(alert == null ? s.t('save_alert') : s.t('price_alert')),
              ),
              const SizedBox(height: 10),
              Text(s.t('alert_push_hint'), style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => ref.read(watchlistProvider.notifier).toggle(itemId),
                icon: Icon(watched ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                label: Text(watched ? s.t('unwatch') : s.t('watch')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => openWikiPage(context, ref, name),
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(s.t('wiki')),
              ),
              const SizedBox(height: 14),
              Text(s.t('tp_note'), style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.hint)),
            ],
          ),
        ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            ItemIcon(url: item?['icon'] as String?, rarity: rarity, size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [if (item?['type'] != null) _typeLabel(s, '${item?['type']}'), if (rarity != null) rarity!]
                        .join(' · ')
                        .caps,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: rarityColor(rarity)),
                  ),
                  const SizedBox(height: 4),
                  Text(name, style: display(32)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (p == null && !price.isLoading)
          Panel(child: Text(s.t('not_tradeable'), style: TextStyle(color: AppColors.muted)))
        else
          Row(
            children: [
              _statBox(s.t('lowest_sell'), CoinText(sell, size: 24),
                  s.t('n_listed', {'n': fmtInt(asInt(sells['quantity']))})),
              const SizedBox(width: 14),
              _statBox(
                  s.t('highest_buy'), CoinText(buy, size: 24), s.t('n_listed', {'n': fmtInt(asInt(buys['quantity']))})),
              const SizedBox(width: 14),
              _statBox(s.t('flip_profit'), CoinText(profit, size: 24), s.t('after_fee')),
              const SizedBox(width: 14),
              _statBox(s.t('you_own'), Text(fmtInt(totals?[itemId] ?? 0), style: display(28))),
            ],
          ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          if (box.maxWidth < 900) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 16), right]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: left), const SizedBox(width: 16), SizedBox(width: 340, child: right)],
          );
        }),
      ],
    );
  }
}
