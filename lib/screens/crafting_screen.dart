import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/recipe_book.dart';
import '../state/account.dart';
import '../state/crafting.dart';
import '../state/goals.dart';
import '../state/items.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import 'trading_screen.dart';

class CraftingDetailScreen extends ConsumerStatefulWidget {
  const CraftingDetailScreen({super.key, required this.itemId});

  final int itemId;

  @override
  ConsumerState<CraftingDetailScreen> createState() => _CraftingDetailScreenState();
}

class _CraftingDetailScreenState extends ConsumerState<CraftingDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final tree = ref.watch(craftTreeProvider(widget.itemId));
    final prices = ref.watch(craftPricesProvider(widget.itemId)).valueOrNull ?? const <int, int>{};
    final totals = ref.watch(accountTotalsProvider).valueOrNull ?? const <int, int>{};
    final item = ref.watch(itemProvider(widget.itemId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text((item?['name'] as String?) ?? s.t('crafting')),
        actions: [
          IconButton(
            tooltip: s.t('goal_add'),
            icon: const Icon(Icons.playlist_add),
            onPressed: () async {
              final goals = ref.read(goalsProvider.notifier);
              if (!goals.has(widget.itemId) && ref.read(goalsProvider).length >= maxGoals) {
                showToast(context, s.t('goals_full'));
                return;
              }
              await goals.add(widget.itemId, _quantity);
              if (context.mounted) showToast(context, s.t('goal_added'));
            },
          ),
        ],
      ),
      body: AsyncView<CraftNode>(
        value: tree,
        onRetry: () => ref.invalidate(craftTreeProvider(widget.itemId)),
        builder: (root) {
          if (root.isLeaf) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(s.t('no_recipe'),
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, height: 1.5)),
              ),
            );
          }
          // scaling is local, so the plus button never triggers a reload. the
          // plan takes intermediates the account already has out of the tree
          final plan = planWithStock(root, _quantity, totals);
          final leaves = craftLeaves(plan);
          var missingCost = 0;
          var ownedValue = 0;
          for (final e in leaves.entries) {
            final unit = prices[e.key] ?? 0;
            final have = totals[e.key] ?? 0;
            missingCost += unit * (have >= e.value ? 0 : e.value - have);
            ownedValue += unit * (have > e.value ? e.value : have);
          }
          final buyInstead = (prices[root.itemId] ?? 0) * _quantity;
          // what every material of the plan is worth, owned or not: the fair
          // comparison with buying, since owned materials could be sold too
          final materialValue = missingCost + ownedValue;
          final unpriced = leaves.keys.where((id) => (prices[id] ?? 0) == 0).length;

          // on a site the recipe is four boxes of figures, the tree at the left and the materials with the verdict at the right
          if (SiteScope.of(context)) {
            final cheaperToBuy = buyInstead > 0 && buyInstead < materialValue;
            Widget box(String label, Widget value, [String note = '']) => Expanded(
                  child: Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label.caps,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: AppColors.muted)),
                        const SizedBox(height: 4),
                        value,
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(note, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ],
                    ),
                  ),
                );
            final tree = Panel(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 0, 6),
                      child: Text(s.t('recipe_tree'), style: display(18))),
                  for (final child in plan.children) _CraftNodeTile(line: child, totals: totals),
                ],
              ),
            );
            final side = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('base_materials'), style: display(18)),
                      const SizedBox(height: 4),
                      for (final e in leaves.entries)
                        MaterialRow(itemId: e.key, need: e.value, have: totals[e.key] ?? 0),
                    ],
                  ),
                ),
                if (buyInstead > 0) ...[
                  const SizedBox(height: 14),
                  Panel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cheaperToBuy ? s.t('buying_cheaper') : s.t('crafting_cheaper'),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: cheaperToBuy ? AppColors.red : AppColors.green)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                                child:
                                    Text(s.t('buy_instead'), style: TextStyle(fontSize: 13, color: AppColors.muted))),
                            CoinText(buyInstead, size: 14),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                                child: Text(s.t('already_owned_value'),
                                    style: TextStyle(fontSize: 13, color: AppColors.muted))),
                            CoinText(ownedValue, size: 14),
                          ],
                        ),
                        if (unpriced > 0) ...[
                          const SizedBox(height: 6),
                          Text(s.t('unpriced_materials', {'n': unpriced}),
                              style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.hint)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  children: [
                    ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            [
                              for (final d in root.disciplines)
                                d == mysticForge ? s.t('mystic_forge') : disciplineLabel(s, d)
                            ].join(' · ').caps,
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.gold),
                          ),
                          const SizedBox(height: 2),
                          Text((item?['name'] as String?) ?? s.t('crafting'), style: display(30)),
                          // whether the character's account knows the recipe, as on a phone
                          ...[
                            for (final p in _learnedPill(ref, s, widget.itemId))
                              Padding(padding: const EdgeInsets.only(top: 6), child: p),
                          ],
                        ],
                      ),
                    ),
                    Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _quantity <= 1 ? null : () => setState(() => _quantity--),
                            icon: Icon(Icons.remove_circle_outline, color: AppColors.gold),
                          ),
                          Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          IconButton(
                            onPressed: () => setState(() => _quantity++),
                            icon: Icon(Icons.add_circle_outline, color: AppColors.gold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () async {
                        final goals = ref.read(goalsProvider.notifier);
                        if (!goals.has(widget.itemId) && ref.read(goalsProvider).length >= maxGoals) {
                          showToast(context, s.t('goals_full'));
                          return;
                        }
                        await goals.add(widget.itemId, _quantity);
                        if (context.mounted) showToast(context, s.t('goal_added'));
                      },
                      icon: const Icon(Icons.playlist_add),
                      label: Text(s.t('goal_add')),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    box(s.t('material_value'), CoinText(materialValue, size: 24), s.t('counting_held')),
                    const SizedBox(width: 14),
                    box(s.t('buy_instead'),
                        buyInstead > 0 ? CoinText(buyInstead, size: 24) : Text('–', style: display(24))),
                    const SizedBox(width: 14),
                    box(s.t('missing_materials_cost'), CoinText(missingCost, size: 24)),
                    const SizedBox(width: 14),
                    box(
                      s.t('craft_time_label'),
                      Text(
                          root.craftMs > 0
                              ? '${(root.craftMs / 1000).toStringAsFixed(root.craftMs % 1000 == 0 ? 0 : 1)} s'
                              : '–',
                          style: display(26)),
                      root.minRating > 0 ? s.t('craft_rating', {'n': root.minRating}) : '',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, box) {
                  if (box.maxWidth < 900) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [tree, const SizedBox(height: 16), side]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: tree),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: side)
                    ],
                  );
                }),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Panel(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(s.t('quantity'), style: TextStyle(fontSize: 14, color: AppColors.textSoft)),
                    ),
                    IconButton(
                      onPressed: _quantity <= 1 ? null : () => setState(() => _quantity--),
                      icon: Icon(Icons.remove_circle_outline, color: AppColors.gold),
                    ),
                    Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: Icon(Icons.add_circle_outline, color: AppColors.gold),
                    ),
                  ],
                ),
              ),
              if (root.disciplines.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in root.disciplines)
                      Pill(d == mysticForge ? s.t('mystic_forge') : disciplineLabel(s, d)),
                    if (root.minRating > 0) Pill(s.t('craft_rating', {'n': root.minRating})),
                    if (root.craftMs > 0)
                      Pill(s.t('craft_time',
                          {'t': (root.craftMs / 1000).toStringAsFixed(root.craftMs % 1000 == 0 ? 0 : 1)})),
                    ..._learnedPill(ref, s, widget.itemId),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _CostPanel(
                missingCost: missingCost,
                ownedValue: ownedValue,
                materialValue: materialValue,
                buyInstead: buyInstead,
                unpriced: unpriced,
              ),
              const SizedBox(height: 22),
              SectionHeader(title: s.t('base_materials'), trailing: '${leaves.length}'),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    for (final e in leaves.entries) MaterialRow(itemId: e.key, need: e.value, have: totals[e.key] ?? 0),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SectionHeader(title: s.t('recipe_tree')),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  children: [
                    for (final child in plan.children) _CraftNodeTile(line: child, totals: totals),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CostPanel extends ConsumerWidget {
  const _CostPanel({
    required this.missingCost,
    required this.ownedValue,
    required this.materialValue,
    required this.buyInstead,
    required this.unpriced,
  });

  final int missingCost;
  final int ownedValue;

  /// missing and owned together, what crafting really uses up
  final int materialValue;
  final int buyInstead;

  /// materials without a trading post price, left out of the sums
  final int unpriced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    // buying is compared with the value of all the materials, owned ones
    // included: using them costs what they would have sold for
    final cheaperToBuy = buyInstead > 0 && buyInstead < materialValue;

    // the four figures two by two, as the site has them in a row: what is still to buy, what is owned, the materials in all,
    // and buying it instead, coloured by which way is cheaper
    Widget figure(String label, int coins, {Color? tint, String? note}) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: tint?.withValues(alpha: 0.10) ?? AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: tint ?? AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.caps,
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: tint ?? AppColors.muted)),
                const SizedBox(height: 6),
                CoinText(coins, size: 16),
                if (note != null) ...[
                  const SizedBox(height: 4),
                  Text(note, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tint)),
                ],
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            figure(s.t('missing_materials_cost'), missingCost),
            const SizedBox(width: 10),
            figure(s.t('already_owned_value'), ownedValue),
          ]),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            figure(s.t('material_value'), materialValue),
            const SizedBox(width: 10),
            if (buyInstead > 0)
              figure(
                s.t('buy_instead'),
                buyInstead,
                tint: cheaperToBuy ? AppColors.red : AppColors.green,
                note: cheaperToBuy ? s.t('buying_cheaper') : s.t('crafting_cheaper'),
              )
            else
              const Expanded(child: SizedBox.shrink()),
          ]),
        ),
        if (unpriced > 0) ...[
          const SizedBox(height: 8),
          Text(s.t('unpriced_materials', {'n': unpriced}),
              style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.hint)),
        ],
      ],
    );
  }
}

