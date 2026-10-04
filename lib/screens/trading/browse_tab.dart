part of '../trading_screen.dart';

/// "LongBow" as "Long Bow", the api's subtypes are camel case
String spacedType(String raw) => raw.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ');

String _typeLabel(S s, String type) {
  final key = 'itype_$type';
  final text = s.t(key);
  return text == key ? spacedType(type) : text;
}

const _rarities = ['Junk', 'Basic', 'Fine', 'Masterwork', 'Rare', 'Exotic', 'Ascended', 'Legendary'];

/// every item the trading post lists, with filters and sorting
class _BrowseTab extends ConsumerStatefulWidget {
  const _BrowseTab();

  @override
  ConsumerState<_BrowseTab> createState() => _BrowseTabState();
}

class _BrowseTabState extends ConsumerState<_BrowseTab> {
  final _ctrl = TextEditingController();
  MarketFilter _f = const MarketFilter();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _set(MarketFilter f) => setState(() => _f = f);

  Future<void> _pickType(List<MarketEntry> entries) async {
    final s = ref.read(stringsProvider);
    final counts = <String, int>{};
    for (final e in entries) {
      counts[e.type] = (counts[e.type] ?? 0) + 1;
    }
    final types = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    final picked = await _choose<String>(s.t('item_type'), [
      (null, s.t('all'), ''),
      for (final t in types) (t, _typeLabel(s, t), fmtInt(counts[t]!)),
    ]);
    if (picked != null) _set(_f.copyWith(type: () => picked.$1, subtype: () => null));
  }

  Future<void> _pickSubtype(List<MarketEntry> entries) async {
    final s = ref.read(stringsProvider);
    final counts = <String, int>{};
    for (final e in entries) {
      if (e.type == _f.type && e.subtype.isNotEmpty) counts[e.subtype] = (counts[e.subtype] ?? 0) + 1;
    }
    final subs = counts.keys.toList()..sort();
    final picked = await _choose<String>(s.t('item_subtype'), [
      (null, s.t('all'), ''),
      for (final t in subs) (t, spacedType(t), fmtInt(counts[t]!)),
    ]);
    if (picked != null) _set(_f.copyWith(subtype: () => picked.$1));
  }

  Future<void> _pickSort() async {
    final s = ref.read(stringsProvider);
    final picked = await _choose<MarketSort>(s.t('sort_by'), [
      for (final m in MarketSort.values) (m, s.t('msort_${m.name}'), ''),
    ]);
    if (picked?.$1 != null) _set(_f.copyWith(sort: picked!.$1));
  }

