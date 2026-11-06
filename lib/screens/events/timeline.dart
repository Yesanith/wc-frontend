part of '../events_screen.dart';

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
        final start = DateTime.utc(
          origin.year,
          origin.month,
          origin.day,
          origin.hour,
          origin.minute - origin.minute % 5,
        );
        final end = start.add(Timeline.span);
        double x(DateTime t) => t.difference(start).inSeconds / 60 * Timeline.pxPerMinute;
        final width = x(end);
        final all = occurrences(
          start,
          end,
          maps: widget.maps,
        ).where((o) => _matches(o.map, o.event, widget.kind, widget.pins)).toList();
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
                  for (
                    var t = DateTime.utc(start.year, start.month, start.day, start.hour);
                    t.isBefore(end);
                    t = t.add(const Duration(minutes: 30))
                  )
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
                            if (o.map == widget.maps[i]) o,
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
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.bg),
                  ),
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
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
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
          border: Border.all(
            color: tint.withValues(alpha: active ? 1 : (dim ? 0.2 : 0.5)),
            width: active ? 1.5 : 1,
          ),
        ),
        // narrow blocks cut their label instead of overflowing
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pinned) ...[Icon(Icons.push_pin, size: 11, color: AppColors.gold), const SizedBox(width: 3)],
                if (looted) ...[Icon(Icons.check_rounded, size: 12, color: AppColors.green), const SizedBox(width: 3)],
                if (o.event.kind == MetaKind.hardBoss) ...[
                  Icon(Icons.local_fire_department_rounded, size: 12, color: AppColors.red),
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
