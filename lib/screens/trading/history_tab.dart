part of '../trading_screen.dart';

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

    Widget list(AsyncValue<List<TxRow>> value, String kind, String emptyKey) => AsyncView<List<TxRow>>(
          permission: 'tradingpost',
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
      onRefresh: () => refreshProviders(ref, [transactionsProvider(first), transactionsProvider(second)]),
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