  /// a list of choices in a bottom sheet. the outer record is null when the
  /// sheet was dismissed, its value null when "all" was picked
  Future<(T?,)?> _choose<T>(String title, List<(T?, String, String)> options) {
    return showModalBottomSheet<(T?,)>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Text(title, style: display(17))),
              for (final o in options)
                ListTile(
                  title: Text(o.$2),
                  trailing: Text(o.$3, style: TextStyle(color: AppColors.muted)),
                  onTap: () => Navigator.of(context).pop((o.$1,)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickLevel() async {
    var range = RangeValues(_f.minLevel.toDouble(), _f.maxLevel.toDouble());
    final s = ref.read(stringsProvider);
    final picked = await showModalBottomSheet<RangeValues>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('level_range_n', {'a': range.start.round(), 'b': range.end.round()}), style: display(17)),
                RangeSlider(
                  values: range,
                  min: 0,
                  max: 80,
                  divisions: 80,
                  activeColor: AppColors.gold,
                  onChanged: (v) => setSheet(() => range = v),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(onPressed: () => Navigator.of(context).pop(range), child: Text(s.t('apply'))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked != null) _set(_f.copyWith(minLevel: picked.start.round(), maxLevel: picked.end.round()));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final entries = ref.watch(marketIndexProvider);
    final index = ref.watch(itemIndexProvider).valueOrNull;
    final prices = ref.watch(allPricesProvider);
    final progress = ref.watch(marketPricesProgressProvider);

    return entries.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.gold)),
      error: (e, _) => ErrorBox(error: e, onRetry: () => ref.invalidate(marketIndexProvider)),
      data: (list) {
        if (list.isEmpty) {
          return Padding(padding: const EdgeInsets.all(24), child: EmptyNote(s.t('market_index_missing')));
        }
        final ids = filterMarket(list, _f, nameOf: namesFrom(index), prices: prices.valueOrNull);
        Widget chip(String label, bool on, VoidCallback onTap, {IconData? icon}) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: icon == null ? null : Icon(icon, size: 16),
                label: Text(label),
                selected: on,
                onSelected: (_) => onTap(),
              ),
            );
        final levelOn = _f.minLevel > 0 || _f.maxLevel < 80;
        final header = <Widget>[
          TextField(
            controller: _ctrl,
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), () => _set(_f.copyWith(query: v)));
            },
            decoration: fieldDecoration(
              s.t('search_items'),
              prefixIcon: Icon(Icons.search, color: AppColors.gold),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close, color: AppColors.muted),
                      onPressed: () {
                        _ctrl.clear();
                        _set(_f.copyWith(query: ''));
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                chip(_f.type == null ? s.t('item_type') : _typeLabel(s, _f.type!), _f.type != null,
                    () => _pickType(list),
                    icon: Icons.category_outlined),
                if (_f.type != null)
                  chip(_f.subtype == null ? s.t('item_subtype') : spacedType(_f.subtype!), _f.subtype != null,
                      () => _pickSubtype(list)),
                chip(levelOn ? s.t('level_range_n', {'a': _f.minLevel, 'b': _f.maxLevel}) : s.t('level'), levelOn,
                    _pickLevel,
                    icon: Icons.signal_cellular_alt),
                chip(s.t('msort_${_f.sort.name}'), true, _pickSort, icon: Icons.sort),
                chip(
                    s.t('only_listed'), _f.minSupply > 0, () => _set(_f.copyWith(minSupply: _f.minSupply > 0 ? 0 : 1))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final r in _rarities)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: CircleAvatar(radius: 5, backgroundColor: rarityColor(r)),
                      label: Text(r),
                      selected: _f.rarities.contains(r),
                      onSelected: (_) {
                        final next = {..._f.rarities};
                        next.contains(r) ? next.remove(r) : next.add(r);
                        _set(_f.copyWith(rarities: next));
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(s.t('n_items', {'n': fmtInt(ids.length)}),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSoft)),
              ),
              if (prices.isLoading)
                Text(s.t('prices_loading', {'n': (progress * 100).round()}),
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              if (prices.hasError)
                TextButton(onPressed: () => ref.invalidate(allPricesProvider), child: Text(s.t('retry'))),
            ],
          ),
          if (prices.isLoading) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(
                value: progress, minHeight: 2, color: AppColors.gold, backgroundColor: AppColors.track),
          ],
          const SizedBox(height: 10),
        ];
        return RefreshIndicator(
          color: AppColors.gold,
          // forceNetwork skips the ten minute disk copy
          onRefresh: () => refreshProviders(ref, [allPricesProvider]),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: header.length + (ids.isEmpty ? 1 : ids.length),
            itemBuilder: (context, i) {
              if (i < header.length) return header[i];
              if (ids.isEmpty) return EmptyNote(s.t('no_results'));
              final n = i - header.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BrowseRow(
                  id: ids[n],
                  batchKey: pageKey(ids, n),
                  price: prices.valueOrNull?[ids[n]],
                  sort: _f.sort,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BrowseRow extends ConsumerWidget {
  const _BrowseRow({required this.id, required this.batchKey, required this.price, required this.sort});

  final int id;
  final String batchKey;
  final TpPrice? price;
  final MarketSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemBatchProvider(batchKey)).valueOrNull?[id];
    final name =
        (item?['name'] as String?) ?? ref.watch(itemIndexProvider).valueOrNull?.nameOf(id) ?? s.t('item_n', {'id': id});
    final p = price;
    final details = item?['details'] is Map ? item!['details'] as Map : const {};
    final level = asInt(item?['level']);
    final sub = [
      if (details['type'] != null)
        spacedType('${details['type']}')
      else if (item?['type'] != null)
        _typeLabel(s, '${item?['type']}'),
      if (level > 0) s.t('level_n', {'n': level}),
    ].join(' · ');
    final small = TextStyle(fontSize: 11, color: AppColors.muted);
    return _ItemTile(
      itemId: id,
      item: item,
      title: name,
      subtitle: sub.isEmpty ? null : sub,
      trailing: p == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (sort == MarketSort.flip) ...[
                  CoinText(p.flip, size: 14),
                  Text('${(p.margin * 100).round()}%', style: small),
                ] else ...[
                  CoinText(p.sell, size: 14),
                  const SizedBox(height: 2),
                  if (sort == MarketSort.supply || sort == MarketSort.demand)
                    Text('${s.t('supply')} ${compact(p.supply)} · ${s.t('demand')} ${compact(p.demand)}', style: small)
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${s.t('buy_short')} ', style: small),
                        CoinText(p.buy, size: 11),
                      ],
                    ),
                ],
              ],
            ),
    );
  }
}
