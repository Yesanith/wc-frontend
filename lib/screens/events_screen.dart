import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/metas.dart';
import '../data/waypoints.dart';
import '../services/boss_alerts.dart' show maxBossAlerts;
import '../state/boss_alerts.dart';
import '../state/clock.dart';
import '../util.dart';
import '../widgets/clock.dart';
import '../state/periodic.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/expansion_badge.dart';
import '../widgets/waypoint_link.dart';

part 'events/timeline.dart';
part 'events/sheet.dart';

String localClock(DateTime t) {
  final l = t.toLocal();
  return '${pad2(l.hour)}:${pad2(l.minute)}';
}

enum KindFilter { all, bosses, metas, pinned }

bool _matches(MetaMap map, MetaEvent e, KindFilter kind, Set<String> pins) => switch (kind) {
      KindFilter.all => true,
      KindFilter.bosses => e.kind != MetaKind.meta,
      KindFilter.metas => e.kind == MetaKind.meta,
      KindFilter.pinned => pins.contains(eventKey(map, e)),
    };

/// the looted list is for today only, a run after the reset is fresh again
bool lootedRun(Occurrence o, Set<String> looted, DateTime now) =>
    o.event.bossId != null && looted.contains(o.event.bossId) && o.start.isBefore(nextDailyReset(now));

/// the releases picked in the filter, remembered between visits
class ReleaseFilterNotifier extends Notifier<Set<Expansion>> {
  static const _key = 'timer_releases';

  @override
  Set<Expansion> build() {
    final saved = ref.watch(prefsProvider).getStringList(_key) ?? const <String>[];
    return {
      for (final e in Expansion.values)
        if (saved.contains(e.name)) e
    };
  }

  void toggle(Expansion e) {
    state = state.contains(e) ? ({...state}..remove(e)) : {...state, e};
    ref.read(prefsProvider).setStringList(_key, [for (final e in state) e.name]);
  }
}

final releaseFilterProvider = NotifierProvider<ReleaseFilterNotifier, Set<Expansion>>(ReleaseFilterNotifier.new);

/// the timeline or the list, remembered between visits
class TimerViewNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(prefsProvider).getBool('timer_list') ?? false;

  void toggle() {
    state = !state;
    ref.read(prefsProvider).setBool('timer_list', state);
  }
}

final timerListViewProvider = NotifierProvider<TimerViewNotifier, bool>(TimerViewNotifier.new);

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key, this.embedded = false});

  /// true when shown inside the drawer shell, which brings its own app bar
  final bool embedded;

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  KindFilter _kind = KindFilter.all;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final pins = ref.watch(pinnedEventsProvider);
    final releases = ref.watch(releaseFilterProvider);
    final listView = ref.watch(timerListViewProvider);
    final looted = ref.watch(doneTodayProvider('worldbosses')).valueOrNull ?? const <String>{};
    final maps = [
      for (final m in metaMaps)
        if ((releases.isEmpty || releases.contains(m.release)) && m.events.any((e) => _matches(m, e, _kind, pins))) m
    ];

    final body = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(s.t('timer_note'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ),
                IconButton(
                  tooltip: listView ? s.t('timeline_view') : s.t('list_view'),
                  onPressed: () => ref.read(timerListViewProvider.notifier).toggle(),
                  icon:
                      Icon(listView ? Icons.view_timeline_outlined : Icons.view_agenda_outlined, color: AppColors.gold),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ChipRow(
            children: [
              for (final k in KindFilter.values)
                ChoiceChip(
                  label: Text(switch (k) {
                    KindFilter.all => s.t('all'),
                    KindFilter.bosses => s.t('filter_bosses'),
                    KindFilter.metas => s.t('filter_metas'),
                    KindFilter.pinned => s.t('pinned'),
                  }),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
              Container(width: 1, height: 24, margin: const EdgeInsets.symmetric(horizontal: 6), color: AppColors.line),
              for (final e in Expansion.values)
                FilterChip(
                  avatar: CircleAvatar(radius: 4, backgroundColor: e.color),
                  label: Text(e.code),
                  tooltip: e.label,
                  selected: releases.contains(e),
                  onSelected: (_) => ref.read(releaseFilterProvider.notifier).toggle(e),
                ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (maps.isEmpty)
          SliverToBoxAdapter(child: EmptyNote(s.t('nothing_pinned')))
        else if (listView)
          _AgendaList(maps: maps, kind: _kind, pins: pins, looted: looted)
        else
          SliverToBoxAdapter(child: Timeline(maps: maps, kind: _kind, pins: pins, looted: looted)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );

    final refreshable = RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [doneTodayProvider('worldbosses')]),
      child: body,
    );
    if (widget.embedded) return refreshable;
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('world_bosses')),
      ),
      body: refreshable,
    );
  }
}

