import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// the whole achievement catalogue, group by group. the account's own
/// progress is only fetched once a category is opened, since the catalogue
/// runs to several thousand entries
class AchievementGroupsScreen extends ConsumerWidget {
  const AchievementGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final groups = ref.watch(achievementCatalogueProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('achievements'), style: display(20)),
      ),
      body: AsyncView<List<AchievementGroup>>(
        value: groups,
        onRetry: () => ref.invalidate(achievementCatalogueProvider),
        builder: (list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final g = list[i];
            return AppCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => _CategoriesScreen(group: g)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '${fmtInt(g.categories.length)} · ${fmtInt(g.achievementCount)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoriesScreen extends ConsumerWidget {
  const _CategoriesScreen({required this.group});

  final AchievementGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(group.name, style: display(20)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: group.categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final c = group.categories[i];
          return ItemRow(
            icon: c.icon,
            title: c.name,
            subtitle: fmtInt(c.achievementIds.length),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => AchievementCategoryScreen(category: c)),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
          );
        },
      ),
    );
  }
}

class AchievementCategoryScreen extends ConsumerWidget {
  const AchievementCategoryScreen({super.key, required this.category});

  final AchievementCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rows = ref.watch(categoryAchievementsProvider(category.id));
    final done = rows.valueOrNull?.where((a) => a.done).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(category.name, style: display(20)),
        actions: [
          if (done != null)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: Text('$done / ${category.achievementIds.length}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold)),
              ),
            ),
        ],
      ),
      body: AsyncView<List<AchievementRow>>(
        value: rows,
        onRetry: () => ref.invalidate(categoryAchievementsProvider(category.id)),
        builder: (list) {
          if (list.isEmpty) {
            return Center(child: Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted)));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _AchievementCard(list[i]),
          );
        },
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard(this.row);

  final AchievementRow row;

  @override
  Widget build(BuildContext context) {
    final description = '${row.detail?['requirement'] ?? row.detail?['description'] ?? ''}'
        .replaceAll(RegExp(r'<[^>]*>'), '');
    final points = row.points;

    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(row.done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18, color: row.done ? AppColors.green : AppColors.track),
              const SizedBox(width: 10),
              Expanded(
                child: Text(row.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: row.done ? AppColors.text : AppColors.textSoft)),
              ),
              if (points > 0) ...[
                const SizedBox(width: 8),
                Pill('$points'),
              ],
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(description,
                style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
          ],
          if (!row.done && row.max > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Bar(value: row.ratio)),
                const SizedBox(width: 10),
                Text('${fmtInt(row.current)} / ${fmtInt(row.max)}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
