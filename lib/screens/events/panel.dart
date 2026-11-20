part of '../events_screen.dart';

/// the event that is looked at in the timeline of a site: the one that was clicked, or else the next one. null is the next one
final selectedEventProvider = StateProvider<Occurrence?>((ref) => null);

/// whether the timeline has the panel of the selected event beside it, as a site with room has, or opens a sheet from the bottom
bool eventPanelFits(BuildContext context) => SiteScope.of(context) && MediaQuery.sizeOf(context).width >= 1100;

/// beside the timeline: the event that is selected, when it runs, where it is on the map, the waypoint to go to and what to do with it
class _EventPanel extends ConsumerWidget {
  const _EventPanel({required this.maps, required this.kind, required this.pins});

  final List<MetaMap> maps;
  final KindFilter kind;
  final Set<String> pins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final chosen = ref.watch(selectedEventProvider);
    return ClockBuilder(
      step: ClockStep.minute,
      builder: (context, now) {
        final o = chosen ??
            (upNext(now, count: 1, where: (c) => maps.contains(c.map) && _matches(c.map, c.event, kind, pins)))
                .firstOrNull;
        if (o == null) return const SizedBox.shrink();
        final key = eventKey(o.map, o.event);
        final pinned = pins.contains(key);
        final waypoint = waypointFor(o.map, o.event);
        final point = waypoint == null ? null : waypointPoints[waypoint.code];
        final when = o.activeAt(now)
            ? s.t('event_running')
            : o.start.isAfter(now)
                ? s.t('event_starts_in', {'t': countdown(o.start.difference(now))})
                : s.t('event_ended');
        final later = [
          for (final r in occurrences(now, now.add(const Duration(hours: 8)), maps: [o.map]))
            if (r.event == o.event && r.start.isAfter(o.start)) r,
        ].take(3).toList();
        return Panel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.t('selected').caps,
                  style:
                      TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: AppColors.gold)),
              const SizedBox(height: 6),
              Text(o.event.name, style: display(26).copyWith(height: 1.1)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _PanelChip(label: o.map.release.code, dot: o.map.release.color),
                  _PanelChip(label: o.event.kind == MetaKind.meta ? s.t('filter_metas') : s.t('filter_bosses')),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(localClock(o.start), style: display(38).copyWith(color: AppColors.gold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('$when · ${o.event.minutes} min',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(o.map.name, style: const TextStyle(fontSize: 14)),
              if (point != null) ...[
                const SizedBox(height: 12),
                MiniMap(x: point.$1, y: point.$2),
              ],
              if (waypoint != null) ...[
                const SizedBox(height: 12),
                WaypointLink(waypoint),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => openWikiPage(context, ref, o.event.wiki ?? o.event.name),
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: Text(s.t('wiki')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: pinned ? s.t('unpin') : s.t('pin'),
                    onPressed: () => togglePin(context, ref, key),
                    icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 20, color: AppColors.gold),
                  ),
                ],
              ),
              if (later.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('${s.t('event_next_runs')}: ${later.map((r) => localClock(r.start)).join(' · ')}',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PanelChip extends StatelessWidget {
  const _PanelChip({required this.label, this.dot});

  final String label;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
