import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/item_index.dart';
import '../state/account.dart';
import '../state/api.dart';
import '../state/items.dart';
import '../state/settings.dart';
import '../state/trading.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import 'item_sheet.dart';

part 'trading/item_page.dart';
part 'trading/overview_tab.dart';
part 'trading/history_tab.dart';
part 'trading/stats_tab.dart';

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
      length: 4,
      child: Column(
        children: [
          AppTabBar(scrollable: true, labels: [s.t('overview'), s.t('orders'), s.t('history'), s.t('stats')]),
          const Expanded(
            child: TabBarView(
              children: [
                _OverviewTab(),
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
