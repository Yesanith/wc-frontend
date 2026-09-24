import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/crafting.dart';
import '../state/items.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import 'goals_screen.dart';
import 'trading_screen.dart';

class CraftingDetailScreen extends ConsumerStatefulWidget {
  const CraftingDetailScreen({super.key, required this.itemId});

  final int itemId;

  @override
  ConsumerState<CraftingDetailScreen> createState() => _CraftingDetailScreenState();
}

class _CraftingDetailScreenState extends ConsumerState<CraftingDetailScreen> {
  int _quantity = 1;

  /// the base materials of the current plan become a goal
  Future<void> _createGoal(Json? item, Map<int, int> leaves) async {
    final s = ref.read(stringsProvider);
    final base = (item?['name'] as String?) ?? s.t('item_n', {'id': widget.itemId});
    final name = _quantity > 1 ? '$base x$_quantity' : base;
    final goals = ref.read(goalsProvider.notifier);
    final goal = await goals.create(name);
    for (final e in leaves.entries) {
      await goals.setItem(goal.id, e.key, e.value);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('goal_created'))));
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GoalDetailScreen(goalId: goal.id)));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final tree = ref.watch(craftTreeProvider(widget.itemId));
    final prices = ref.watch(craftPricesProvider(widget.itemId)).valueOrNull ?? const <int, int>{};
    final totals = ref.watch(accountTotalsProvider).valueOrNull ?? const <int, int>{};
    final item = ref.watch(itemProvider(widget.itemId)).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text((item?['name'] as String?) ?? s.t('crafting'), style: display(20)),
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
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.5)),
              ),
            );
          }
          // scaling is local, so the plus button never triggers a reload
          final plan = planFor(root, _quantity);
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Panel(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(s.t('quantity'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
                    ),
                    IconButton(
                      onPressed: _quantity <= 1 ? null : () => setState(() => _quantity--),
                      icon: const Icon(Icons.remove_circle_outline, color: AppColors.gold),
                    ),
                    Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.gold),
                    ),
                  ],
                ),
              ),
              if (root.disciplines.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final d in root.disciplines) Pill(d)],
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _createGoal(item, leaves),
                icon: const Icon(Icons.flag_outlined),
                label: Text(s.t('create_goal_from')),
              ),
              const SizedBox(height: 16),
              _CostPanel(missingCost: missingCost, ownedValue: ownedValue, buyInstead: buyInstead),
              const SizedBox(height: 22),
              SectionHeader(title: s.t('base_materials'), trailing: '${leaves.length}'),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    for (final e in leaves.entries)
                      _LeafRow(itemId: e.key, need: e.value, have: totals[e.key] ?? 0),
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
  const _CostPanel({required this.missingCost, required this.ownedValue, required this.buyInstead});

  final int missingCost;
  final int ownedValue;
  final int buyInstead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final cheaperToBuy = buyInstead > 0 && buyInstead < missingCost;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.t('missing_materials_cost'),
                    style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
              ),
              CoinText(missingCost, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(s.t('already_owned_value'),
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ),
              CoinText(ownedValue, size: 13),
            ],
          ),
          if (buyInstead > 0) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.track, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(s.t('buy_instead'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
                ),
                CoinText(buyInstead, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              cheaperToBuy ? s.t('buying_cheaper') : s.t('crafting_cheaper'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cheaperToBuy ? AppColors.red : AppColors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LeafRow extends ConsumerWidget {
  const _LeafRow({required this.itemId, required this.need, required this.have});

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
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TradingItemScreen(itemId: itemId)),
      ),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: done ? AppColors.muted : AppColors.text)),
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
