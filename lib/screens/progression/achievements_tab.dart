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

/// three panes: the categories of the game, the achievements of the chosen one, and the chosen achievement in full
class _AchievementsSite extends ConsumerStatefulWidget {
  const _AchievementsSite({required this.rows});

  /// the ones in progress, shown while no category is chosen
  final List<AchievementRow> rows;

  @override
  ConsumerState<_AchievementsSite> createState() => _AchievementsSiteState();
}

class _AchievementsSiteState extends ConsumerState<_AchievementsSite> {
  /// null for the achievements in progress
  AchievementCategory? _category;
  int? _selectedId;

  Widget _paneHeader(String text, {Widget? trailing}) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        color: AppColors.track.withValues(alpha: 0.5),
        child: Row(
          children: [
            Expanded(
              child: Text(text.caps,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.muted)),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );

  Widget _categoryRow(String label, String? note, {required bool on, required VoidCallback onTap, bool sub = false}) =>
      InkWell(
        onTap: onTap,
        child: Container(
          color: on ? AppColors.gold.withValues(alpha: 0.14) : null,
          padding: EdgeInsets.fromLTRB(sub ? 28 : 18, 9, 14, 9),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
              ),
              if (note != null) Text(note, style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ],
          ),
        ),
      );

  Widget _achievementRow(AchievementRow a, {required bool on}) => InkWell(
        onTap: () => setState(() => _selectedId = a.id),
        child: Container(
          color: on ? AppColors.gold.withValues(alpha: 0.12) : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (a.done) ...[
                    Icon(Icons.check_circle, size: 16, color: AppColors.green),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: a.done ? AppColors.muted : AppColors.text)),
                  ),
                  const SizedBox(width: 10),
                  Text(a.done ? '' : '${fmtInt(a.current)} / ${fmtInt(a.max)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
                ],
              ),
              if (!a.done) ...[const SizedBox(height: 7), Bar(value: a.ratio)],
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final groups = ref.watch(achievementCatalogueProvider).valueOrNull ?? const <AchievementGroup>[];
    final category = _category;

    Widget centre(List<AchievementRow> list) {
      if (list.isEmpty) return EmptyNote(s.t('nothing_here'));
      // the chosen one, or the first while none is chosen
      final chosen = list.firstWhere((a) => a.id == _selectedId, orElse: () => list.first);
      // the ones still to do go first, the closest to done on top
      final sorted = [...list]..sort((a, b) {
          if (a.done != b.done) return a.done ? 1 : -1;
          return b.ratio.compareTo(a.ratio);
        });
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Panel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _paneHeader(
                    category == null ? '${s.t('in_progress')} · ${fmtInt(list.length)}' : category.name,
                    trailing: category == null
                        ? null
                        : Text('${list.where((a) => a.done).length} / ${list.length}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.gold)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: sorted.length,
                      itemBuilder: (context, i) => _achievementRow(sorted[i], on: sorted[i].id == chosen.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 380,
            child: Panel(
              padding: EdgeInsets.zero,
              child: AchievementDetailScreen(key: ValueKey(chosen.id), row: chosen, embedded: true),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 270,
          child: Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _paneHeader(s.t('categories')),
                Expanded(
                  child: ListView(
                    children: [
                      _categoryRow(s.t('in_progress'), fmtInt(widget.rows.length),
                          on: category == null,
                          onTap: () => setState(() {
                                _category = null;
                                _selectedId = null;
                              })),
                      for (final g in groups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 14, 4),
                          child: Text(g.name.caps,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppColors.gold)),
                        ),
                        for (final c in g.categories)
                          _categoryRow(c.name, fmtInt(c.achievementIds.length),
                              sub: true,
                              on: category?.id == c.id,
                              onTap: () => setState(() {
                                    _category = c;
                                    _selectedId = null;
                                  })),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: category == null
              ? centre(widget.rows)
              : AsyncView<List<AchievementRow>>(
                  value: ref.watch(categoryAchievementsProvider(category.id)),
                  onRetry: () => ref.invalidate(categoryAchievementsProvider(category.id)),
                  builder: centre,
                ),
        ),
      ],
    );
  }
}
