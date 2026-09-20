import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/gw2_api.dart';
import '../services/item_index.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// gold / silver / copper with the in-game coin colors
class CoinText extends StatelessWidget {
  const CoinText(this.copper, {super.key, this.size = 16});

  final int copper;
  final double size;

  @override
  Widget build(BuildContext context) {
    final negative = copper < 0;
    final c = Coins(copper.abs());
    final unit = TextStyle(fontSize: size * 0.75, fontWeight: FontWeight.w800);
    final value = TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: negative ? AppColors.red : null);
    return Text.rich(
      TextSpan(children: [
        if (negative) TextSpan(text: '-', style: value),
        if (c.gold > 0) ...[
          TextSpan(text: fmtInt(c.gold), style: value),
          TextSpan(text: 'g ', style: unit.copyWith(color: AppColors.gold)),
        ],
        if (c.gold > 0 || c.silver > 0) ...[
          TextSpan(text: '${c.silver}', style: value),
          TextSpan(text: 's ', style: unit.copyWith(color: AppColors.silver)),
        ],
        TextSpan(text: '${c.copper}', style: value),
        TextSpan(text: 'c', style: unit.copyWith(color: AppColors.copper)),
      ]),
    );
  }
}

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
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(priceProvider(itemId));
          try {
            await ref.read(priceProvider(itemId).future);
          } catch (_) {}
        },
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

class WatchRow extends ConsumerWidget {
  const WatchRow(this.w, {super.key});

  final WatchedItem w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final sells = w.price?['sells'] is Map ? w.price!['sells'] as Map : const {};
    final buys = w.price?['buys'] is Map ? w.price!['buys'] as Map : const {};
    final name = (w.item?['name'] as String?) ?? s.t('item_n', {'id': w.id});
    return _ItemTile(
      itemId: w.id,
      item: w.item,
      title: name,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CoinText(asInt(sells['unit_price']), size: 15),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${s.t('buy_short')} ', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              CoinText(asInt(buys['unit_price']), size: 12),
            ],
          ),
        ],
      ),
    );
  }
}

/// item row that opens the trading post page for the item
class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.itemId, required this.item, required this.title, this.subtitle, required this.trailing});

  final int itemId;
  final Json? item;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => TradingItemScreen(itemId: itemId)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    if (sub != null) Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// like AsyncView but shows a hint instead of an error when the key
/// is missing the tradingpost permission
class _TpAsync<T> extends ConsumerWidget {
  const _TpAsync({required this.value, required this.builder, required this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return value.when(
      data: builder,
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) {
        if (e is Gw2ApiException && (e.status == 401 || e.status == 403)) {
          return Panel(child: Text(s.t('needs_tp_perm'), style: const TextStyle(color: AppColors.muted, height: 1.5)));
        }
        return ErrorBox(message: '$e', onRetry: onRetry);
      },
    );
  }
}

/// the trading post section of the drawer
class TradingHubScreen extends ConsumerWidget {
  const TradingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.gold,
            dividerColor: AppColors.track,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            tabs: [
              Tab(text: s.t('overview')),
              Tab(text: s.t('orders')),
              Tab(text: s.t('history')),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(),
                _TxTab(first: 'current/buys', second: 'current/sells', firstKey: 'buying', secondKey: 'selling'),
                _TxTab(first: 'history/sells', second: 'history/buys', firstKey: 'sold', secondKey: 'bought'),
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
    _ctrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    final index = ref.read(itemIndexProvider).valueOrNull ?? ItemIndex.empty;
    setState(() => _results = index.search(q));
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
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                for (final item in _results.take(12))
                  ListTile(
                    dense: true,
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF6E6859)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => TradingItemScreen(itemId: item.id)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

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
      onRefresh: () async {
        ref.invalidate(gemRatesProvider);
        ref.invalidate(deliveryProvider);
        ref.invalidate(watchlistPricesProvider);
        try {
          await ref.read(watchlistPricesProvider.future);
        } catch (_) {}
      },
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
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(s.t('delivery').toUpperCase()),
                const SizedBox(height: 12),
                _TpAsync<Delivery>(
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
                ? Panel(child: Text(s.t('watchlist_empty'), style: const TextStyle(color: AppColors.muted, height: 1.5)))
                : Column(
                    children: [
                      for (final w in items)
                        Padding(padding: const EdgeInsets.only(bottom: 8), child: WatchRow(w)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TxTab extends ConsumerWidget {
  const _TxTab({required this.first, required this.second, required this.firstKey, required this.secondKey});

  final String first;
  final String second;
  final String firstKey;
  final String secondKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final a = ref.watch(transactionsProvider(first));
    final b = ref.watch(transactionsProvider(second));

    Widget list(AsyncValue<List<TxRow>> value, String kind, String emptyKey) => _TpAsync<List<TxRow>>(
          value: value,
          onRetry: () => ref.invalidate(transactionsProvider(kind)),
          builder: (rows) => rows.isEmpty
              ? Panel(child: Text(s.t(emptyKey), style: const TextStyle(color: AppColors.muted)))
              : Column(
                  children: [
                    for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 8), child: _TxRowTile(r)),
                  ],
                ),
        );

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async {
        ref.invalidate(transactionsProvider(first));
        ref.invalidate(transactionsProvider(second));
        try {
          await ref.read(transactionsProvider(first).future);
        } catch (_) {}
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          SectionHeader(title: s.t(firstKey), trailing: a.valueOrNull == null ? null : '${a.valueOrNull!.length}'),
          const SizedBox(height: 10),
          list(a, first, 'nothing_here'),
          const SizedBox(height: 22),
          SectionHeader(title: s.t(secondKey), trailing: b.valueOrNull == null ? null : '${b.valueOrNull!.length}'),
          const SizedBox(height: 10),
          list(b, second, 'nothing_here'),
        ],
      ),
    );
  }
}

class _TxRowTile extends ConsumerWidget {
  const _TxRowTile(this.r);

  final TxRow r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final id = asInt(r.tx['item_id']);
    final qty = asInt(r.tx['quantity']);
    final date = '${r.tx['purchased'] ?? r.tx['created'] ?? ''}';
    return _ItemTile(
      itemId: id,
      item: r.item,
      title: (r.item?['name'] as String?) ?? s.t('item_n', {'id': id}),
      subtitle: date.length >= 10 ? date.substring(0, 10) : null,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CoinText(asInt(r.tx['price']), size: 15),
          Text('x${fmtInt(qty)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}
