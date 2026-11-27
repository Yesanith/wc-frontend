part of '../events_screen.dart';

/// a train of events for the next hours: one after another with time to travel between them, what is looted today left out. each
/// with its time, its map and its waypoint to copy
class MetaTrainScreen extends ConsumerStatefulWidget {
  const MetaTrainScreen({super.key});

  @override
  ConsumerState<MetaTrainScreen> createState() => _MetaTrainScreenState();
}

class _MetaTrainScreenState extends ConsumerState<MetaTrainScreen> {
  var _hours = 2;
  var _kind = KindFilter.all;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final looted = ref.watch(doneTodayProvider('worldbosses')).valueOrNull ?? const <String>{};
    final pins = ref.watch(pinnedEventsProvider);
    final releases = ref.watch(releaseFilterProvider);
    final maps = [
      for (final m in ref.watch(shownMetaMapsProvider))
        if (releases.isEmpty || releases.contains(m.release)) m
    ];
    return Scaffold(
      appBar: AppBar(surfaceTintColor: Colors.transparent, title: Text(s.t('meta_train'))),
      body: ClockBuilder(
        step: ClockStep.minute,
        builder: (context, now) {
          final train = planTrain(
            now,
            Duration(hours: _hours),
            maps: maps,
            where: (o) => _matches(o.map, o.event, _kind, pins) && !lootedRun(o, looted, now),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(s.t('meta_train_note'), style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final h in const [1, 2, 3])
                  ChoiceChip(
                    label: Text(s.t('n_hours', {'n': h})),
                    selected: _hours == h,
                    onSelected: (_) => setState(() => _hours = h),
                  ),
                Container(width: 1, height: 28, color: AppColors.line),
                for (final k in const [KindFilter.all, KindFilter.bosses, KindFilter.metas])
                  ChoiceChip(
                    label: Text(switch (k) {
                      KindFilter.bosses => s.t('filter_bosses'),
                      KindFilter.metas => s.t('filter_metas'),
                      _ => s.t('all'),
                    }),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ]),
              const SizedBox(height: 14),
              if (train.isEmpty) EmptyNote(s.t('meta_train_none')),
              for (final (i, o) in train.indexed)
                _TrainStop(o: o, now: now, next: i + 1 < train.length ? train[i + 1] : null),
            ],
          );
        },
      ),
    );
  }
}

class _TrainStop extends ConsumerWidget {
  const _TrainStop({required this.o, required this.now, required this.next});

  final Occurrence o;
  final DateTime now;
  final Occurrence? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final waypoint = waypointFor(o.map, o.event);
    final wait = next?.start.difference(o.end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 62,
                child: Text(localClock(o.start), style: display(22, color: AppColors.gold)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.event.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    Text('${o.map.name} · ${o.event.minutes} min',
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    if (o.activeAt(now))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Pill(s.t('event_running'), color: AppColors.green),
                      ),
                    if (waypoint != null) ...[const SizedBox(height: 6), WaypointLink(waypoint)],
                  ],
                ),
              ),
              ExpansionBadge(o.map.release),
            ],
          ),
        ),
        if (wait != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              const SizedBox(width: 30),
              Icon(Icons.more_vert, size: 16, color: AppColors.chevron),
              const SizedBox(width: 6),
              Text(s.t('meta_train_wait', {'t': countdown(wait)}),
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          )
        else
          const SizedBox(height: 8),
      ],
    );
  }
}
