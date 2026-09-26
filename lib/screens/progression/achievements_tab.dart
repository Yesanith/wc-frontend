part of '../progression_screen.dart';

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
