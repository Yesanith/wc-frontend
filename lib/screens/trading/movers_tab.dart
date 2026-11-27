part of '../trading_screen.dart';

/// what rose and fell on the trading post: over a day, a week or a month, the items that are traded enough for a price to mean
/// something, the most risen and the most fallen side by side where there is room
class _MoversTab extends ConsumerStatefulWidget {
  const _MoversTab();

  @override
  ConsumerState<_MoversTab> createState() => _MoversTabState();
}

class _MoversTabState extends ConsumerState<_MoversTab> {
  var _days = 1;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final movers = ref.watch(marketMoversProvider(_days));
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async => ref.invalidate(marketMoversProvider(_days)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(s.t('movers_note'), style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final (d, key) in const [(1, 'movers_day'), (7, 'movers_week'), (30, 'movers_month')])
              ChoiceChip(label: Text(s.t(key)), selected: _days == d, onSelected: (_) => setState(() => _days = d)),
          ]),
          const SizedBox(height: 14),
          AsyncView<MarketMovers>(
            value: movers,
            onRetry: () => ref.invalidate(marketMoversProvider(_days)),
            builder: (m) {
              if (!communityReady) return EmptyNote(s.t('movers_unavailable'));
              if (m.isEmpty) return EmptyNote(s.t('movers_none'));
              return SplitColumns(
                breakpoint: 820,
                primaryFlex: 1,
                secondaryFlex: 1,
                spacing: 20,
                primary: [_MoverList(title: s.t('movers_up'), moves: m.risers, up: true)],
                secondary: [_MoverList(title: s.t('movers_down'), moves: m.fallers, up: false)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MoverList extends ConsumerWidget {
  const _MoverList({required this.title, required this.moves, required this.up});

  final String title;
  final List<MarketMove> moves;
  final bool up;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = moves.map((m) => m.itemId).join(',');
    final items = ref.watch(itemBatchProvider(key)).valueOrNull ?? const <int, Json>{};
    final tint = up ? AppColors.green : AppColors.red;
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(up ? Icons.trending_up : Icons.trending_down, size: 18, color: tint),
            const SizedBox(width: 8),
            Kicker(title.caps),
          ]),
          const SizedBox(height: 6),
          if (moves.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('–', style: TextStyle(color: AppColors.muted)),
            ),
          for (final m in moves)
            InkWell(
              onTap: () => showItemDetails(context, m.itemId),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    ItemIcon(
                        url: items[m.itemId]?['icon'] as String?,
                        rarity: items[m.itemId]?['rarity'] as String?,
                        size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${items[m.itemId]?['name'] ?? '#${m.itemId}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Row(children: [
                            CoinText(m.before, size: 11.5),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.arrow_forward, size: 12, color: AppColors.muted),
                            ),
                            CoinText(m.sell, size: 11.5),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${m.change > 0 ? '+' : ''}${(m.change * 100).toStringAsFixed(m.change.abs() >= 1 ? 0 : 1)}%',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: tint),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
