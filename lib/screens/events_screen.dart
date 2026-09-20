import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/world_bosses.dart';
import '../l10n/strings.dart';
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
  Timer? _tick;
  bool _pinnedOnly = false;

  @override
  void initState() {
    super.initState();
    // countdowns only need minute precision
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final pinned = ref.watch(pinnedEventsProvider);
    final now = DateTime.now().toUtc();
    var spawns = upcomingSpawns(now, ahead: const Duration(hours: 6));
    if (_pinnedOnly) spawns = spawns.where((e) => pinned.contains(e.boss.id)).toList();

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
          const SizedBox(height: 14),
          if (top == null)
            Panel(child: Text(s.t('nothing_pinned'), style: const TextStyle(color: AppColors.muted)))
          else
            _FeaturedBoss(spawn: top, now: now),
          const SizedBox(height: 16),
          for (final e in rest) _BossRow(spawn: e, now: now, pinned: pinned.contains(e.boss.id)),
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

class _FeaturedBoss extends ConsumerWidget {
  const _FeaturedBoss({required this.spawn, required this.now});

  final BossSpawn spawn;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
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
  const _BossRow({required this.spawn, required this.now, required this.pinned});

  final BossSpawn spawn;
  final DateTime now;
  final bool pinned;

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
                  Text(untilText(s, spawn.start, now),
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
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
                  Text(spawn.boss.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
