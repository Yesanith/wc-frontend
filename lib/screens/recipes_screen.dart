import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/recipes.dart';
import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'goals_screen.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  String _query = '';
  bool _legendaryOnly = true;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(langProvider);
    final library = ref.watch(recipeLibraryProvider);

    return AsyncView<RecipeLibrary>(
      value: library,
      onRetry: () => ref.invalidate(recipeLibraryProvider),
      builder: (lib) {
        if (lib.roots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(s.t('no_recipe_data'), style: const TextStyle(color: AppColors.muted, height: 1.5)),
          );
        }
        final list = lib.roots.where((r) {
          if (_legendaryOnly && !r.isLegendary) return false;
          if (_query.isEmpty) return true;
          return lib.label(r.node, lang).toLowerCase().contains(_query);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    decoration: fieldDecoration(
                      s.t('search_recipes'),
                      prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text(s.t('legendaries')),
                        selected: _legendaryOnly,
                        onSelected: (_) => setState(() => _legendaryOnly = true),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(s.t('all')),
                        selected: !_legendaryOnly,
                        onSelected: (_) => setState(() => _legendaryOnly = false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final root = list[i];
                  return AppCard(
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => RecipeDetailScreen(root: root)),
                  ),
                           padding: const EdgeInsets.all(10),
                           child: Row(
                          children: [
                            ItemIcon(url: root.node.icon, rarity: root.node.rarity, size: 42),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(lib.label(root.node, lang),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFF6E6859)),
                          ],
                        ),
                         );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.root});

  final RecipeRoot root;

  Future<void> _createGoal(BuildContext context, WidgetRef ref, RecipeLibrary lib, AppLang lang) async {
    final s = ref.read(stringsProvider);
    final name = lib.label(root.node, lang);
    final goal = await ref.read(goalsProvider.notifier).create(name);
    final materials = baseMaterials(root.node);
    for (final e in materials.entries) {
      await ref.read(goalsProvider.notifier).setItem(goal.id, e.key, e.value);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('goal_created'))));
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GoalDetailScreen(goalId: goal.id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(langProvider);
    final lib = ref.watch(recipeLibraryProvider).valueOrNull ?? RecipeLibrary.empty;
    final totals = ref.watch(accountTotalsProvider).valueOrNull ?? const <int, int>{};
    final materials = baseMaterials(root.node);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(lib.label(root.node, lang), style: display(20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          FilledButton.icon(
            onPressed: () => _createGoal(context, ref, lib, lang),
            icon: const Icon(Icons.flag_outlined),
            label: Text(s.t('create_goal_from')),
          ),
          const SizedBox(height: 18),
          SectionHeader(title: s.t('base_materials'), trailing: '${materials.length}'),
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final e in materials.entries)
                  _MaterialRow(itemId: e.key, need: e.value, have: totals[e.key] ?? 0),
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
                for (final child in root.node.children) _TreeNode(node: child, lib: lib, lang: lang),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(s.t('recipe_source_note'), style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.hint)),
        ],
      ),
    );
  }
}

class _MaterialRow extends ConsumerWidget {
  const _MaterialRow({required this.itemId, required this.need, required this.have});

  final int itemId;
  final int need;
  final int have;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemProvider(itemId)).valueOrNull;
    final name = (item?['name'] as String?) ?? s.t('item_n', {'id': itemId});
    final done = have >= need;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ItemIcon(url: item?['icon'] as String?, rarity: item?['rarity'] as String?, size: 34),
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
    );
  }
}

class _TreeNode extends StatelessWidget {
  const _TreeNode({required this.node, required this.lib, required this.lang});

  final RecipeNode node;
  final RecipeLibrary lib;
  final AppLang lang;

  @override
  Widget build(BuildContext context) {
    final title = Row(
      children: [
        ItemIcon(url: node.icon, rarity: node.rarity, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Text('${fmtInt(node.count)} x ${lib.label(node, lang)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
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
          for (final child in node.children) _TreeNode(node: child, lib: lib, lang: lang),
        ],
      ),
    );
  }
}
