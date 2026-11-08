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
              ? Panel(child: Text(s.t(emptyKey), style: TextStyle(color: AppColors.muted)))
              : Column(
                  children: [
                    // on the site a table under its headings, the rows touching
                    if (SiteScope.of(context))
                      _SiteHeadings(
                          first: s.t('item'), columns: [s.t('tp_col_date'), s.t('tp_col_qty'), s.t('tp_col_price')]),
                    for (final r in rows)
                      Padding(padding: EdgeInsets.only(bottom: SiteScope.of(context) ? 0 : 8), child: _TxRowTile(r)),
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
    if (SiteScope.of(context)) {
      final small = TextStyle(fontSize: 13, color: AppColors.textSoft);
      return _ItemTile(
        itemId: id,
        item: r.item,
        title: (r.item?['name'] as String?) ?? s.t('item_n', {'id': id}),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _siteCell(Text(date.length >= 10 ? date.substring(0, 10) : '', style: small)),
            _siteCell(Text(fmtInt(qty), style: small)),
            _siteCell(CoinText(asInt(r.tx['price']), size: 13)),
          ],
        ),
      );
    }
    return _ItemTile(
      itemId: id,
      item: r.item,
      title: (r.item?['name'] as String?) ?? s.t('item_n', {'id': id}),
      subtitle: date.length >= 10 ? date.substring(0, 10) : null,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CoinText(asInt(r.tx['price']), size: 15),
          Text('x${fmtInt(qty)}', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}
