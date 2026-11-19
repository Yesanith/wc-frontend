import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/clock.dart';
import '../state/account.dart';
import '../state/periodic.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../state/vault.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/stale_note.dart';
import '../widgets/vault_objectives.dart' show VaultChestReward;
import 'daily_screen.dart';
import 'vault_objectives_screen.dart' show VaultHeaderActions;

/// one line of the day's list: what is to be done, which part of the page it belongs to and how far it is
class _Task {
  const _Task({required this.group, required this.name, required this.done, this.current = 0, this.max = 0, this.icon});

  final String group;
  final String name;
  final bool done;
  final int current;
  final int max;
  final String? icon;
}

/// the daily or the weekly page of a site: what the day or the week asks for in one list under tabs, the vault and the counters in a column
/// beside it
class PeriodSite extends ConsumerStatefulWidget {
  const PeriodSite({super.key, required this.counters, this.weekly = false});

  final bool weekly;

  /// the small counters of the day: label and value
  final List<(String, String)> counters;

  @override
  ConsumerState<PeriodSite> createState() => _PeriodSiteState();
}

class _PeriodSiteState extends ConsumerState<PeriodSite> {
  String? _group;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final track = widget.weekly ? 'weekly' : 'daily';
    final stale = ref.watch(vaultStaleProvider(track));
    final daily = ref.watch(vaultTrackProvider(track)).valueOrNull;
    final periodic = ref.watch(periodicAchievementsProvider).valueOrNull;
    final categories = widget.weekly ? periodic?.weekly : periodic?.daily;
    final vaultName = s.t(widget.weekly ? 'vault_weekly' : 'wizards_vault');
    final special = widget.weekly ? ref.watch(vaultTrackProvider('special')).valueOrNull : null;
    final raids = widget.weekly ? ref.watch(raidsProvider).valueOrNull : null;

    List<_Task> objectives(Json? v, String group) => [
          for (final o in (v?['objectives'] as List?) ?? const [])
            if (o is Map)
              _Task(
                group: group,
                name: '${o['title']}',
                done:
                    asInt(o['progress_complete']) > 0 && asInt(o['progress_current']) >= asInt(o['progress_complete']),
                current: asInt(o['progress_current']),
                max: asInt(o['progress_complete']),
              ),
        ];

    final tasks = <_Task>[
      if (!stale && daily != null) ...objectives(daily, vaultName),
      ...objectives(special, s.t('vault_special')),
      if (categories != null)
        for (final c in categories)
          for (final r in c.rows)
            _Task(
              group: c.name,
              name: r.name,
              done: r.done,
              current: r.current,
              max: r.max,
              icon: (r.detail?['icon'] as String?) ?? c.icon,
            ),
      if (raids != null)
        for (final w in raids)
          _Task(
            group: s.t('raids'),
            name: w.label,
            done: w.encounters.isNotEmpty && w.done >= w.encounters.length,
            current: w.done,
            max: w.encounters.length,
          ),
    ];
    final groups = <String>[];
    for (final t in tasks) {
      if (!groups.contains(t.group)) groups.add(t.group);
    }
    final shown = _group != null && groups.contains(_group) ? _group : null;
    final list = [
      for (final t in tasks)
        if (shown == null || t.group == shown) t
    ]..sort((a, b) => (a.done ? 1 : 0).compareTo(b.done ? 1 : 0));
    int doneIn(String g) => tasks.where((t) => t.group == g && t.done).length;
    int countIn(String g) => tasks.where((t) => t.group == g).length;