/// one material with how much of it the account has against how much is needed
class MaterialRow extends ConsumerWidget {
  const MaterialRow({super.key, required this.itemId, required this.need, required this.have});

  final int itemId;
  final int need;
  final int have;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemProvider(itemId)).valueOrNull;
    final name = (item?['name'] as String?) ?? s.t('item_n', {'id': itemId});
    final done = have >= need;
    return InkWell(
      onTap: () => openPanel(context, (_) => TradingItemScreen(itemId: itemId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: done ? AppColors.muted : AppColors.text)),
                  const SizedBox(height: 6),
                  Bar(value: need == 0 ? 0 : have / need, color: done ? AppColors.green : AppColors.gold),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('${fmtInt(have)} / ${fmtInt(need)}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: done ? AppColors.green : AppColors.gold)),
          ],
        ),
      ),
    );
  }
}

class _CraftNodeTile extends StatelessWidget {
  const _CraftNodeTile({required this.line, required this.totals});

  final CraftLine line;
  final Map<int, int> totals;

  @override
  Widget build(BuildContext context) {
    final have = totals[line.itemId] ?? 0;
    final title = Row(
      children: [
        ItemIcon(url: line.node.item?['icon'] as String?, rarity: line.node.item?['rarity'] as String?, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Text('${fmtInt(line.count)} x ${line.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        if (have > 0)
          Text(fmtInt(have),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: have >= line.count ? AppColors.green : AppColors.muted)),
      ],
    );

    if (line.isLeaf) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7), child: title);
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.only(left: 16),
        iconColor: AppColors.gold,
        collapsedIconColor: AppColors.muted,
        title: title,
        children: [
          for (final child in line.children) _CraftNodeTile(line: child, totals: totals),
        ],
      ),
    );
  }
}

/// "learned" or "not learned" for a regular recipe, nothing for forge ones or
/// when the key cannot read unlocks
List<Widget> _learnedPill(WidgetRef ref, S s, int itemId) {
  final recipe = ref.watch(recipeBookProvider).valueOrNull?.recipeFor(itemId);
  final learned = ref.watch(learnedRecipesProvider).valueOrNull;
  if (recipe == null || recipe.id <= 0 || learned == null) return const [];
  final known = learned.contains(recipe.id);
  return [Pill(s.t(known ? 'recipe_learned' : 'recipe_not_learned'), color: known ? AppColors.green : AppColors.red)];
}
