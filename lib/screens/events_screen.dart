import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/metas.dart';
import '../state/clock.dart';
import '../widgets/clock.dart';
import '../state/periodic.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/expansion_badge.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String localClock(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
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
                  child: Text(s.t('timer_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final k in KindFilter.values) ...[
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
                  const SizedBox(width: 6),
                ],
                Container(
                    width: 1, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10), color: AppColors.line),
                for (final e in Expansion.values) ...[
                  FilterChip(
                    avatar: CircleAvatar(radius: 4, backgroundColor: e.color),
                    label: Text(e.code),
                    tooltip: e.label,
                    selected: releases.contains(e),
                    onSelected: (_) => ref.read(releaseFilterProvider.notifier).toggle(e),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
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
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('world_bosses'), style: display(20)),
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
                      '${_two(o.start.toLocal().hour)}:00',
                      style: const TextStyle(
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
          onTap: () => openWikiPage(context, ref, o.event.name),
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
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted, fontFeatures: [FontFeature.tabularFigures()]),
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
                            const Icon(Icons.local_fire_department_rounded, size: 15, color: AppColors.red),
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
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(999)),
                    child: Text(s.t('now'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.onGold)),
                  )
                else if (looted)
                  const Icon(Icons.check_rounded, size: 18, color: AppColors.green)
                else
                  ExpansionBadge(o.map.release, size: 30),
                if (pinnable)
                  IconButton(
                    tooltip: pinned ? s.t('unpin') : s.t('pin'),
                    onPressed: () => ref.read(pinnedEventsProvider.notifier).toggle(key),
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

/// every map as a lane, events as blocks, and a line for now. scrolls
/// sideways through the next hours; map names stay pinned at the left edge
class Timeline extends ConsumerStatefulWidget {
  const Timeline({super.key, required this.maps, required this.kind, required this.pins, required this.looted});

  final List<MetaMap> maps;
  final KindFilter kind;
  final Set<String> pins;
  final Set<String> looted;

  static const pxPerMinute = 6.0;
  static const before = Duration(minutes: 30);
  static const span = Duration(hours: 6);
  static const lane = 58.0;
  static const gutter = 20.0;

  @override
  ConsumerState<Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<Timeline> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    // the lanes only change once a minute. the now line ticks every second
    // on its own, so the forty odd lanes are not rebuilt with it
    return ClockBuilder(
      step: ClockStep.minute,
      builder: (context, now) {
        // the window moves in five minute steps
        final origin = now.subtract(Timeline.before);
        final start =
            DateTime.utc(origin.year, origin.month, origin.day, origin.hour, origin.minute - origin.minute % 5);
        final end = start.add(Timeline.span);
        double x(DateTime t) => t.difference(start).inSeconds / 60 * Timeline.pxPerMinute;
        final width = x(end);
        final all = occurrences(start, end, maps: widget.maps)
            .where((o) => _matches(o.map, o.event, widget.kind, widget.pins))
            .toList();
        const g = Timeline.gutter;

        return SizedBox(
          height: 28 + widget.maps.length * Timeline.lane,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width + g * 2,
              child: Stack(
                children: [
                  // hour and half hour ticks
                  for (var t = DateTime.utc(start.year, start.month, start.day, start.hour);
                      t.isBefore(end);
                      t = t.add(const Duration(minutes: 30)))
                    if (!t.isBefore(start))
                      Positioned(
                        left: g + x(t),
                        top: 0,
                        bottom: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localClock(t),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: t.minute == 0 ? AppColors.muted : AppColors.hint,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Container(
                                width: 1,
                                color: AppColors.line.withValues(alpha: t.minute == 0 ? 0.9 : 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                  for (var i = 0; i < widget.maps.length; i++)
                    Positioned(
                      top: 28 + i * Timeline.lane,
                      left: 0,
                      width: width + g * 2,
                      height: Timeline.lane,
                      child: _Lane(
                        map: widget.maps[i],
                        runs: [
                          for (final o in all)
                            if (o.map == widget.maps[i]) o
                        ],
                        x: x,
                        now: now,
                        looted: widget.looted,
                        scroll: _scroll,
                      ),
                    ),
                  // now
                  _NowLine(x: x, label: s.t('now')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// the red line for the current moment, the only part of the timeline that
/// moves every second
class _NowLine extends ConsumerWidget {
  const _NowLine({required this.x, required this.label});

  final double Function(DateTime) x;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClockBuilder(
      step: ClockStep.second,
      builder: (context, now) {
        return Positioned(
          left: Timeline.gutter + x(now) - 1,
          top: 16,
          bottom: 0,
          child: IgnorePointer(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(4)),
                  child: Text(label,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.bg)),
                ),
                Expanded(child: Container(width: 2, color: AppColors.red)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.map,
    required this.runs,
    required this.x,
    required this.now,
    required this.looted,
    required this.scroll,
  });

  final MetaMap map;
  final List<Occurrence> runs;
  final double Function(DateTime) x;
  final DateTime now;
  final Set<String> looted;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final tint = map.release.color;
    return Stack(
      children: [
        // the map name rides along with the scroll so it is always readable
        Positioned(
          left: Timeline.gutter,
          top: 4,
          child: AnimatedBuilder(
            animation: scroll,
            builder: (context, child) =>
                Transform.translate(offset: Offset(scroll.hasClients ? scroll.offset : 0, 0), child: child),
            child: Text(
              map.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
            ),
          ),
        ),
        for (final o in runs)
          Positioned(
            left: Timeline.gutter + x(o.start),
            width: (o.event.minutes * Timeline.pxPerMinute - 2).clamp(6, double.infinity).toDouble(),
            top: 22,
            height: 30,
            child: _Block(
              occurrence: o,
              tint: tint,
              active: o.activeAt(now),
              past: !o.end.isAfter(now),
              looted: lootedRun(o, looted, now),
            ),
          ),
      ],
    );
  }
}

class _Block extends ConsumerWidget {
  const _Block({
    required this.occurrence,
    required this.tint,
    required this.active,
    required this.past,
    required this.looted,
  });

  final Occurrence occurrence;
  final Color tint;
  final bool active;
  final bool past;
  final bool looted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = occurrence;
    final dim = past || looted;
    final pinned = ref.watch(pinnedEventsProvider).contains(eventKey(o.map, o.event));
    // a tap opens the event, where it can be pinned. the old tooltip only
    // showed the name, so nothing on the timeline could be pinned
    return GestureDetector(
      onTap: () => showEventSheet(context, ref, o),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: dim ? 0.08 : (active ? 0.34 : 0.18)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tint.withValues(alpha: active ? 1 : (dim ? 0.2 : 0.5)), width: active ? 1.5 : 1),
        ),
        // narrow blocks cut their label instead of overflowing
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pinned) ...[
                  const Icon(Icons.push_pin, size: 11, color: AppColors.gold),
                  const SizedBox(width: 3),
                ],
                if (looted) ...[
                  const Icon(Icons.check_rounded, size: 12, color: AppColors.green),
                  const SizedBox(width: 3),
                ],
                if (o.event.kind == MetaKind.hardBoss) ...[
                  const Icon(Icons.local_fire_department_rounded, size: 12, color: AppColors.red),
                  const SizedBox(width: 2),
                ],
                Text(
                  o.event.name,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: dim ? AppColors.hint : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// one run of an event from the timeline: when it runs, how long until it
/// starts, and buttons to pin it or read about it on the wiki
void showEventSheet(BuildContext context, WidgetRef ref, Occurrence o) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final s = ref.watch(stringsProvider);
        final key = eventKey(o.map, o.event);
        final pinned = ref.watch(pinnedEventsProvider).contains(key);
        final now = DateTime.now();
        final when = o.activeAt(now)
            ? s.t('event_running')
            : o.start.isAfter(now)
                ? s.t('event_starts_in', {'t': countdown(o.start.difference(now))})
                : s.t('event_ended');
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.event.name, style: display(19)),
                const SizedBox(height: 4),
                Text('${o.map.name} · ${localClock(o.start)}–${localClock(o.end)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(when, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => ref.read(pinnedEventsProvider.notifier).toggle(key),
                        icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18),
                        label: Text(pinned ? s.t('unpin') : s.t('pin')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // read what the page needs before the sheet goes away
                          openWikiPage(context, ref, o.event.name);
                          Navigator.of(ctx).pop();
                        },
                        icon: const Icon(Icons.menu_book_outlined, size: 18),
                        label: Text(s.t('wiki')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
