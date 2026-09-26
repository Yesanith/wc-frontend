part of '../trading_screen.dart';

/// profit and loss from the 90 days of history the api keeps
class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final stats = ref.watch(tradeStatsProvider);

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [transactionsProvider('history/sells'), transactionsProvider('history/buys'), tradeStatsProvider]),
      child: AsyncView<TradeStats>(
        permission: 'tradingpost',
        value: stats,
        onRetry: () => ref.invalidate(tradeStatsProvider),
        builder: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(s.t('last_90_days'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 12),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatLine(label: s.t('sold_for'), copper: data.soldValue),
                  const SizedBox(height: 12),
                  _StatLine(label: s.t('spent_on_buys'), copper: data.boughtValue),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.track, height: 1),
                  const SizedBox(height: 12),
                  _StatLine(label: s.t('net'), copper: data.net, highlight: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Panel(
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(label: s.t('items_sold'), value: fmtInt(data.soldCount)),
                  ),
                  Expanded(
                    child: StatTile(label: s.t('items_bought'), value: fmtInt(data.boughtCount)),
                  ),
                ],
              ),
            ),
            if (data.topSold.isNotEmpty) ...[
              const SizedBox(height: 22),
              SectionHeader(title: s.t('top_sellers')),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    for (final entry in data.topSold)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(entry.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 10),
                            CoinText(entry.value, size: 13),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.copper, this.highlight = false});

  final String label;
  final int copper;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
                  color: highlight ? AppColors.text : AppColors.textSoft)),
        ),
        CoinText(copper, size: highlight ? 18 : 15),
      ],
    );
  }
}