    return LayoutBuilder(
      builder: (context, box) {
        final column = _SideColumn(counters: widget.counters, weekly: widget.weekly);
        final main = Panel(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // one row that goes sideways: the day has more groups than a row holds
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final g in <String?>[null, ...groups])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(g == null
                              ? '${s.t('all')}  ${tasks.where((t) => t.done).length}/${tasks.length}'
                              : '$g  ${doneIn(g)}/${countIn(g)}'),
                          selected: shown == g,
                          onSelected: (_) => setState(() => _group = g),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (stale) const VaultAwaitingLogin(track: 'daily'),
              if (periodic == null && tasks.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              for (final t in list) _TaskRow(task: t, showGroup: shown == null),
            ],
          ),
        );
        if (box.maxWidth < 900) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [column, const SizedBox(height: 16), main]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 380, child: column),
            const SizedBox(width: 22),
            Expanded(child: main),
          ],
        );
      },
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.showGroup});

  final _Task task;
  final bool showGroup;

  @override
  Widget build(BuildContext context) {
    final t = task;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.track))),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: t.done ? AppColors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.done ? AppColors.green : AppColors.hint, width: 1.5),
            ),
            child: t.done ? Icon(Icons.check, size: 14, color: AppColors.bg) : null,
          ),
          const SizedBox(width: 14),
          if (showGroup)
            SizedBox(
              width: 120,
              child: Text(t.group.caps,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: AppColors.gold)),
            ),
          if (showGroup) const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.name,
              style: TextStyle(
                fontSize: 14.5,
                color: t.done ? AppColors.muted : AppColors.text,
                decoration: t.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (t.max > 1 && !t.done) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (t.current / t.max).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppColors.track,
                  color: AppColors.gold,
                ),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text('${t.current}/${t.max}',
                  textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ),
          ],
        ],
      ),
    );
  }
}

/// the vault with the chest that is being filled, its other two tracks, and the day's counters
class _SideColumn extends ConsumerWidget {
  const _SideColumn({required this.counters, required this.weekly});

  final bool weekly;

  final List<(String, String)> counters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    (int?, int) track(String id) {
      final v = ref.watch(vaultTrackProvider(id)).valueOrNull;
      final stale = ref.watch(vaultStaleProvider(id));
      final goal = v == null ? 0 : asInt(v['meta_progress_complete']);
      final now = v == null ? 0 : asInt(v['meta_progress_current']);
      return (stale || goal <= 0 ? null : (now > goal ? goal : now), goal);
    }

    // the track the page is about is the big number, the other one a line under it
    final (dailyNow, dailyGoal) = track(weekly ? 'weekly' : 'daily');
    final (otherNow, otherGoal) = track(weekly ? 'daily' : 'weekly');
    final special = ref.watch(vaultTrackProvider('special')).valueOrNull;
    final objectives = [
      for (final o in (special?['objectives'] as List?) ?? const [])
        if (o is Map) o
    ];
    final specialDone = objectives
        .where(
            (o) => asInt(o['progress_complete']) > 0 && asInt(o['progress_current']) >= asInt(o['progress_complete']))
        .length;
    final daily = ref.watch(vaultTrackProvider(weekly ? 'weekly' : 'daily')).valueOrNull;
    final season = ref.watch(vaultSeasonProvider).valueOrNull;
    final end = DateTime.tryParse('${season?['end'] ?? ''}')?.toLocal();

    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppColors.muted))),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResetBanner(
          label: s.t(weekly ? 'weekly_reset_in' : 'daily_reset_in'),
          at: weekly ? nextWeeklyReset() : nextDailyReset(),
        ),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(s.t('wizards_vault').caps,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: AppColors.gold)),
                ),
                const VaultHeaderActions(),
              ]),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(dailyNow == null ? '–' : '$dailyNow', style: display(52).copyWith(height: 1)),
                  const SizedBox(width: 8),
                  Text(dailyGoal > 0 ? '/ $dailyGoal ${s.t('vault_to_chest')}' : '',
                      style: display(20).copyWith(color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: dailyNow == null || dailyGoal == 0 ? 0 : dailyNow / dailyGoal,
                  minHeight: 9,
                  backgroundColor: AppColors.track,
                  color: dailyNow != null && dailyNow >= dailyGoal && dailyGoal > 0 ? AppColors.green : AppColors.gold,
                ),
              ),
              line(s.t(weekly ? 'vault_daily' : 'vault_weekly'), otherNow == null ? '–' : '$otherNow / $otherGoal'),
              line(s.t('vault_special'), objectives.isEmpty ? '–' : '$specialDone / ${objectives.length}'),
              if (daily != null) ...[const SizedBox(height: 12), VaultChestReward(daily)],
              if (end != null) ...[
                const SizedBox(height: 10),
                Text(s.t('season_ends', {'d': shortDateText(s, end)}),
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Wrap(
            runSpacing: 14,
            children: [
              for (final c in counters)
                SizedBox(
                  width: 160,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.$1.caps,
                        style: TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(c.$2, style: display(24)),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
