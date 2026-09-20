import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// share of the goal that's covered by what the account already owns
double goalProgress(Goal g, Map<int, int> totals) {
  var need = 0;
  var have = 0;
  for (final i in g.items) {
    need += i.need;
    final owned = totals[i.itemId] ?? 0;
    have += owned > i.need ? i.need : owned;
  }
  return need == 0 ? 0 : have / need;
}

Future<String?> _askName(BuildContext context, S s, {String initial = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(s.t('new_goal')),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: fieldDecoration(s.t('goal_name_hint')),
        onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.t('cancel'))),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: Text(s.t('create'))),
      ],
    ),
  );
}

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final name = await _askName(context, s);
    if (name == null || name.isEmpty) return;
    final goal = await ref.read(goalsProvider.notifier).create(name);
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GoalDetailScreen(goalId: goal.id)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final goals = ref.watch(goalsProvider);
    final totals = ref.watch(accountTotalsProvider).valueOrNull ?? const <int, int>{};

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('goals'), style: display(20)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.onGold,
        icon: const Icon(Icons.add),
        label: Text(s.t('new_goal')),
      ),
      body: goals.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Text(s.t('goals_empty'),
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.5)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              itemCount: goals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final g = goals[i];
                final progress = goalProgress(g, totals);
                return Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => GoalDetailScreen(goalId: g.id)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(g.name, style: display(18))),
                              Text('${(progress * 100).round()}%',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(s.t('n_items', {'n': g.items.length}),
                              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          const SizedBox(height: 10),
                          Bar(value: progress, color: progress >= 1 ? AppColors.green : AppColors.gold),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.t('delete_goal')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.t('delete'))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(goalsProvider.notifier).remove(goalId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final goals = ref.watch(goalsProvider);
    Goal? goal;
    for (final g in goals) {
      if (g.id == goalId) goal = g;
    }
    final totalsAsync = ref.watch(accountTotalsProvider);
    final totals = totalsAsync.valueOrNull ?? const <int, int>{};
    final items = ref.watch(goalItemsProvider).valueOrNull ?? const <int, Json>{};

    if (goal == null) {
      return Scaffold(appBar: AppBar(backgroundColor: AppColors.bg), body: const SizedBox.shrink());
    }
    final g = goal;
    final progress = goalProgress(g, totals);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(g.name, style: display(20)),
        actions: [
          IconButton(
            tooltip: s.t('delete_goal'),
            onPressed: () => _delete(context, ref),
            icon: const Icon(Icons.delete_outline, color: AppColors.muted),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(accountTotalsProvider);
          try {
            await ref.read(accountTotalsProvider.future);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Panel(
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress.clamp(0.0, 1.0).toDouble(),
                          strokeWidth: 9,
                          backgroundColor: AppColors.track,
                          color: progress >= 1 ? AppColors.green : AppColors.gold,
                        ),
                        Center(
                          child: Text('${(progress * 100).round()}%',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.t('total_progress'),
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Text(s.t('n_items', {'n': g.items.length}),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        if (totalsAsync.isLoading) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(minHeight: 2, color: AppColors.gold),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (g.items.isEmpty)
              Panel(
                child: Text(s.t('goal_items_empty'), style: const TextStyle(color: AppColors.muted, height: 1.5)),
              ),
            for (final gi in g.items) ...[
              _GoalItemRow(goalId: g.id, gi: gi, item: items[gi.itemId], have: totals[gi.itemId] ?? 0),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoalItemRow extends ConsumerWidget {
  const _GoalItemRow({required this.goalId, required this.gi, required this.item, required this.have});

  final String goalId;
  final GoalItem gi;
  final Json? item;
  final int have;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final name = (item?['name'] as String?) ?? s.t('item_n', {'id': gi.itemId});
    final done = have >= gi.need;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAddToGoalSheet(context, itemId: gi.itemId, itemName: name, goalId: goalId, need: gi.need),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: done ? AppColors.muted : AppColors.text)),
                        ),
                        Text('${fmtInt(have)} / ${fmtInt(gi.need)}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: done ? AppColors.green : AppColors.gold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Bar(value: gi.need == 0 ? 0 : have / gi.need, color: done ? AppColors.green : AppColors.gold),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// pick a goal (or make one) and set how many of this item it needs.
/// setting the amount to 0 removes the item from the goal
void showAddToGoalSheet(
  BuildContext context, {
  required int itemId,
  required String itemName,
  String? goalId,
  int need = 1,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _AddToGoalSheet(itemId: itemId, itemName: itemName, goalId: goalId, need: need),
  );
}

class _AddToGoalSheet extends ConsumerStatefulWidget {
  const _AddToGoalSheet({required this.itemId, required this.itemName, this.goalId, required this.need});

  final int itemId;
  final String itemName;
  final String? goalId;
  final int need;

  @override
  ConsumerState<_AddToGoalSheet> createState() => _AddToGoalSheetState();
}

class _AddToGoalSheetState extends ConsumerState<_AddToGoalSheet> {
  late final TextEditingController _count = TextEditingController(text: '${widget.need}');
  String? _goalId;

  @override
  void initState() {
    super.initState();
    _goalId = widget.goalId;
  }

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  Future<void> _newGoal() async {
    final s = ref.read(stringsProvider);
    final name = await _askName(context, s);
    if (name == null || name.isEmpty) return;
    final goal = await ref.read(goalsProvider.notifier).create(name);
    if (mounted) setState(() => _goalId = goal.id);
  }

  Future<void> _save() async {
    final id = _goalId;
    if (id == null) return;
    final need = int.tryParse(_count.text.trim()) ?? 0;
    await ref.read(goalsProvider.notifier).setItem(id, widget.itemId, need);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final goals = ref.watch(goalsProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.t('add_to_goal'), style: display(20)),
            const SizedBox(height: 2),
            Text(widget.itemName, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in goals)
                  ChoiceChip(
                    label: Text(g.name),
                    selected: _goalId == g.id,
                    onSelected: (_) => setState(() => _goalId = g.id),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(s.t('new_goal')),
                  onPressed: _newGoal,
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _count,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: fieldDecoration(s.t('amount_needed')),
            ),
            const SizedBox(height: 6),
            Text(s.t('zero_removes'), style: const TextStyle(fontSize: 12, color: AppColors.hint)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _goalId == null ? null : _save,
              child: Text(s.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
