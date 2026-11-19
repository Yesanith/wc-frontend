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

    // on a site every wing and every dungeon is a row of boxes, one box for each encounter or path
    if (SiteScope.of(context)) {
      Widget block(String title, String? tally, Widget body) => Panel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  color: AppColors.track.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(title.caps,
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.muted)),
                      ),
                      if (tally != null)
                        Text(tally,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.gold)),
                    ],
                  ),
                ),
                body,
              ],
            ),
          );
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          AsyncView<List<RaidWing>>(
            permission: 'progression',
            value: raids,
            onRetry: () => ref.invalidate(raidsProvider),
            builder: (list) => block(
              s.t('raids'),
              _tally(raids.valueOrNull?.tally, s.t('weekly')),
              Column(
                children: [
                  for (final wing in list)
                    _ClearRow(label: wing.label, boxes: [for (final e in wing.encounters) (e.label, e.done)]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          AsyncView<List<Dungeon>>(
            permission: 'progression',
            value: dungeons,
            onRetry: () => ref.invalidate(dungeonsProvider),
            builder: (list) => block(
              s.t('dungeons'),
              _tally(dungeons.valueOrNull?.tally, s.t('daily')),
              Column(
                children: [
                  for (final d in list)
                    _ClearRow(label: d.label, boxes: [for (final p in d.paths) (titleCase(p.id), p.done)]),
                ],
              ),
            ),
          ),
        ],
      );
    }

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

/// a wing or a dungeon with a box for each of its encounters or paths, filled once cleared
class _ClearRow extends StatelessWidget {
  const _ClearRow({required this.label, required this.boxes});

  final String label;
  final List<(String, bool)> boxes;

  @override
  Widget build(BuildContext context) {
    final done = boxes.where((b) => b.$2).length;
    final all = boxes.isNotEmpty && done == boxes.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final (name, ok) in boxes)
                  Tooltip(
                    message: name,
                    child: Container(
                      width: 30,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ok ? AppColors.green : null,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ok ? AppColors.green : AppColors.track, width: 1.5),
                      ),
                      child: ok ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: Text('$done / ${boxes.length}',
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: all ? AppColors.green : AppColors.muted)),
          ),
        ],
      ),
    );
  }
}
