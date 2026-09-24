import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/item_index.dart';
import '../services/recipe_book.dart';
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

/// filter chips: everything, legendaries, then one per discipline
const _all = '';
const _legendary = 'legendary';

/// how many rows the list shows before asking for a narrower search
const _limit = 150;

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _filter = _all;

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
      case _all:
        return true;
      case _legendary:
        return recipes.any((r) => r.legendary);
      default:
        return recipes.any((r) => r.disciplines.contains(_filter));
    }
  }

  String _label(S s, String discipline) {
    if (discipline == _all) return s.t('all');
    if (discipline == _legendary) return s.t('legendaries');
    if (discipline == mysticForge) return s.t('mystic_forge');
    return discipline;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final book = ref.watch(recipeBookProvider);
    final index = ref.watch(itemIndexProvider).valueOrNull ?? ItemIndex.empty;

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
          if (!_matchesFilter(entry.value)) continue;
          final name = index.nameOf(entry.key) ?? '#${entry.key}';
          if (_query.isNotEmpty && !name.toLowerCase().contains(_query)) continue;
          total++;
          rows.add((entry.key, name, entry.value));
        }
        rows.sort((a, b) => a.$2.compareTo(b.$2));
        final shown = rows.length > _limit ? rows.sublist(0, _limit) : rows;
        // icons and rarity of the visible rows in one request, cached on disk
        final details = ref.watch(itemBatchProvider(shown.map((r) => r.$1).join(','))).valueOrNull ??
            const <int, Json>{};

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
                  for (final d in [_all, _legendary, ...b.disciplines]) ...[
                    ChoiceChip(
                      label: Text(_label(s, d)),
                      selected: _filter == d,
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
                  total > _limit
                      ? s.t('recipes_more', {'n': fmtInt(total), 'shown': _limit})
                      : s.t('recipes_count', {'n': fmtInt(total)}),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: shown.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final (id, name, recipes) = shown[i];
                  final disciplines = {for (final r in recipes) ...r.disciplines};
                  final legendary = recipes.any((r) => r.legendary);
                  final item = details[id];
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
                                children: [for (final d in disciplines) Pill(_label(s, d))],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.chevron),
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
