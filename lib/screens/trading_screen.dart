import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final list = ref.watch(watchlistPricesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('watchlist'), style: display(20)),
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(watchlistPricesProvider);
          try {
            await ref.read(watchlistPricesProvider.future);
          } catch (_) {}
        },
        child: AsyncView<List<WatchedItem>>(
          value: list,
          onRetry: () => ref.invalidate(watchlistPricesProvider),
          builder: (items) {
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(s.t('watchlist_empty'),
                      textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.5)),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final w = items[i];
                final sells = w.price?['sells'] is Map ? w.price!['sells'] as Map : const {};
                final buys = w.price?['buys'] is Map ? w.price!['buys'] as Map : const {};
                final name = (w.item?['name'] as String?) ?? s.t('item_n', {'id': w.id});
                return Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => TradingItemScreen(itemId: w.id)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          ItemIcon(url: w.item?['icon'] as String?, rarity: w.item?['rarity'] as String?, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CoinText(asInt(sells['unit_price']), size: 15),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${s.t('buy_short')} ',
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                  CoinText(asInt(buys['unit_price']), size: 12),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
