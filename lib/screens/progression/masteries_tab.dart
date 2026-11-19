part of '../progression_screen.dart';

class _MasteriesTab extends ConsumerWidget {
  const _MasteriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rows = ref.watch(masteriesProvider);
    final points = ref.watch(masteryPointsProvider).valueOrNull ?? const <Json>[];

    // on a site the regions stand side by side, each track as a path of its levels
    if (SiteScope.of(context)) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          AsyncView<List<MasteryRow>>(
            permission: 'progression',
            value: rows,
            onRetry: () => ref.invalidate(masteriesProvider),
            builder: (list) {
              if (list.isEmpty) return Panel(child: EmptyNote(s.t('nothing_here'), center: false));
              return _MasteriesSite(rows: list, points: points);
            },
          ),
        ],
      );
    }

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
                              style: TextStyle(fontSize: 13, color: AppColors.gold, fontWeight: FontWeight.w800)),
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
                return Panel(child: EmptyNote(s.t('nothing_here'), center: false));
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
                    fontSize: 12, fontWeight: FontWeight.w800, color: complete ? AppColors.green : AppColors.muted)),
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
            Text(row.requirement, style: TextStyle(fontSize: 11, height: 1.4, color: AppColors.hint)),
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
                    fontSize: 13, fontWeight: FontWeight.w600, color: done ? AppColors.text : AppColors.muted)),
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

/// the mastery regions as columns, every track a row of numbered nodes, and below them the track to learn next
class _MasteriesSite extends ConsumerWidget {
  const _MasteriesSite({required this.rows, required this.points});

  final List<MasteryRow> rows;
  final List<Json> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final regions = _regionsOf(rows);
    final unspent = points.fold<int>(0, (n, p) => n + (asInt(p['earned']) - asInt(p['spent'])));
    MasteryRow? next;
    for (final m in rows) {
      if (m.started && m.level < m.total) {
        next = m;
        break;
      }
    }
    Widget node(int n, {required bool done, required bool isNext}) => Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.green : null,
            border: Border.all(color: done ? AppColors.green : (isNext ? AppColors.gold : AppColors.track), width: 2),
          ),
          child: Text('$n',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: done ? Colors.white : (isNext ? AppColors.gold : AppColors.muted))),
        );

    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth >= 1100 ? 4 : (box.maxWidth >= 800 ? 3 : (box.maxWidth >= 520 ? 2 : 1));
      final width = (box.maxWidth - (cols - 1) * 16) / cols;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              for (final region in regions)
                SizedBox(
                  width: width,
                  child: Panel(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(region, style: display(17, color: AppColors.gold))),
                            Text(
                              '${rows.where((m) => m.region == region).fold<int>(0, (n, m) => n + m.level)}'
                              ' / ${rows.where((m) => m.region == region).fold<int>(0, (n, m) => n + m.total)}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted),
                            ),
                          ],
                        ),
                        for (final m in rows.where((m) => m.region == region))
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: m.started ? AppColors.text : AppColors.muted)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    for (var i = 0; i < m.total; i++) ...[
                                      if (i > 0)
                                        Expanded(
                                          child: Container(
                                            height: 2,
                                            color: i <= m.level - 1 ? AppColors.green : AppColors.track,
                                          ),
                                        ),
                                      Tooltip(
                                        message: '${m.levels[i]['name'] ?? ''}',
                                        child: node(i + 1, done: i < m.level, isNext: i == m.level && m.started),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 18),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Kicker(s.t('mastery_next').caps),
                      const SizedBox(height: 2),
                      Text('${next.name}, ${s.t('mastery_rank_n', {'n': next.level + 1})}', style: display(22)),
                    ],
                  ),
                  const SizedBox(width: 30),
                  Expanded(
                    child: Text(
                      [
                        if (asInt(next.levels[next.level]['point_cost']) > 0)
                          s.t('mastery_cost_n', {'n': asInt(next.levels[next.level]['point_cost'])}),
                        s.t('mastery_unspent_n', {'n': unspent}),
                      ].join(' · '),
                      style: TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}