class _AgendaList extends ConsumerWidget {
  const _AgendaList({required this.maps, required this.kind, required this.pins, required this.looted});

  final List<MetaMap> maps;
  final KindFilter kind;
  final Set<String> pins;
  final Set<String> looted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // the list only changes once a minute, the rows tick on their own
    return ClockBuilder(
      step: ClockStep.minute,
      builder: (context, now) {
        final list = occurrences(now, now.add(const Duration(hours: 6)), maps: maps)
            .where((o) => _matches(o.map, o.event, kind, pins))
            .toList();
        return SliverList.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final o = list[i];
            final hourChanged = i == 0 || o.start.toLocal().hour != list[i - 1].start.toLocal().hour;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hourChanged)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 20, 4),
                    child: Text(
                      '${pad2(o.start.toLocal().hour)}:00',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppColors.hint),
                    ),
                  ),
                MetaRow(occurrence: o, looted: lootedRun(o, looted, now), pinnable: true),
              ],
            );
          },
        );
      },
    );
  }
}

/// one run of an event: when, what, where
class MetaRow extends ConsumerWidget {
  const MetaRow({super.key, required this.occurrence, required this.looted, this.pinnable = false});

  final Occurrence occurrence;
  final bool looted;
  final bool pinnable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final o = occurrence;
    final tint = o.map.release.color;
    final key = eventKey(o.map, o.event);
    // watched outside the clock, whose ticks rebuild only the clock
    final pinned = ref.watch(pinnedEventsProvider).contains(key);
    return ClockBuilder(
      step: ClockStep.second,
      builder: (context, now) {
        final active = o.activeAt(now);
        return InkWell(
          onTap: () => openWikiPage(context, ref, o.event.wiki ?? o.event.name),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 8, 9),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localClock(o.start),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: active ? AppColors.gold : AppColors.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        active
                            ? s.t('ends_in', {'t': countdown(o.end.difference(now))})
                            : s.t('starts_in', {'t': countdown(o.start.difference(now))}),
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 11, color: AppColors.muted, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                    width: 3,
                    height: 34,
                    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (o.event.kind == MetaKind.hardBoss) ...[
                            Icon(Icons.local_fire_department_rounded, size: 15, color: AppColors.red),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              o.event.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: looted ? AppColors.muted : AppColors.text,
                                decoration: looted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(o.map.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      // right under it, the waypoint to travel to, as the wiki's timer has it
                      if (waypointFor(o.map, o.event) case final waypoint?) WaypointLink(waypoint),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(999)),
                    child: Text(s.t('now'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.onGold)),
                  )
                else if (looted)
                  Icon(Icons.check_rounded, size: 18, color: AppColors.green)
                else
                  ExpansionBadge(o.map.release, size: 30),
                if (pinnable)
                  IconButton(
                    tooltip: pinned ? s.t('unpin') : s.t('pin'),
                    onPressed: () => togglePin(context, ref, key),
                    icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 20, color: pinned ? AppColors.gold : AppColors.chevron),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
