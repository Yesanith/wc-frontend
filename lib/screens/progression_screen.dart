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
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.gold,
            dividerColor: AppColors.track,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            tabs: [
              Tab(text: s.t('achievements')),
              Tab(text: s.t('masteries')),
            ],
          ),
          const Expanded(
            child: TabBarView(children: [_AchievementsTab(), _MasteriesTab()]),
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
