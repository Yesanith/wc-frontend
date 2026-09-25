import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'achievements_screen.dart';

class ProgressionScreen extends ConsumerWidget {
  const ProgressionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          AppTabBar(
            scrollable: true,
            labels: [s.t('achievements'), s.t('masteries'), s.t('instances'), s.t('pvp_wvw')],
          ),
          const Expanded(
            child: TabBarView(
              children: [_AchievementsTab(), _MasteriesTab(), _InstancesTab(), _PvpTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementsTab extends ConsumerWidget {
  const _AchievementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rows = ref.watch(achievementsProvider);
    final summary = ref.watch(achievementSummaryProvider).valueOrNull;
    final total = ref.watch(achievementTotalProvider).valueOrNull;

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [achievementsProvider, achievementSummaryProvider]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (summary != null)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: s.t('completed'),
                          value: total == null
                              ? fmtInt(summary.done)
                              : '${fmtInt(summary.done)} / ${fmtInt(total)}',
                        ),
                      ),
                      Expanded(
                        child: StatTile(label: s.t('in_progress'), value: fmtInt(summary.inProgress)),
                      ),
                    ],
                  ),
                  if (total != null && total > 0) ...[
                    const SizedBox(height: 12),
                    Bar(value: summary.done / total),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          AppCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AchievementGroupsScreen()),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt_outlined, size: 20, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.t('browse_all'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionHeader(title: s.t('in_progress'), trailing: fmtInt(summary?.inProgress ?? 0)),
          const SizedBox(height: 10),
          AsyncView<List<AchievementRow>>(
            permission: 'progression',
            value: rows,
            onRetry: () => ref.invalidate(achievementsProvider),
            builder: (list) {
              if (list.isEmpty) {
                return Panel(child: Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted)));
              }
              return Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    for (final a in list.take(60))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(a.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 10),
                                Text('${fmtInt(a.current)} / ${fmtInt(a.max)}',
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Bar(value: a.ratio),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

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

/// "6 / 27 · weekly", dropping to just the period until the numbers arrive
String? _tally(({int done, int total})? counts, [String? period]) {
  if (counts == null || counts.total == 0) return period;
  final ratio = '${fmtInt(counts.done)} / ${fmtInt(counts.total)}';
  return period == null ? ratio : '$ratio · $period';
}

class _InstancesTab extends ConsumerWidget {
  const _InstancesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final raids = ref.watch(raidsProvider);
    final dungeons = ref.watch(dungeonsProvider);

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [raidsProvider, dungeonsProvider]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          SectionHeader(title: s.t('raids'), trailing: _tally(raids.valueOrNull?.tally, s.t('weekly'))),
          const SizedBox(height: 10),
          AsyncView<List<RaidWing>>(
            permission: 'progression',
            value: raids,
            onRetry: () => ref.invalidate(raidsProvider),
            builder: (list) => Panel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                children: [
                  for (final wing in list)
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                        iconColor: AppColors.gold,
                        collapsedIconColor: AppColors.muted,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(wing.label,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                            ),
                            Text('${wing.done} / ${wing.encounters.length}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: wing.done == wing.encounters.length && wing.encounters.isNotEmpty
                                        ? AppColors.green
                                        : AppColors.muted)),
                          ],
                        ),
                        children: [
                          for (final e in wing.encounters)
                            ListTile(
                              dense: true,
                              leading: Icon(
                                e.done ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 20,
                                color: e.done ? AppColors.green : AppColors.hint,
                              ),
                              title: Text(e.label,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: e.done ? AppColors.muted : AppColors.text)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: s.t('dungeons'), trailing: _tally(dungeons.valueOrNull?.tally, s.t('daily'))),
          const SizedBox(height: 10),
          AsyncView<List<Dungeon>>(
            permission: 'progression',
            value: dungeons,
            onRetry: () => ref.invalidate(dungeonsProvider),
            builder: (list) => Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (final d in list)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(d.label,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          Text('${d.done} / ${d.paths.length}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: d.done == d.paths.length && d.paths.isNotEmpty
                                      ? AppColors.green
                                      : AppColors.muted)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PvpTab extends ConsumerWidget {
  const _PvpTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final stats = ref.watch(pvpStatsProvider);
    final account = ref.watch(accountProvider).valueOrNull;
    final wvw = account?['wvw'];
    final wvwRank = wvw is Map ? asInt(wvw['rank']) : asInt(account?['wvw_rank']);

    String ratio(Json? agg) {
      final wins = asInt(agg?['wins']);
      final losses = asInt(agg?['losses']);
      final total = wins + losses;
      if (total == 0) return '-';
      return '${(wins / total * 100).round()}%';
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        AsyncView<Json>(
          permission: 'pvp',
          value: stats,
          onRetry: () => ref.invalidate(pvpStatsProvider),
          builder: (data) {
            final aggregate = data['aggregate'] is Map
                ? Map<String, dynamic>.from(data['aggregate'] as Map)
                : <String, dynamic>{};
            final professions = data['professions'] is Map
                ? Map<String, dynamic>.from(data['professions'] as Map)
                : <String, dynamic>{};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: StatTile(label: s.t('pvp_rank'), value: '${asInt(data['pvp_rank'])}')),
                          Expanded(child: StatTile(label: s.t('win_rate'), value: ratio(aggregate))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: StatTile(label: s.t('wins'), value: fmtInt(asInt(aggregate['wins'])))),
                          Expanded(
                            child: StatTile(label: s.t('losses'), value: fmtInt(asInt(aggregate['losses']))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SectionHeader(title: s.t('per_profession')),
                const SizedBox(height: 10),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      for (final entry in professions.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: professionColor(titleCase(entry.key)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(titleCase(entry.key),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              ),
                              Text(
                                ratio(entry.value is Map
                                    ? Map<String, dynamic>.from(entry.value as Map)
                                    : null),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        SectionHeader(title: s.t('wvw')),
        const SizedBox(height: 10),
        Panel(
          child: Row(
            children: [
              Expanded(
                child: Text(s.t('wvw_rank'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
              ),
              Text(wvwRank > 0 ? fmtInt(wvwRank) : '-',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
            ],
          ),
        ),
      ],
    );
  }
}
