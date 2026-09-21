import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/item_index.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'trading_screen.dart';

/// pick an item, then see what crafting it would take
class CraftingScreen extends ConsumerStatefulWidget {
  const CraftingScreen({super.key});

  @override
  ConsumerState<CraftingScreen> createState() => _CraftingScreenState();
}

class _CraftingScreenState extends ConsumerState<CraftingScreen> {
  final _ctrl = TextEditingController();
  List<IndexedItem> _results = const [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _search(String q) {
    final index = ref.read(itemIndexProvider).valueOrNull ?? ItemIndex.empty;
    setState(() => _results = index.search(q));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final index = ref.watch(itemIndexProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(s.t('crafting_intro'), style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          onChanged: _search,
          decoration: fieldDecoration(
            s.t('search_items'),
            prefixIcon: const Icon(Icons.search, color: AppColors.gold),
          ),
        ),
        if (index.isLoading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2, color: AppColors.gold),
        ],
        const SizedBox(height: 12),
        for (final item in _results.take(20))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF6E6859)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => CraftingDetailScreen(itemId: item.id)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

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
    final key = '${widget.itemId}:$_quantity';
    final tree = ref.watch(craftTreeProvider(key));
    final cost = ref.watch(craftCostProvider(key));
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
        onRetry: () => ref.invalidate(craftTreeProvider(key)),
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
          final leaves = craftLeaves(root);
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
                    Text('$_quantity',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
              const SizedBox(height: 16),
              cost.when(
                data: (c) => _CostPanel(cost: c),
                loading: () => const Panel(
                  child: Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
                ),
                error: (e, _) => ErrorBox(message: '$e', onRetry: () => ref.invalidate(craftCostProvider(key))),
              ),
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
                    for (final child in root.children) _CraftNodeTile(node: child, totals: totals),
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
  const _CostPanel({required this.cost});

  final CraftCost cost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final cheaperToBuy = cost.buyOutputCost > 0 && cost.buyOutputCost < cost.missingCost;

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
              CoinText(cost.missingCost, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(s.t('already_owned_value'),
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ),
              CoinText(cost.ownedValue, size: 13),
            ],
          ),
          if (cost.buyOutputCost > 0) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.track, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(s.t('buy_instead'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
                ),
                CoinText(cost.buyOutputCost, size: 16),
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
  const _CraftNodeTile({required this.node, required this.totals});

  final CraftNode node;
  final Map<int, int> totals;

  @override
  Widget build(BuildContext context) {
    final have = totals[node.itemId] ?? 0;
    final title = Row(
      children: [
        ItemIcon(url: node.item?['icon'] as String?, rarity: node.item?['rarity'] as String?, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Text('${fmtInt(node.count)} x ${node.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        if (have > 0)
          Text(fmtInt(have),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: have >= node.count ? AppColors.green : AppColors.muted)),
      ],
    );

    if (node.isLeaf) {
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
          for (final child in node.children) _CraftNodeTile(node: child, totals: totals),
        ],
      ),
    );
  }
}
