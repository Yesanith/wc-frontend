part of '../progression_screen.dart';

/// how many raid bosses, fractals, dungeon paths, world bosses and metas the account has done, as the server counts
/// them for a player who agreed, and the legendaries of its armory, which the game tells at once
class _ClearsTab extends ConsumerWidget {
  const _ClearsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final name = ref.watch(accountProvider).valueOrNull?['name'] as String?;
    final signedIn = communityReady && ref.watch(sessionProvider).valueOrNull != null;
    final counts = ref.watch(clearCountsProvider);
    final mine = clearsOf(counts.valueOrNull ?? const [], name);

    return ContentFrame(
      maxWidth: readingMaxWidth,
      child: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(clearCountsProvider);
          ref.invalidate(legendaryCountProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!signedIn)
                  _ClearsAsk(text: s.t('clears_sign_in'))
                else if (counts.isLoading && !counts.hasValue)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                else if (counts.hasError)
                  ErrorBox(error: counts.error, onRetry: () => ref.invalidate(clearCountsProvider))
                else if (mine == null || mine.status == 'off' && mine.total.values.every((n) => n == 0))
                  const _ClearsAsk()
                else
                  _ClearsBoard(counts: mine),
                const SizedBox(height: 18),
                const _LegendaryPanel(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// what the count takes, in plain words, and the button that starts it
class _ClearsAsk extends ConsumerStatefulWidget {
  const _ClearsAsk({this.text});

  /// in place of the button, why it cannot be started
  final String? text;

  @override
  ConsumerState<_ClearsAsk> createState() => _ClearsAskState();
}

class _ClearsAskState extends ConsumerState<_ClearsAsk> {
  var _busy = false;

  Future<void> _start() async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      await startClearWatch(ref.read(gw2ApiProvider));
      if (mounted) showToast(context, s.t('clears_on'));
    } on LinkFailure catch (e) {
      final key = switch (e.code) {
        'not_linked' || 'missing_permission' || 'subtoken_failed' => 'clears_needs',
        'rate_limited' => 'err_rate_limited',
        _ => 'clears_failed',
      };
      if (mounted) showToast(context, '${s.t(key)} (${e.code})', duration: const Duration(seconds: 6));
    } catch (e) {
      if (mounted) showToast(context, '${s.t('clears_failed')} (${'$e'.split('\n').first})');
    } finally {
      ref.invalidate(clearCountsProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.military_tech_outlined, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(child: Text(s.t('clears_title'), style: display(20))),
          ]),
          const SizedBox(height: 10),
          Text(s.t('clears_ask'), style: TextStyle(height: 1.45, color: AppColors.textSoft)),
          const SizedBox(height: 14),
          if (widget.text != null)
            Text(widget.text!, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.gold))
          else
            FilledButton.icon(
              onPressed: _busy ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: Text(s.t('clears_start')),
            ),
        ],
      ),
    );
  }
}

class _ClearsBoard extends ConsumerWidget {
  const _ClearsBoard({required this.counts});

  final ClearCounts counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final c = counts;
    Widget tile(String kind) => Panel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker(s.t('clears_$kind').caps, color: AppColors.muted),
              const SizedBox(height: 4),
              Text(fmtInt(c.total[kind] ?? 0), style: display(30)),
              Text(s.t('clears_week', {'n': fmtInt(c.week[kind] ?? 0)}),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.gold)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.t('clears_title'), style: display(22)),
              if (c.since != null)
                Text(s.t('clears_since', {'d': shortDateText(s, c.since!)}),
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          PopupMenuButton<String>(
            tooltip: s.t('tab_more'),
            icon: Icon(Icons.more_vert, color: AppColors.muted),
            onSelected: (v) async {
              if (v == 'start') {
                await startClearWatch(ref.read(gw2ApiProvider)).catchError((_) => '');
              } else {
                await stopClearWatch(c.accountId, forget: v == 'forget');
              }
              ref.invalidate(clearCountsProvider);
            },
            itemBuilder: (_) => [
              if (!c.on) PopupMenuItem(value: 'start', child: Text(s.t('clears_start'))),
              if (c.on) PopupMenuItem(value: 'stop', child: Text(s.t('clears_stop'))),
              PopupMenuItem(value: 'forget', child: Text(s.t('clears_forget'))),
            ],
          ),
        ]),
        if (c.status == 'refused') ...[
          const SizedBox(height: 8),
          Text(s.t('clears_refused'), style: TextStyle(fontSize: 13, color: AppColors.gold)),
        ] else if (c.status == 'off') ...[
          const SizedBox(height: 8),
          Text(s.t('clears_off'), style: TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, box) {
          final columns = box.maxWidth >= 640 ? 3 : 2;
          const gap = 12.0;
          final w = (box.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(spacing: gap, runSpacing: gap, children: [
            for (final k in clearKinds) SizedBox(width: w, child: tile(k)),
          ]);
        }),
        const SizedBox(height: 10),
        Text(s.t('clears_note'), style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted)),
      ],
    );
  }
}

class _LegendaryPanel extends ConsumerWidget {
  const _LegendaryPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AsyncView<({int kinds, int total})>(
      permission: 'unlocks',
      value: ref.watch(legendaryCountProvider),
      onRetry: () => ref.invalidate(legendaryCountProvider),
      builder: (l) => Panel(
        child: Row(children: [
          Icon(Icons.auto_awesome, color: AppColors.gold),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Kicker(s.t('clears_legendary').caps, color: AppColors.muted),
              Text(s.t('clears_legendary_n', {'n': fmtInt(l.kinds), 't': fmtInt(l.total)}),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
          ),
          Text(fmtInt(l.kinds), style: display(30)),
        ]),
      ),
    );
  }
}
