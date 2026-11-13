part of '../home_screen.dart';

/// the trading post at a glance: what waits in the delivery box, how many orders are open, and the first of the
/// watchlist with its price
class _TradeBox extends ConsumerWidget {
  const _TradeBox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final delivery = ref.watch(deliveryProvider).valueOrNull;
    final buys = ref.watch(transactionsProvider('current/buys')).valueOrNull;
    final sells = ref.watch(transactionsProvider('current/sells')).valueOrNull;
    final watched = ref.watch(watchlistPricesProvider).valueOrNull ?? const <WatchedItem>[];
    final waiting = delivery == null ? 0 : delivery.items.length;
    return AppCard(
      onTap: () => ref.read(sectionProvider.notifier).state = AppSection.trading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TradeLine(
            label: s.t('delivery'),
            value: delivery == null
                ? const Text('–')
                : delivery.coins == 0 && waiting == 0
                    ? Text(s.t('delivery_empty'), style: TextStyle(fontSize: 12, color: AppColors.muted))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (delivery.coins > 0) CoinText(delivery.coins, size: 14),
                        if (delivery.coins > 0 && waiting > 0) const SizedBox(width: 10),
                        if (waiting > 0) Text('+ $waiting', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ]),
          ),
          _TradeLine(
            label: s.t('orders'),
            value: Text(
              buys == null || sells == null
                  ? '–'
                  : '${s.t('buying')} ${buys.length} · ${s.t('selling')} ${sells.length}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          for (final w in watched.take(3))
            if (w.item != null && w.price != null)
              _TradeLine(
                label: '${w.item!['name']}',
                value: CoinText(TpPrice.fromJson(w.price!).sell, size: 13),
              ),
        ],
      ),
    );
  }
}

class _TradeLine extends StatelessWidget {
  const _TradeLine({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppColors.textSoft)),
            ),
            value,
          ],
        ),
      );
}

/// the day's and the week's vault in two bars, so both are in sight without opening the tabs
class _VaultBars extends ConsumerWidget {
  const _VaultBars();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    Widget bar(String track, String label) {
      final v = ref.watch(vaultTrackProvider(track)).valueOrNull;
      final stale = ref.watch(vaultStaleProvider(track));
      final goal = v == null ? 0 : asInt(v['meta_progress_complete']);
      final now = v == null ? 0 : asInt(v['meta_progress_current']);
      final shown = stale || goal <= 0 ? null : (now > goal ? goal : now);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              Text(shown == null ? '–' : '$shown / $goal',
                  style: TextStyle(fontSize: 12, color: AppColors.muted, fontFeatures: _tabular)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: shown == null ? 0 : shown / goal,
                minHeight: 6,
                backgroundColor: AppColors.track,
                color: shown != null && shown >= goal ? AppColors.green : AppColors.gold,
              ),
            ),
          ],
        ),
      );
    }

    return Column(children: [bar('daily', s.t('vault_daily')), bar('weekly', s.t('vault_weekly'))]);
  }
}

/// the newest article of the official feed, one line with its date
class _LatestNews extends ConsumerWidget {
  const _LatestNews();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final items = ref.watch(newsProvider).valueOrNull ?? const <NewsItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final top = items.first;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        onTap: () => ref.read(sectionProvider.notifier).state = AppSection.news,
        child: Row(
          children: [
            Icon(Icons.newspaper, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [s.t('latest_news'), if (top.date != null) shortDateText(s, top.date!.toLocal())].join(' · ').caps,
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.muted),
                  ),
                  const SizedBox(height: 3),
                  Text(top.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.chevron),
          ],
        ),
      ),
    );
  }
}
