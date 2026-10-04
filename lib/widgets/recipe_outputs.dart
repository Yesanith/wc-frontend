import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../screens/crafting_screen.dart';
import '../services/item_index.dart';
import '../services/recipe_book.dart';
import '../state/crafting.dart';
import '../state/items.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import 'common.dart';

/// icons are fetched for this many rows at a time, as they scroll in
const _chunk = 50;

String _disciplineName(S s, String d) => d == mysticForge ? s.t('mystic_forge') : disciplineLabel(s, d);

/// the ids of the rows around [i], so neighbouring rows share one request
String chunkKeyFor(List<UsedIn> rows, int i) {
  final from = i - i % _chunk;
  final to = from + _chunk > rows.length ? rows.length : from + _chunk;
  return [for (var j = from; j < to; j++) rows[j].output].join(',');
}

/// one recipe shown by what it makes. opens the crafting calculator
class RecipeOutputRow extends ConsumerWidget {
  const RecipeOutputRow({super.key, required this.entry, required this.chunkKey});

  final UsedIn entry;
  final String chunkKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final item = ref.watch(itemBatchProvider(chunkKey)).valueOrNull?[entry.output];
    final index = ref.watch(itemIndexProvider).valueOrNull;
    final name = (item?['name'] as String?) ?? index?.nameOf(entry.output) ?? s.t('item_n', {'id': entry.output});
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => CraftingDetailScreen(itemId: entry.output)),
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
                      color: item?['rarity'] == 'Legendary' ? rarityColor('Legendary') : AppColors.text,
                    )),
                if (entry.disciplines.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [for (final d in entry.disciplines) Pill(_disciplineName(s, d))],
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.chevron),
        ],
      ),
    );
  }
}

/// a searchable list of recipes, filtered by discipline
class RecipeOutputsScreen extends ConsumerStatefulWidget {
  const RecipeOutputsScreen({super.key, required this.title, required this.entries});

  final String title;
  final List<UsedIn> entries;

  @override
  ConsumerState<RecipeOutputsScreen> createState() => _RecipeOutputsScreenState();
}

class _RecipeOutputsScreenState extends ConsumerState<RecipeOutputsScreen> {
  String _query = '';
  String? _discipline;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final index = ref.watch(itemIndexProvider).valueOrNull;
    String nameOf(UsedIn e) => index?.nameOf(e.output) ?? '';

    final disciplines = {for (final e in widget.entries) ...e.disciplines}.toList()..sort();
    final rows = widget.entries.where((e) {
      if (_discipline != null && !e.disciplines.contains(_discipline)) return false;
      if (_query.isNotEmpty && !nameOf(e).toLowerCase().contains(_query)) return false;
      return true;
    }).toList()
      ..sort((a, b) => nameOf(a).compareTo(nameOf(b)));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.title, style: display(20)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration:
                  fieldDecoration(s.t('search_recipes'), prefixIcon: Icon(Icons.search, color: AppColors.muted)),
            ),
          ),
          if (disciplines.length > 1)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ChoiceChip(
                    label: Text(s.t('all')),
                    selected: _discipline == null,
                    onSelected: (_) => setState(() => _discipline = null),
                  ),
                  const SizedBox(width: 8),
                  for (final d in disciplines) ...[
                    ChoiceChip(
                      label: Text(_disciplineName(s, d)),
                      selected: _discipline == d,
                      onSelected: (_) => setState(() => _discipline = d),
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
              child: Text(s.t('recipes_count', {'n': fmtInt(rows.length)}),
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? EmptyNote(s.t('no_results'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => RecipeOutputRow(entry: rows[i], chunkKey: chunkKeyFor(rows, i)),
                  ),
          ),
        ],
      ),
    );
  }
}
