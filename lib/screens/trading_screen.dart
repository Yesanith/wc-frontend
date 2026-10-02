import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/item_index.dart';
import '../state/account.dart';
import '../state/alerts.dart';
import '../state/api.dart';
import '../state/gem_history.dart';
import '../state/items.dart';
import '../state/market.dart';
import '../state/price_history.dart';
import '../state/server_price_alerts.dart';
import '../state/settings.dart';
import '../state/trading.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import '../widgets/price_chart.dart';
import 'item_sheet.dart';
import 'item_detail_screen.dart';

part 'trading/item_page.dart';
part 'trading/overview_tab.dart';
part 'trading/history_tab.dart';
part 'trading/stats_tab.dart';
part 'trading/browse_tab.dart';

class WatchRow extends ConsumerWidget {
  const WatchRow(this.w, {super.key});

  final WatchedItem w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final sells = w.price?['sells'] is Map ? w.price!['sells'] as Map : const {};
    final buys = w.price?['buys'] is Map ? w.price!['buys'] as Map : const {};
    final name = (w.item?['name'] as String?) ?? s.t('item_n', {'id': w.id});
    final hasAlert = ref.watch(priceAlertsProvider).containsKey(w.id);
    final fired = ref.watch(triggeredAlertsProvider).valueOrNull?.contains(w.id) ?? false;
    // the sell price against a week ago, once the history reaches back that far
    final week = lastDays(ref.watch(priceHistoryProvider)[w.id] ?? const <PricePoint>[], 7);
    final change = percentChange(week, (p) => p.sell);
    return _ItemTile(
      itemId: w.id,
      item: w.item,
      title: name,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (hasAlert)
            Icon(fired ? Icons.notifications_active : Icons.notifications_none,
                size: 16, color: fired ? AppColors.green : AppColors.gold),
          CoinText(asInt(sells['unit_price']), size: 15),
          if (change != null)
            Text(
              '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% · 7d',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: change >= 0 ? AppColors.green : AppColors.red),
            ),
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
  const _ItemTile(
      {required this.itemId, required this.item, required this.title, this.subtitle, required this.trailing});

  final int itemId;
  final Json? item;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return ItemRow(
      icon: item?['icon'] as String?,
      rarity: item?['rarity'] as String?,
      title: title,
      subtitle: sub,
      trailing: trailing,
      iconSize: 44,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TradingItemScreen(itemId: itemId)),
      ),
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
      length: 5,
      child: Column(
        children: [
          AppTabBar(
              scrollable: true,
              labels: [s.t('overview'), s.t('tp_all_items'), s.t('orders'), s.t('history'), s.t('stats')]),
          const Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(),
                _BrowseTab(),
                _TxTab(first: 'current/buys', second: 'current/sells', firstKey: 'buying', secondKey: 'selling'),
                _TxTab(first: 'history/sells', second: 'history/buys', firstKey: 'sold', secondKey: 'bought'),
                _StatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
