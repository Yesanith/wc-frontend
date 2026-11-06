import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../state/account.dart';
import '../state/goals.dart';
import '../state/items.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import 'crafting_screen.dart';

/// the things the player wants made, with one list of everything they take: what is already in the
/// bank, what is left to get and what that costs at the trading post
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final goals = ref.watch(goalsProvider);
    final trees = ref.watch(goalTreesProvider);
    final prices = ref.watch(goalPricesProvider).valueOrNull ?? const <int, int>{};
    final owned = ref.watch(accountTotalsProvider).valueOrNull ?? const <int, int>{};
    final plans = ref.watch(goalPlansProvider);
    final list = buildShoppingList([for (final (_, plan) in plans) plan], owned, prices);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('goals'), style: display(20, color: AppColors.accent)),
        actions: [
          if (goals.isNotEmpty)
            IconButton(
              tooltip: s.t('goals_share'),
              icon: const Icon(Icons.share_outlined),
              onPressed: () => _share(ref, s.t('goals'), s.t('goals_share_missing'), goals, list),
            ),
          if (goals.isNotEmpty)
            IconButton(
              tooltip: s.t('goals_clear'),
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClear(context, ref, s.t('goals_clear'), s.t('goals_clear_ask'), s.t('cancel')),
            ),
        ],
      ),
      body: goals.isEmpty
          ? Padding(padding: const EdgeInsets.all(24), child: EmptyNote(s.t('goals_empty')))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    children: [for (final g in goals) _GoalRow(goal: g)],
                  ),
                ),
                const SizedBox(height: 16),
                if (trees.isLoading && list.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                else if (trees.hasError)
                  ErrorBox(error: trees.error, onRetry: () => ref.invalidate(goalTreesProvider))
                else ...[
                  _TotalsPanel(list: list),
                  const SizedBox(height: 22),
                  SectionHeader(title: s.t('goals_shopping'), trailing: '${list.rows.length}'),
                  const SizedBox(height: 10),
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      children: [for (final r in list.rows) MaterialRow(itemId: r.itemId, need: r.need, have: r.have)],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  /// the goals and what is still to get, as text for a message or a note
  Future<void> _share(WidgetRef ref, String title, String missingLabel, List<Goal> goals, ShoppingList list) {
    String name(int id) => (ref.read(itemProvider(id)).valueOrNull?['name'] as String?) ?? '#$id';
    final text = goalsShareText(
      title: '$title · Wondrous Compass',
      missingLabel: missingLabel,
      goals: [for (final g in goals) (name(g.itemId), g.quantity)],
      missing: [
        for (final r in list.rows)
          if (!r.done) (name(r.itemId), r.missing),
      ],
    );
    return SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref, String title, String body, String cancel) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(cancel)),
          TextButton(onPressed: () => Navigator.pop(dialog, true), child: Text(title)),
        ],
      ),
    );
    if (yes == true) await ref.read(goalsProvider.notifier).clear();
  }
}

class _GoalRow extends ConsumerWidget {
  const _GoalRow({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemProvider(goal.itemId)).valueOrNull;
    final name = (item?['name'] as String?) ?? s.t('item_n', {'id': goal.itemId});
    final goals = ref.read(goalsProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => openPanel(context, (_) => CraftingDetailScreen(itemId: goal.itemId)),
              child: Row(
                children: [
                  ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: '-',
            onPressed: goal.quantity <= 1 ? null : () => goals.setQuantity(goal.itemId, goal.quantity - 1),
            icon: Icon(Icons.remove_circle_outline, color: AppColors.gold),
          ),
          Text('${goal.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          IconButton(
            tooltip: '+',
            onPressed:
                goal.quantity >= maxGoalQuantity ? null : () => goals.setQuantity(goal.itemId, goal.quantity + 1),
            icon: Icon(Icons.add_circle_outline, color: AppColors.gold),
          ),
          IconButton(
            tooltip: s.t('goal_remove'),
            onPressed: () => goals.remove(goal.itemId),
            icon: Icon(Icons.close, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _TotalsPanel extends ConsumerWidget {
  const _TotalsPanel({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (list.complete) {
      return NoticeCard(text: s.t('goals_complete'), icon: Icons.check_circle_outline, accentColor: AppColors.green);
    }
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.t('missing_materials_cost'), style: TextStyle(fontSize: 14, color: AppColors.textSoft)),
              ),
              CoinText(list.missingCost, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(s.t('already_owned_value'), style: TextStyle(fontSize: 13, color: AppColors.muted)),
              ),
              CoinText(list.ownedValue, size: 13),
            ],
          ),
          if (list.unpriced > 0) ...[
            const SizedBox(height: 6),
            Text(
              s.t('unpriced_materials', {'n': list.unpriced}),
              style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.hint),
            ),
          ],
        ],
      ),
    );
  }
}
