part of '../progression_screen.dart';

class _MasteriesTab extends ConsumerWidget {
  const _MasteriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rows = ref.watch(masteriesProvider);
    final points = ref.watch(masteryPointsProvider).valueOrNull ?? const <Json>[];

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [masteriesProvider, masteryPointsProvider]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (points.isNotEmpty) ...[
            SectionHeader(title: s.t('mastery_points')),
            const SizedBox(height: 10),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (final p in points)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(masteryRegionName('${p['region'] ?? ''}'),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          Text(s.t('points_spent', {'a': asInt(p['spent']), 'b': asInt(p['earned'])}),
                              style: const TextStyle(fontSize: 13, color: AppColors.gold, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
          SectionHeader(title: s.t('mastery_tracks'), trailing: _tally(rows.valueOrNull?.tally)),
          const SizedBox(height: 10),
          AsyncView<List<MasteryRow>>(
            permission: 'progression',
            value: rows,
            onRetry: () => ref.invalidate(masteriesProvider),
            builder: (list) {
              if (list.isEmpty) {
                return Panel(child: Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted)));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final region in _regionsOf(list)) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
                      child: Text(region, style: display(15, color: AppColors.gold)),
                    ),
                    Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(
                        children: [
                          for (final m in list.where((m) => m.region == region)) _MasteryTile(m),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// raid wings reset weekly, dungeon paths daily
/// regions in the order the tracks already came back in
List<String> _regionsOf(List<MasteryRow> rows) {
  final seen = <String>[];
  for (final r in rows) {
    if (!seen.contains(r.region)) seen.add(r.region);
  }
  return seen;
}

/// one track, opening to the individual levels and what each one costs
class _MasteryTile extends StatelessWidget {
  const _MasteryTile(this.row);

  final MasteryRow row;

  @override
  Widget build(BuildContext context) {
    final complete = row.total > 0 && row.level >= row.total;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        iconColor: AppColors.gold,
        collapsedIconColor: AppColors.muted,
        title: Row(
          children: [
            Expanded(
              child: Text(row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: row.started ? AppColors.text : AppColors.muted)),
            ),
            const SizedBox(width: 10),
            Text('${row.level} / ${row.total}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: complete ? AppColors.green : AppColors.muted)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Bar(
            value: row.total == 0 ? 0 : row.level / row.total,
            color: complete ? AppColors.green : AppColors.gold,
          ),
        ),
        children: [
          for (var i = 0; i < row.levels.length; i++) _MasteryLevelRow(row.levels[i], done: i < row.level),
          if (!row.started && row.requirement.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(row.requirement,
                style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.hint)),
          ],
        ],
      ),
    );
  }
}

class _MasteryLevelRow extends StatelessWidget {
  const _MasteryLevelRow(this.level, {required this.done});

  final Json level;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final points = asInt(level['point_cost']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16, color: done ? AppColors.green : AppColors.track),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${level['name'] ?? ''}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: done ? AppColors.text : AppColors.muted)),
          ),
          if (points > 0) ...[
            const SizedBox(width: 8),
            Pill('$points'),
          ],
        ],
      ),
    );
  }
}
