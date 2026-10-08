import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/item_index.dart';
import '../services/recipe_book.dart';
import '../state/craft_profit.dart';
import '../state/items.dart';
import '../state/market.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import 'crafting_screen.dart';

/// icons are fetched for this many rows at a time, as they scroll in
const _chunk = 40;

/// what is worth making: the recipes that earn the most from the prices of the trading post now
class CraftProfitScreen extends ConsumerStatefulWidget {
  const CraftProfitScreen({super.key});

  @override
  ConsumerState<CraftProfitScreen> createState() => _CraftProfitScreenState();
}

class _CraftProfitScreenState extends ConsumerState<CraftProfitScreen> {
  String? _discipline;
  bool _byReturn = false;
  bool _onlyLearned = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final book = ref.watch(recipeBookProvider);
    final prices = ref.watch(allPricesProvider);
    final index = ref.watch(itemIndexProvider).valueOrNull ?? ItemIndex.empty;
    final learned = ref.watch(learnedForProfitProvider);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('craft_profit'), style: display(20, color: AppColors.accent)),
      ),
      body: AsyncView<RecipeBook>(
        value: book,
        onRetry: () => ref.invalidate(recipeBookProvider),
        builder: (b) => AsyncView<Map<int, TpPrice>>(
          value: prices,
          onRetry: () => ref.invalidate(allPricesProvider),
          builder: (market) {
            final ranked = rankCrafts(
              b,
              market,
              discipline: _discipline,
              learned: _onlyLearned ? learned : null,
              byReturn: _byReturn,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(s.t('craft_profit_note'),
                      style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted)),
                ),
                const SizedBox(height: 12),
                ChipRow(
                  children: [
                    ChoiceChip(
                      label: Text(s.t('all')),
                      selected: _discipline == null,
                      onSelected: (_) => setState(() => _discipline = null),
                    ),
                    for (final d in b.disciplines)
                      if (d != mysticForge)
                        ChoiceChip(
                          label: Text(disciplineLabel(s, d)),
                          selected: _discipline == d,
                          onSelected: (_) => setState(() => _discipline = d),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
                ChipRow(
                  height: 40,
                  children: [
                    ChoiceChip(
                      label: Text(s.t('sort_profit')),
                      selected: !_byReturn,
                      onSelected: (_) => setState(() => _byReturn = false),
                    ),
                    ChoiceChip(
                      label: Text(s.t('sort_return')),
                      selected: _byReturn,
                      onSelected: (_) => setState(() => _byReturn = true),
                    ),
                    if (learned != null)
                      FilterChip(
                        label: Text(s.t('recipe_learned')),
                        selected: _onlyLearned,
                        onSelected: (on) => setState(() => _onlyLearned = on),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (ranked.isEmpty)
                  Padding(padding: const EdgeInsets.all(24), child: EmptyNote(s.t('craft_profit_empty')))
                else
                  for (var i = 0; i < ranked.length; i++)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: _ProfitRow(
                        entry: ranked[i],
                        name: index.nameOf(ranked[i].itemId) ?? s.t('item_n', {'id': ranked[i].itemId}),
                        chunkKey: _chunkKey(ranked, i),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// the rows of one chunk share one request for icons
  String _chunkKey(List<CraftProfit> rows, int i) {
    final from = i - i % _chunk;
    final to = from + _chunk > rows.length ? rows.length : from + _chunk;
    return [for (var j = from; j < to; j++) rows[j].itemId].join(',');
  }
}

class _ProfitRow extends ConsumerWidget {
  const _ProfitRow({required this.entry, required this.name, required this.chunkKey});

  final CraftProfit entry;
  final String name;
  final String chunkKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemBatchProvider(chunkKey)).valueOrNull?[entry.itemId];
    final percent = (entry.returnOnCost * 100).round();
    return AppCard(
      onTap: () => openPanel(context, (_) => CraftingDetailScreen(itemId: entry.itemId)),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final d in entry.recipe.disciplines) Pill(disciplineLabel(s, d)),
                    Pill('+$percent%', color: AppColors.green),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${s.t('craft_cost')} ', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    CoinText(entry.cost, size: 11),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(s.t('profit'), style: TextStyle(fontSize: 11, color: AppColors.muted)),
              CoinText(entry.profit, size: 14),
            ],
          ),
        ],
      ),
    );
  }
}
