part of '../progression_screen.dart';

class _AchievementsTab extends ConsumerWidget {
  const _AchievementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rows = ref.watch(achievementsProvider);
    final summary = ref.watch(achievementSummaryProvider).valueOrNull;
    final total = ref.watch(achievementTotalProvider).valueOrNull;

    // on a site the achievements being worked on stand in a list with the chosen one open beside it
    if (SiteScope.of(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (summary != null) ...[
                  Expanded(
                    flex: 3,
                    child: Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      child: Row(
                        children: [
                          StatTile(
                            label: s.t('completed'),
                            value: total == null ? fmtInt(summary.done) : '${fmtInt(summary.done)} / ${fmtInt(total)}',
                          ),
                          const SizedBox(width: 30),
                          StatTile(label: s.t('in_progress'), value: fmtInt(summary.inProgress)),
                          if (total != null && total > 0) ...[
                            const SizedBox(width: 30),
                            Expanded(child: Bar(value: summary.done / total)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: AppCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const AchievementGroupsScreen()),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.list_alt_outlined, size: 20, color: AppColors.gold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s.t('browse_all'),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: AsyncView<List<AchievementRow>>(
                permission: 'progression',
                value: rows,
                onRetry: () => ref.invalidate(achievementsProvider),
                builder: (list) {
                  if (list.isEmpty) return Panel(child: EmptyNote(s.t('nothing_here'), center: false));
                  return _AchievementsSite(rows: list);
                },
              ),
            ),
          ],
        ),
      );
    }

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
                          value: total == null ? fmtInt(summary.done) : '${fmtInt(summary.done)} / ${fmtInt(total)}',
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
                Icon(Icons.list_alt_outlined, size: 20, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(s.t('browse_all'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                Icon(Icons.chevron_right, color: AppColors.muted),
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
                return Panel(child: EmptyNote(s.t('nothing_here'), center: false));
              }
              return Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TwoColumnRows(
                  children: [
                    for (final a in list.take(60))
                      InkWell(
                        onTap: () => openPanel(context, (_) => AchievementDetailScreen(row: a)),
                        child: Padding(
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
                                      style:
                                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
                                  AchievementPinButton(id: a.id),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Bar(value: a.ratio),
                            ],
                          ),
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

/// the achievements in progress as a list, and the chosen one in full beside it
class _AchievementsSite extends ConsumerStatefulWidget {
  const _AchievementsSite({required this.rows});

  final List<AchievementRow> rows;

  @override
  ConsumerState<_AchievementsSite> createState() => _AchievementsSiteState();
}

class _AchievementsSiteState extends ConsumerState<_AchievementsSite> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final list = widget.rows;
    final index = _selected < list.length ? _selected : 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.centerLeft,
                  color: AppColors.track.withValues(alpha: 0.5),
                  child: Text('${s.t('in_progress')} · ${fmtInt(list.length)}'.caps,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.muted)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final a = list[i];
                      return InkWell(
                        onTap: () => setState(() => _selected = i),
                        child: Container(
                          color: i == index ? AppColors.gold.withValues(alpha: 0.12) : null,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                                      style:
                                          TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Bar(value: a.ratio),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 400,
          child: Panel(
            padding: EdgeInsets.zero,
            child: AchievementDetailScreen(key: ValueKey(list[index].id), row: list[index], embedded: true),
          ),
        ),
      ],
    );
  }
}
