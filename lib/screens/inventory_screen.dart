import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/item_index.dart';
import '../state/account.dart';
import '../state/inventory.dart';
import '../state/items.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import 'item_detail_screen.dart';

/// everything the account owns in one place: a search across every storage,
/// bag and piece of gear, and a list of what could be tidied up
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          AppTabBar(labels: [s.t('inv_search'), s.t('inv_cleanup')]),
          const Expanded(child: TabBarView(children: [_SearchTab(), _CleanupTab()])),
        ],
      ),
    );
  }
}

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  final _ctrl = TextEditingController();
  String _query = '';
  OwnedKind? _only;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final index = ref.watch(itemIndexProvider).valueOrNull;
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [ownedPlacesProvider]),
      child: AsyncView<Map<int, Map<OwnedPlace, int>>>(
        value: ref.watch(ownedPlacesProvider),
        onRetry: () => ref.invalidate(ownedPlacesProvider),
        builder: (owned) {
          final ids = searchOwned(owned, _query, _only, index);
          final header = [
            TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: fieldDecoration(
                s.t('where_is_my'),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, color: AppColors.muted),
                        onPressed: () => setState(() {
                          _ctrl.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                      label: Text(s.t('all')),
                      selected: _only == null,
                      onSelected: (_) => setState(() => _only = null)),
                  for (final k in OwnedKind.values) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: Icon(placeIcon(k), size: 16),
                      label: Text(_kindLabel(s, k)),
                      selected: _only == k,
                      onSelected: (_) => setState(() => _only = _only == k ? null : k),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionHeader(
              title: _query.trim().isEmpty ? s.t('biggest_stacks') : s.t('results'),
              trailing: s.t('n_items', {'n': fmtInt(ids.length)}),
            ),
            const SizedBox(height: 10),
          ];
          final shown = _query.trim().isEmpty ? ids.take(100).toList() : ids;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: header.length + (shown.isEmpty ? 1 : shown.length),
            itemBuilder: (context, i) {
              if (i < header.length) return header[i];
              if (shown.isEmpty) return EmptyNote(s.t('no_results'));
              final n = i - header.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OwnedRow(
                  itemId: shown[n],
                  places: owned[shown[n]]!,
                  batchKey: pageKey(shown, n),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _kindLabel(S s, OwnedKind k) => switch (k) {
      OwnedKind.bags => s.t('nav_characters'),
      OwnedKind.equipped => s.t('equipment'),
      _ => placeLabel(s, OwnedPlace(k)),
    };

/// owned item ids matching a name and a kind of place, most owned first
List<int> searchOwned(Map<int, Map<OwnedPlace, int>> owned, String query, OwnedKind? only, ItemIndex? index) {
  final words = query.trim().toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  int total(int id) => owned[id]!.values.fold(0, (a, b) => a + b);
  final ids = [
    for (final e in owned.entries)
      if ((only == null || e.value.keys.any((p) => p.kind == only)) &&
          (words.isEmpty || words.every((index?.nameOf(e.key) ?? '').toLowerCase().contains)))
        e.key
  ];
  ids.sort((a, b) => total(b).compareTo(total(a)));
  return ids;
}

/// one owned item: where it is and how many
class OwnedRow extends ConsumerWidget {
  const OwnedRow({super.key, required this.itemId, required this.places, required this.batchKey, this.count});

  final int itemId;
  final Map<OwnedPlace, int> places;
  final String batchKey;

  /// shown instead of the total of [places]
  final int? count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemBatchProvider(batchKey)).valueOrNull?[itemId];
    final index = ref.watch(itemIndexProvider).valueOrNull;
    final total = count ?? places.values.fold<int>(0, (a, b) => a + b);
    final where = places.keys.toList();
    return ItemRow(
      icon: item?['icon'] as String?,
      rarity: item?['rarity'] as String?,
      title: (item?['name'] as String?) ?? index?.nameOf(itemId) ?? s.t('item_n', {'id': itemId}),
      titleLines: 1,
      subtitle: where.isEmpty
          ? null
          : where.length == 1
              ? placeLabel(s, where.first)
              : where.length <= 3
                  ? where.map((p) => placeLabel(s, p)).join(' · ')
                  : s.t('in_n_places', {'n': where.length}),
      iconSize: 42,
      trailing: Text('×${fmtInt(total)}',
          style:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
      onTap: () => showItemDetails(context, itemId),
    );
  }
}

class _CleanupTab extends ConsumerWidget {
  const _CleanupTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [ownedPlacesProvider, materialSlotIdsProvider, cleanupProvider]),
      child: AsyncView<CleanupReport>(
        value: ref.watch(cleanupProvider),
        onRetry: () => ref.invalidate(cleanupProvider),
        builder: (r) {
          if (r.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [EmptyNote(s.t('cleanup_nothing'))],
            );
          }
          List<Widget> section(String title, String note, List<CleanupRow> rows, {Widget? extra}) {
            if (rows.isEmpty) return const [];
            final ids = [for (final row in rows) row.itemId];
            return [
              const SizedBox(height: 18),
              SectionHeader(title: title, trailing: fmtInt(rows.length)),
              const SizedBox(height: 4),
              Text(note, style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
              if (extra != null) ...[const SizedBox(height: 8), extra],
              const SizedBox(height: 10),
              for (var i = 0; i < rows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OwnedRow(
                    itemId: rows[i].itemId,
                    places: rows[i].places,
                    count: rows[i].count,
                    batchKey: pageKey(ids, i),
                  ),
                ),
            ];
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              ...section(s.t('cleanup_deposit'), s.t('cleanup_deposit_note'), r.deposit),
              ...section(s.t('cleanup_split'), s.t('cleanup_split_note'), r.split),
              ...section(
                s.t('cleanup_junk'),
                s.t('cleanup_junk_note'),
                r.junk,
                extra: Row(
                  children: [
                    Text('${s.t('vendor_value')}: ', style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                    CoinDots(r.junkValue),
                  ],
                ),
              ),
              ...section(s.t('cleanup_full'), s.t('cleanup_full_note', {'n': fmtInt(r.storageCap)}), r.full),
            ],
          );
        },
      ),
    );
  }
}
