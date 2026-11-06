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

/// the most rows shown
const _shown = 200;

/// what is worth making: the recipes that earn the most from the prices of the trading post now. the server ranks them, from the recipes and
/// the prices it keeps, and gives the answer at once; without a server the app ranks them itself, which takes a while
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
    final learned = ref.watch(learnedForProfitProvider);
    // a filter the server does not know is applied here, to what it gives of the most
    final server = ref.watch(
      serverCraftProfitProvider((discipline: _discipline, byReturn: _byReturn, wide: _onlyLearned && learned != null)),
    );

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('craft_profit'), style: display(20, color: AppColors.accent)),
      ),
      body: AsyncView<RecipeBook>(
        value: book,
        onRetry: () => ref.invalidate(recipeBookProvider),
        builder: (b) {
          Widget page(List<CraftProfit> rows, DateTime? readAt) => _Page(
            book: b,
            rows: rows,
            readAt: readAt,
            discipline: _discipline,
            byReturn: _byReturn,
            onlyLearned: _onlyLearned,
            canFilterLearned: learned != null,
            onDiscipline: (d) => setState(() => _discipline = d),
            onByReturn: (v) => setState(() => _byReturn = v),
            onOnlyLearned: (v) => setState(() => _onlyLearned = v),
          );

          if (server.isLoading) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final answer = server.valueOrNull;
          if (answer != null) {
            final rows = _onlyLearned && learned != null
                ? answer.rows.where((c) => learned.contains(c.recipeId)).take(_shown).toList()
                : answer.rows;
            return page(rows, answer.updatedAt);
          }
          return _OwnRanking(
            book: b,
            discipline: _discipline,
            byReturn: _byReturn,
            learned: _onlyLearned ? learned : null,
            builder: (rows) => page(rows, null),
          );
        },
      ),
    );
  }
}

/// the ranking made on the device from every price of the trading post, when there is no server to give it
class _OwnRanking extends ConsumerWidget {
  const _OwnRanking({
    required this.book,
    required this.discipline,
    required this.byReturn,
    required this.learned,
    required this.builder,
  });

  final RecipeBook book;
  final String? discipline;
  final bool byReturn;
  final Set<int>? learned;
  final Widget Function(List<CraftProfit> rows) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<Map<int, TpPrice>>(
      value: ref.watch(allPricesProvider),
      onRetry: () => ref.invalidate(allPricesProvider),
      builder: (market) => builder(
        rankCrafts(book, market, discipline: discipline, learned: learned, byReturn: byReturn, limit: _shown),
      ),
    );
  }
}

class _Page extends ConsumerWidget {
  const _Page({
    required this.book,
    required this.rows,
    required this.readAt,
    required this.discipline,
    required this.byReturn,
    required this.onlyLearned,
    required this.canFilterLearned,
    required this.onDiscipline,
    required this.onByReturn,
    required this.onOnlyLearned,
  });

  final RecipeBook book;
  final List<CraftProfit> rows;

  /// when the server read the prices, null when the ranking was made here
  final DateTime? readAt;
  final String? discipline;
  final bool byReturn;
  final bool onlyLearned;
  final bool canFilterLearned;
  final ValueChanged<String?> onDiscipline;
  final ValueChanged<bool> onByReturn;
  final ValueChanged<bool> onOnlyLearned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final index = ref.watch(itemIndexProvider).valueOrNull ?? ItemIndex.empty;
    final age = readAt == null ? null : DateTime.now().difference(readAt!).inMinutes;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(s.t('craft_profit_note'), style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted)),
        ),
        if (age != null && age >= 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text(s.t('craft_profit_age', {'n': age}), style: TextStyle(fontSize: 11, color: AppColors.hint)),
          ),
        const SizedBox(height: 12),
        ChipRow(
          children: [
            ChoiceChip(label: Text(s.t('all')), selected: discipline == null, onSelected: (_) => onDiscipline(null)),
            for (final d in book.disciplines)
              if (d != mysticForge)
                ChoiceChip(
                  label: Text(disciplineLabel(s, d)),
                  selected: discipline == d,
                  onSelected: (_) => onDiscipline(d),
                ),
          ],
        ),
        const SizedBox(height: 8),
        ChipRow(
          height: 40,
          children: [
            ChoiceChip(label: Text(s.t('sort_profit')), selected: !byReturn, onSelected: (_) => onByReturn(false)),
            ChoiceChip(label: Text(s.t('sort_return')), selected: byReturn, onSelected: (_) => onByReturn(true)),
            if (canFilterLearned)
              FilterChip(label: Text(s.t('recipe_learned')), selected: onlyLearned, onSelected: onOnlyLearned),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Padding(padding: const EdgeInsets.all(24), child: EmptyNote(s.t('craft_profit_empty')))
        else
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _ProfitRow(
                entry: rows[i],
                name: index.nameOf(rows[i].itemId) ?? s.t('item_n', {'id': rows[i].itemId}),
                chunkKey: _chunkKey(rows, i),
              ),
            ),
      ],
    );
  }

  /// the rows of one chunk share one request for icons
  static String _chunkKey(List<CraftProfit> rows, int i) {
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
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final d in entry.disciplines) Pill(disciplineLabel(s, d)),
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
