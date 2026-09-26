import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/item_index.dart';
import '../services/recipe_book.dart';
import '../state/account.dart';
import '../state/items.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'crafting_screen.dart';

/// every recipe in one place: regular crafting from the api and mystic
/// forge recipes pulled from item descriptions. opening one shows the
/// crafting calculator for it
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

/// the first tab, then one per discipline
const _legendary = 'legendary';

/// icons are fetched for this many rows at a time, as they scroll in
const _chunk = 50;

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _filter = _legendary;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }

  bool _matchesFilter(List<BookRecipe> recipes) {
    switch (_filter) {
      case _legendary:
        return recipes.any((r) => r.legendary);
      default:
        return recipes.any((r) => r.disciplines.contains(_filter));
    }
  }

  String _label(S s, String discipline) {
    if (discipline == _legendary) return s.t('legendaries');
    if (discipline == mysticForge) return s.t('mystic_forge');
    return disciplineLabel(s, discipline);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final book = ref.watch(recipeBookProvider);
    final index = ref.watch(itemIndexProvider).valueOrNull ?? ItemIndex.empty;
    // recipe ids the account knows, empty without the unlocks permission
    final learned = ref.watch(learnedRecipesProvider).valueOrNull ?? const <int>{};

    return AsyncView<RecipeBook>(
      value: book,
      onRetry: () => ref.invalidate(recipeBookProvider),
      builder: (b) {
        if (b.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(s.t('no_recipe_data'), style: const TextStyle(color: AppColors.muted, height: 1.5)),
          );
        }

        final rows = <(int, String, List<BookRecipe>)>[];
        var total = 0;
        for (final entry in b.byOutput.entries) {
          // a search looks through every recipe, the tabs only filter the browse view
          if (_query.isEmpty && !_matchesFilter(entry.value)) continue;
          final name = index.nameOf(entry.key);
          if (name == null) continue;
          if (_query.isNotEmpty && !name.toLowerCase().contains(_query)) continue;
          total++;
          rows.add((entry.key, name, entry.value));
        }
        rows.sort((a, b) => a.$2.compareTo(b.$2));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _ctrl,
                onChanged: _onChanged,
                decoration: fieldDecoration(
                  s.t('search_recipes'),
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final d in [_legendary, ...b.disciplines]) ...[
                    ChoiceChip(
                      label: Text(_label(s, d)),
                      selected: _query.isEmpty && _filter == d,
                      onSelected: (_) => setState(() => _filter = d),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s.t('recipes_count', {'n': fmtInt(total)}),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final (id, name, recipes) = rows[i];
                  final from = i - i % _chunk;
                  final to = from + _chunk > rows.length ? rows.length : from + _chunk;
                  return _RecipeRow(
                    id: id,
                    name: name,
                    recipes: recipes,
                    // rows of the same chunk share one request for icons
                    chunkKey: [for (var j = from; j < to; j++) rows[j].$1].join(','),
                    label: (d) => _label(s, d),
                    learned: recipes.any((r) => r.id > 0 && learned.contains(r.id)),
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

class _RecipeRow extends ConsumerWidget {
  const _RecipeRow({
    required this.id,
    required this.name,
    required this.recipes,
    required this.chunkKey,
    required this.label,
    this.learned = false,
  });

  final int id;
  final String name;
  final List<BookRecipe> recipes;
  final String chunkKey;
  final String Function(String discipline) label;
  final bool learned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemBatchProvider(chunkKey)).valueOrNull?[id];
    final disciplines = {for (final r in recipes) ...r.disciplines};
    final legendary = recipes.any((r) => r.legendary);
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CraftingDetailScreen(itemId: id)),
      ),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: legendary ? rarityColor('Legendary') : AppColors.text,
                    )),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [for (final d in disciplines) Pill(label(d))],
                ),
              ],
            ),
          ),
          if (learned) ...[
            const Icon(Icons.check_circle, size: 18, color: AppColors.green),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.chevron_right, color: AppColors.chevron),
        ],
      ),
    );
  }
}
