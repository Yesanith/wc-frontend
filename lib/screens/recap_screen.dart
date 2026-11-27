import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../services/share_card.dart';
import '../state/clock.dart';
import '../state/recap.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

/// the recap of the year or of the wizard's vault season, as a card to share
class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key});

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  final _cardKey = GlobalKey();
  var _span = RecapSpan.year;
  var _busy = false;

  Future<void> _share() async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      await shareCard(_cardKey, name: 'recap', text: 'Wondrous Compass');
    } catch (_) {
      if (mounted) showToast(context, s.t('share_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final value = ref.watch(recapProvider(_span));
    return Scaffold(
      appBar: AppBar(surfaceTintColor: Colors.transparent, title: Text(s.t('recap'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: SegmentedButton<RecapSpan>(
              segments: [
                ButtonSegment(value: RecapSpan.year, label: Text(s.t('recap_year'))),
                ButtonSegment(value: RecapSpan.season, label: Text(s.t('recap_season'))),
              ],
              selected: {_span},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _span = v.first),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AsyncView<Recap?>(
                value: value,
                onRetry: () => ref.invalidate(recapProvider(_span)),
                builder: (r) => r == null
                    ? EmptyNote(s.t('recap_no_season'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          RepaintBoundary(key: _cardKey, child: RecapCard(recap: r)),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _share,
                              icon: const Icon(Icons.ios_share),
                              label: Text(s.t('share')),
                            ),
                          ),
                          const SizedBox(height: 14),
                          for (final note in recapNotes(s, r))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(note, style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted)),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// what the card leaves out or counts from less than the span, said under it
List<String> recapNotes(S s, Recap r) => [
      if (r.wealth == null)
        s.t('recap_note_no_wealth')
      else if (!r.wealth!.whole)
        s.t('recap_note_wealth', {'d': shortDateText(s, DateTime.parse(r.wealth!.first.day))}),
      if (r.trade != null && r.tradePartial) s.t('recap_note_trade'),
      if (!r.signedIn) s.t('recap_note_guild'),
    ];

String _signed(int n, String unit) => '${n >= 0 ? '+' : '−'}${fmtInt(n.abs())}$unit';

class RecapCard extends ConsumerWidget {
  const RecapCard({super.key, required this.recap});

  final Recap recap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = recap;
    final heading = r.span == RecapSpan.year ? '${r.from.year}' : (r.title ?? s.t('recap_season'));
    final dates = '${shortDateText(s, r.from)} – ${shortDateText(s, r.to.subtract(const Duration(days: 1)))}';
    final fg = AppColors.text;
    final muted = AppColors.muted;

    final stats = <(String, String, String?)>[
      if (r.coins != null) (s.t('recap_gold'), _signed(r.coins! ~/ 10000, 'g'), null),
      if (r.playHours != null) (s.t('recap_played'), s.t('recap_hours_n', {'n': fmtInt(r.playHours!)}), null),
      if (r.guild != null)
        (
          s.t('recap_events'),
          fmtInt(r.guild!.events),
          r.guild!.events == 0
              ? null
              : s.t('recap_events_sub', {'h': fmtInt(r.guild!.hours.round()), 'g': r.guild!.guilds}),
        ),
      if (r.guild != null && r.guild!.hosted > 0) (s.t('recap_hosted'), fmtInt(r.guild!.hosted), null),
      if (r.trade != null && r.trade!.sold > 0)
        (s.t('recap_sold'), fmtInt(r.trade!.sold), _signed(r.trade!.soldCoins ~/ 10000, 'g')),
      if (r.specialTotal != null && r.specialTotal! > 0)
        (s.t('recap_vault_special'), '${r.specialDone} / ${r.specialTotal}', null),
      if (r.karma != null && r.karma != 0) (s.t('recap_karma'), _signed(r.karma!, ''), null),
    ];
    final top = r.guild?.topActivity;

    Widget stat((String, String, String?) st) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(st.$1.caps,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: muted)),
              const SizedBox(height: 2),
              Text(st.$2, style: display(24, color: fg)),
              if (st.$3 != null)
                Text(st.$3!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
            ],
          ),
        );

    final rows = <Widget>[];
    for (var i = 0; i < stats.length; i += 2) {
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: stat(stats[i])),
        const SizedBox(width: 12),
        Expanded(child: i + 1 < stats.length ? stat(stats[i + 1]) : const SizedBox.shrink()),
      ]));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withAlpha(140), width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            DiamondEmblem(size: 34, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.t(r.span == RecapSpan.year ? 'recap_year' : 'recap_season').caps,
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: AppColors.gold)),
                Text(heading, maxLines: 2, overflow: TextOverflow.ellipsis, style: display(26, color: fg)),
              ]),
            ),
          ]),
          const SizedBox(height: 4),
          Text(dates, style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 12),
          Divider(color: muted.withAlpha(90), height: 1),
          const SizedBox(height: 6),
          if (stats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(s.t('recap_empty'), textAlign: TextAlign.center, style: TextStyle(color: muted)),
            )
          else
            ...rows,
          if (top != null && top != 'other') ...[
            const SizedBox(height: 6),
            Text(s.t('recap_top', {'a': s.t('activity_$top')}),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
          ],
          const SizedBox(height: 14),
          Text(
            'WONDROUS COMPASS${r.account != null ? ' · ${r.account}' : ''}'.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: muted),
          ),
        ],
      ),
    );
  }
}
