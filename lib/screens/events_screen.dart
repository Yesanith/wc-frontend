import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/world_bosses.dart';
import '../l10n/strings.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String localClock(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}

String untilText(S s, DateTime start, DateTime now) {
  final mins = start.difference(now).inMinutes;
  if (mins < 1) return s.t('now');
  if (mins < 60) return s.t('in_min', {'m': mins});
  return s.t('in_h_min', {'h': mins ~/ 60, 'm': _two(mins % 60)});
}

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key, this.embedded = false});

  /// true when shown inside the drawer shell, which brings its own app bar
  final bool embedded;

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  bool _visible = true;
  Timer? _tick;
  bool _pinnedOnly = false;

  /// null means every release
  Expansion? _expansion;

  @override
  void initState() {
    super.initState();
    // countdowns only need minute precision
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      // _visible follows TickerMode, which is off while the section is
      // hidden in the drawer stack
      if (mounted && _visible) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _visible = TickerMode.valuesOf(context).enabled;
    final s = ref.watch(stringsProvider);
    final pinned = ref.watch(pinnedEventsProvider);
    final done = ref.watch(doneTodayProvider('worldbosses')).valueOrNull ?? const <String>{};
    final now = DateTime.now().toUtc();
    var spawns = upcomingSpawns(now, ahead: const Duration(hours: 6));
    if (_pinnedOnly) spawns = spawns.where((e) => pinned.contains(e.boss.id)).toList();
    final release = _expansion;
    if (release != null) spawns = spawns.where((e) => e.boss.expansion == release).toList();

    BossSpawn? featured;
    for (final e in spawns) {
      if (e.isActive(now)) {
        featured = e;
        break;
      }
    }
    featured ??= spawns.isEmpty ? null : spawns.first;
    final top = featured;
    final rest = spawns.where((e) => e != top).toList();

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(s.t('local_time_note'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 12),
        Row(
          children: [
            ChoiceChip(
              label: Text(s.t('all')),
              selected: !_pinnedOnly,
              onSelected: (_) => setState(() => _pinnedOnly = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(s.t('pinned')),
              selected: _pinnedOnly,
              onSelected: (_) => setState(() => _pinnedOnly = true),
            ),
          ],
        ),
        // only shown once there is more than one release to choose between
        if (expansionsWithBosses.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: Text(s.t('all')),
                  selected: _expansion == null,
                  onSelected: (_) => setState(() => _expansion = null),
                ),
                for (final e in expansionsWithBosses) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(e.label),
                    selected: _expansion == e,
                    onSelected: (_) => setState(() => _expansion = e),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (top == null)
          Panel(child: Text(s.t('nothing_pinned'), style: const TextStyle(color: AppColors.muted)))
        else
          _FeaturedBoss(spawn: top, now: now),
        const SizedBox(height: 16),
        const _DailyResets(),
        const SizedBox(height: 8),
        for (final e in rest)
          _BossRow(
            spawn: e,
            now: now,
            pinned: pinned.contains(e.boss.id),
            done: bossDone(e.boss, done),
          ),
      ],
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(s.t('world_bosses'), style: display(20)),
      ),
      body: body,
    );
  }
}

/// daily craft and map chest progress for today
class _DailyResets extends ConsumerWidget {
  const _DailyResets();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final crafts = ref.watch(dailyProgressProvider('dailycrafting')).valueOrNull;
    final chests = ref.watch(dailyProgressProvider('mapchests')).valueOrNull;
    if (crafts == null && chests == null) return const SizedBox.shrink();

    Widget row(String label, DailyProgress? p) {
      if (p == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSoft))),
            Text('${p.done} / ${p.total}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: p.done >= p.total && p.total > 0 ? AppColors.green : AppColors.gold)),
          ],
        ),
      );
    }

    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          row(s.t('daily_crafts'), crafts),
          row(s.t('map_chests'), chests),
        ],
      ),
    );
  }
}

/// the /account/worldbosses endpoint uses snake_case names, our own ids
/// match some of them, so check both
bool bossDone(WorldBoss boss, Set<String> done) {
  if (done.isEmpty) return false;
  final fromName = boss.name.toLowerCase().replaceAll(' ', '_');
  return done.contains(boss.id) || done.contains(fromName);
}

class _FeaturedBoss extends ConsumerWidget {
  const _FeaturedBoss({required this.spawn, required this.now});

  final BossSpawn spawn;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final done = bossDone(spawn.boss, ref.watch(doneTodayProvider('worldbosses')).valueOrNull ?? const {});
    final active = spawn.isActive(now);
    final elapsed = now.difference(spawn.start).inSeconds / bossWindow.inSeconds;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill(
                active ? s.t('active_now') : s.t('up_next'),
                color: active ? AppColors.onGold : AppColors.gold,
                background: active ? AppColors.gold : AppColors.surface2,
              ),
              if (done) ...[
                const SizedBox(width: 8),
                Pill(s.t('done_today'), color: AppColors.green, background: AppColors.surface2),
              ],
              const Spacer(),
              Text(
                active
                    ? s.t('started_ago', {'m': now.difference(spawn.start).inMinutes})
                    : '${untilText(s, spawn.start, now)} · ${localClock(spawn.start)}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(spawn.boss.name, style: display(22)),
          Text(spawn.boss.map, style: const TextStyle(fontSize: 14, color: AppColors.textSoft)),
          if (active) ...[
            const SizedBox(height: 12),
            Bar(value: elapsed),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openWikiPage(context, ref, spawn.boss.name),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(s.t('wiki')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BossRow extends ConsumerWidget {
  const _BossRow({required this.spawn, required this.now, required this.pinned, required this.done});

  final BossSpawn spawn;
  final DateTime now;
  final bool pinned;
  final bool done;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return InkWell(
      onTap: () => openWikiPage(context, ref, spawn.boss.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(localClock(spawn.start),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.gold)),
                  Text(untilText(s, spawn.start, now), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 10,
              height: 10,
              transform: Matrix4.rotationZ(0.785398),
              transformAlignment: Alignment.center,
              color: spawn.boss.hardcore ? AppColors.gold : AppColors.line,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (done) ...[
                        const Icon(Icons.check_circle, size: 14, color: AppColors.green),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          spawn.boss.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: done ? AppColors.muted : AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(spawn.boss.map, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            IconButton(
              tooltip: pinned ? s.t('unpin') : s.t('pin'),
              onPressed: () => ref.read(pinnedEventsProvider.notifier).toggle(spawn.boss.id),
              icon: Icon(
                pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: pinned ? AppColors.gold : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
