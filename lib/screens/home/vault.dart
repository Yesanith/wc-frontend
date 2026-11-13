part of '../home_screen.dart';

class _Vault extends ConsumerStatefulWidget {
  const _Vault();

  @override
  ConsumerState<_Vault> createState() => _VaultState();
}

class _VaultState extends ConsumerState<_Vault> {
  String _track = 'daily';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final period = ref.watch(vaultTrackProvider(_track));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _VaultBars(),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.gold.withValues(alpha: 0.18),
                selectedForegroundColor: AppColors.text,
                foregroundColor: AppColors.muted,
                side: BorderSide(color: AppColors.line),
              ),
              segments: [
                ButtonSegment(value: 'daily', label: Text(s.t('vault_daily'))),
                ButtonSegment(value: 'weekly', label: Text(s.t('vault_weekly'))),
                ButtonSegment(value: 'special', label: Text(s.t('vault_special'))),
              ],
              selected: {_track},
              onSelectionChanged: (v) => setState(() => _track = v.first),
            ),
          ),
          const SizedBox(height: 16),
          AsyncView<Json>(
            value: period,
            onRetry: () => ref.invalidate(vaultTrackProvider(_track)),
            builder: (v) {
              // yesterday's objectives are not shown as today's: the new ones come when the player logs in
              if (ref.watch(vaultStaleProvider(_track))) return VaultAwaitingLogin(track: _track);
              final objectives = [
                for (final o in (v['objectives'] as List?) ?? const [])
                  if (o is Map) Map<String, dynamic>.from(o)
              ];
              if (objectives.isEmpty) return EmptyNote(s.t('vault_empty'), center: false);
              bool done(Json o) =>
                  asInt(o['progress_complete']) > 0 && asInt(o['progress_current']) >= asInt(o['progress_complete']);
              double ratio(Json o) =>
                  asInt(o['progress_complete']) <= 0 ? 0 : asInt(o['progress_current']) / asInt(o['progress_complete']);
              final finished = objectives.where(done).length;
              final left = objectives.where((o) => o['claimed'] != true).fold(0, (sum, o) => sum + asInt(o['acclaim']));
              final metaGoal = asInt(v['meta_progress_complete']);
              final metaNow = asInt(v['meta_progress_current']);
              // open objectives first, the closest to done on top
              objectives.sort((a, b) {
                if (done(a) != done(b)) return done(a) ? 1 : -1;
                return ratio(b).compareTo(ratio(a));
              });
              return Column(
                children: [
                  Row(
                    children: [
                      Ring(
                        value: metaGoal > 0 ? metaNow / metaGoal : finished / objectives.length,
                        size: 64,
                        child: Text(
                          metaGoal > 0 ? '$metaNow/$metaGoal' : '$finished',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFeatures: _tabular),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                // the ring is the track of the chest, which is not all of the objectives
                                metaGoal > 0 && metaGoal != objectives.length
                                    ? s.t(
                                        'objectives_done_chest', {'a': finished, 'b': objectives.length, 'c': metaGoal})
                                    : s.t('objectives_done', {'a': finished, 'b': objectives.length}),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(s.t('acclaim_left', {'n': fmtInt(left)}),
                                style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  VaultChestReward(v),
                  for (final o in objectives) _Objective(o, done: done(o), ratio: ratio(o)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Objective extends StatelessWidget {
  const _Objective(this.o, {required this.done, required this.ratio});

  final Json o;
  final bool done;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final claimed = o['claimed'] == true;
    final track = switch ('${o['track']}') {
      'PvP' => AppColors.red,
      'WvW' => AppColors.amber,
      _ => AppColors.blue,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
              width: 3, height: 30, decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${o['title'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: done ? AppColors.muted : AppColors.text,
                    decoration: claimed ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (!done) ...[
                  const SizedBox(height: 5),
                  Meter(value: ratio, height: 4),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (done)
            Icon(claimed ? Icons.check_circle_rounded : Icons.redeem_rounded,
                color: claimed ? AppColors.green : AppColors.amber, size: 20)
          else
            Text('${asInt(o['progress_current'])}/${asInt(o['progress_complete'])}',
                style: TextStyle(fontSize: 12, color: AppColors.muted, fontFeatures: _tabular)),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text('${asInt(o['acclaim'])}',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
}
