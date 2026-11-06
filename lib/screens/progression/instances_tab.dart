part of '../progression_screen.dart';

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
                              child:
                                  Text(wing.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
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
                                  style: TextStyle(fontSize: 13, color: e.done ? AppColors.muted : AppColors.text)),
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
                            child: Text(d.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
