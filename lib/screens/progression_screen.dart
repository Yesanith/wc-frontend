import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

class ProgressionScreen extends ConsumerWidget {
  const ProgressionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.gold,
            dividerColor: AppColors.track,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            tabs: [
              Tab(text: s.t('achievements')),
              Tab(text: s.t('masteries')),
              Tab(text: s.t('instances')),
              Tab(text: s.t('pvp_wvw')),
            ],
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
    final done = ref.watch(achievementsDoneProvider).valueOrNull;

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async {
        ref.invalidate(achievementsProvider);
        ref.invalidate(achievementsDoneProvider);
        try {
          await ref.read(achievementsProvider.future);
        } catch (_) {}
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (done != null)
            Panel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.t('completed'), style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
                  ),
                  Text(fmtInt(done),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SectionHeader(title: s.t('in_progress')),
          const SizedBox(height: 10),
          AsyncView<List<AchievementRow>>(
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
      onRefresh: () async {
        ref.invalidate(masteriesProvider);
        ref.invalidate(masteryPointsProvider);
        try {
          await ref.read(masteriesProvider.future);
        } catch (_) {}
      },
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
                            child: Text('${p['region'] ?? ''}',
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
          SectionHeader(title: s.t('mastery_tracks')),
          const SizedBox(height: 10),
          AsyncView<List<MasteryRow>>(
            value: rows,
            onRetry: () => ref.invalidate(masteriesProvider),
            builder: (list) {
              if (list.isEmpty) {
                return Panel(child: Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted)));
              }
              return Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    for (final m in list)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(m.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 10),
                                Text('${m.level} / ${m.total}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: m.level >= m.total ? AppColors.green : AppColors.muted)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(m.region, style: const TextStyle(fontSize: 11, color: AppColors.hint)),
                            const SizedBox(height: 7),
                            Bar(
                              value: m.total == 0 ? 0 : m.level / m.total,
                              color: m.level >= m.total ? AppColors.green : AppColors.gold,
                            ),
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


/// raid wings reset weekly, dungeon paths daily
class _InstancesTab extends ConsumerWidget {
  const _InstancesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final raids = ref.watch(raidsProvider);
    final dungeons = ref.watch(dungeonsProvider);

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () async {
        ref.invalidate(raidsProvider);
        ref.invalidate(dungeonsProvider);
        try {
          await ref.read(raidsProvider.future);
        } catch (_) {}
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          SectionHeader(title: s.t('raids'), trailing: s.t('weekly')),
          const SizedBox(height: 10),
          AsyncView<List<RaidWing>>(
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
          SectionHeader(title: s.t('dungeons'), trailing: s.t('daily')),
          const SizedBox(height: 10),
          AsyncView<List<Dungeon>>(
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
                                  color: professionColor(
                                      '${entry.key[0].toUpperCase()}${entry.key.substring(1)}'),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(entry.key,
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
