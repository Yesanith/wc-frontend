import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/metas.dart';
import '../data/waypoints.dart';
import '../services/icon_cache.dart';
import '../state/account.dart';
import '../state/api.dart';
import '../state/alerts.dart';
import '../state/clock.dart';
import '../widgets/stale_note.dart';
import '../widgets/clock.dart';
import '../state/navigation.dart';
import '../state/periodic.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../state/wvw.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/meters.dart';
import '../widgets/pin_button.dart';
import '../widgets/vault_objectives.dart' show VaultChestReward;
import '../widgets/waypoint_link.dart';
import '../state/news.dart';
import '../state/market.dart' show TpPrice;
import '../state/trading.dart';
import 'achievement_detail_screen.dart';
import 'events_screen.dart';

part 'home/banners.dart';
part 'home/vault.dart';
part 'home/wallet.dart';
part 'home/extras.dart';

const _tabular = [FontFeature.tabularFigures()];

/// the day at a glance: resets, the vault, what is coming up, the daily
/// checklist and the wallet
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) => refreshProviders(ref, [
        triggeredAlertsProvider,
        accountProvider,
        walletProvider,
        vaultTrackProvider,
        dailyProgressProvider,
        doneTodayProvider,
        pinnedAchievementRowsProvider,
      ]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final hasKey = ref.watch(hasKeyProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => _refresh(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // the day's name, the greeting and the clocks everyone plans around, in one strip
          const _HomeHero(),
          const _AlertBanner(),
          const _NewsBanner(),
          // a guest has no vault, checklist or wallet to show
          if (!hasKey) const _GuestCard(),
          // what is coming, as cards in a row where there is room
          Eyebrow(
            s.t('up_next'),
            trailing: TextButton(
              onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.bosses,
              child: Text(s.t('all_timers')),
            ),
          ),
          const _UpNext(),
          // what the account holds, side by side where there is room: the vault, the purse, the day's tallies
          if (hasKey) ...[
            const SizedBox(height: 8),
            CardWrap(
              minWidth: 330,
              gap: 20,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Eyebrow(s.t('wizards_vault')),
                  const _Vault(),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Eyebrow(s.t('trading_post')),
                  const _TradeBox(),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Eyebrow(s.t('wallet')),
                  const _Wallet(),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Eyebrow(s.t('daily_checklist')),
                  const _Checklist(),
                  const _WvwMini(),
                  const _PinnedAchievements(),
                ]),
              ],
            ),
          ],
          const _LatestNews(),
        ],
      ),
    );
  }
}

/// the date and the time in capitals, the greeting under it, and the clocks at the right of it: the daily and the weekly
/// reset, and how far the vault is. on a phone they go under the greeting
class _HomeHero extends ConsumerWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final hasKey = ref.watch(hasKeyProvider);
    final name = '${ref.watch(accountProvider).valueOrNull?['name'] ?? ''}';
    final short = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    final hour = DateTime.now().hour;
    final key = hour < 12
        ? 'good_morning'
        : hour < 18
            ? 'good_afternoon'
            : 'good_evening';
    final site = SiteScope.of(context);
    final greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClockBuilder(
          step: ClockStep.minute,
          builder: (context, now) => Text(
            '${fullDateText(s, now.toLocal())} · ${localClock(now)}'.caps,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.8, color: AppColors.gold),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          short.isEmpty ? s.t('welcome') : s.t(key, {'name': short}),
          style: display(site ? 40 : 28).copyWith(height: 1.1),
        ),
      ],
    );
    final chips = Wrap(spacing: 10, runSpacing: 10, children: [
      const _ResetChip(weekly: false),
      const _ResetChip(weekly: true),
      if (hasKey) const _VaultChip(),
    ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 820
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [Expanded(child: greeting), const SizedBox(width: 24), chips],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [greeting, const SizedBox(height: 16), chips]),
      ),
    );
  }
}

/// a small framed number with its name over it, the form the day's clocks take in the hero
class _HomeChip extends StatelessWidget {
  const _HomeChip({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label.caps,
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppColors.muted)),
              const SizedBox(height: 2),
              Text(value, style: display(22).copyWith(fontFeatures: _tabular)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetChip extends ConsumerWidget {
  const _ResetChip({required this.weekly});

  final bool weekly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ClockBuilder(
      step: ClockStep.second,
      builder: (context, now) => _HomeChip(
        label: s.t(weekly ? 'weekly_reset' : 'daily_reset'),
        value: countdown((weekly ? nextWeeklyReset(now) : nextDailyReset(now)).difference(now)),
        onTap: () => ref.read(sectionProvider.notifier).state = weekly ? AppSection.weekly : AppSection.daily,
      ),
    );
  }
}

/// how many of today's vault objectives are done, or a dash while the api still has yesterday's
class _VaultChip extends ConsumerWidget {
  const _VaultChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final v = ref.watch(vaultTrackProvider('daily')).valueOrNull;
    final stale = ref.watch(vaultStaleProvider('daily'));
    var text = '–';
    if (v != null && !stale) {
      final all = [
        for (final o in (v['objectives'] as List?) ?? const [])
          if (o is Map) o
      ];
      final done = all
          .where(
              (o) => asInt(o['progress_complete']) > 0 && asInt(o['progress_current']) >= asInt(o['progress_complete']))
          .length;
      if (all.isNotEmpty) text = '$done / ${all.length}';
    }
    return _HomeChip(
      label: s.t('wizards_vault'),
      value: text,
      onTap: () => ref.read(sectionProvider.notifier).state = AppSection.daily,
    );
  }
}

/// the matchup as one bar of the three teams' victory points, with the player's own team marked
class _WvwMini extends ConsumerWidget {
  const _WvwMini();

  static const _colors = {'green': Color(0xFF4FB36A), 'red': Color(0xFFD9534F), 'blue': Color(0xFF4B8FE0)};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final match = ref.watch(wvwMatchProvider).valueOrNull;
    final points = match?['victory_points'];
    if (match == null || points is! Map) return const SizedBox.shrink();
    final team = ref.watch(wvwTeamProvider).valueOrNull ?? 0;
    final mine = wvwColorOf(match, team);
    final values = {for (final c in _colors.keys) c: asInt(points[c])};
    if (values.values.every((v) => v == 0)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Eyebrow(s.t('wvw'),
              trailing: TextButton(
                onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.wvw,
                child: Text(s.t('wvw_matchup_open')),
              )),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(children: [
                    for (final c in _colors.keys)
                      Expanded(flex: values[c]! == 0 ? 1 : values[c]!, child: Container(height: 8, color: _colors[c])),
                  ]),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final c in _colors.keys)
                      Text(
                        '${s.t('team_$c')}${c == mine ? ' · ${s.t('your_team')}' : ''} ${fmtInt(values[c]!)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _colors[c]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// what can still be joined: fresh runs and upcoming ones, not the ones already looted today. cards in a row where
/// there is room, the rows of the timer on a phone
class _UpNext extends ConsumerWidget {
  const _UpNext();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // providers are watched here, outside the clock: its ticks rebuild only
    // the clock, where the consumer's ref may not watch anything new
    final looted = ref.watch(doneTodayProvider('worldbosses')).valueOrNull ?? const <String>{};
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 640;
        return ClockBuilder(
          step: ClockStep.minute,
          builder: (context, now) {
            final next = upNext(
              now,
              count: wide ? 4 : 5,
              where: (o) => !lootedRun(o, looted, now) && now.difference(o.start) < const Duration(minutes: 10),
            );
            if (!wide) {
              return Panel(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [for (final o in next) MetaRow(occurrence: o, looted: false)]),
              );
            }
            return CardWrap(
              minWidth: 250,
              gap: 16,
              maxColumns: 4,
              children: [
                for (var i = 0; i < next.length; i++) _EventCard(occurrence: next[i], first: i == 0, now: now)
              ],
            );
          },
        );
      },
    );
  }
}

/// one event as a card: its time large, how long until it, the name, the map and the waypoint to copy
class _EventCard extends ConsumerWidget {
  const _EventCard({required this.occurrence, required this.first, required this.now});

  final Occurrence occurrence;
  final bool first;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final o = occurrence;
    final active = o.activeAt(now);
    final waypoint = waypointFor(o.map, o.event);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: first ? AppColors.gold : AppColors.line),
        boxShadow: first ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.18), blurRadius: 22)] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => openWikiPage(context, ref, o.event.wiki ?? o.event.name),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(localClock(o.start),
                        style: display(30)
                            .copyWith(color: first ? AppColors.goldSoft : AppColors.text, fontFeatures: _tabular)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        active
                            ? s.t('ends_in', {'t': countdown(o.end.difference(now))})
                            : s.t('starts_in', {'t': countdown(o.start.difference(now))}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(o.event.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(o.map.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                if (waypoint != null) ...[const SizedBox(height: 10), WaypointLink(waypoint)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Checklist extends ConsumerWidget {
  const _Checklist();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Panel(
      child: Column(
        children: [
          _TallyRow(icon: Icons.handyman_outlined, label: s.t('daily_crafts'), path: 'dailycrafting'),
          _TallyRow(icon: Icons.inventory_2_outlined, label: s.t('map_chests'), path: 'mapchests'),
          _TallyRow(icon: Icons.whatshot_outlined, label: s.t('world_boss_loot'), path: 'worldbosses'),
        ],
      ),
    );
  }
}

class _TallyRow extends ConsumerWidget {
  const _TallyRow({required this.icon, required this.label, required this.path});

  final IconData icon;
  final String label;
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tally = ref.watch(dailyProgressProvider(path));
    final t = tally.valueOrNull;
    final complete = t != null && t.total > 0 && t.done >= t.total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: complete ? AppColors.green : AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 5),
                Meter(
                  value: t == null || t.total == 0 ? 0 : t.done / t.total,
                  height: 4,
                  color: complete ? AppColors.green : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            child: tally.hasError
                ? Icon(Icons.lock_outline, size: 16, color: AppColors.hint)
                : Text(
                    t == null ? '–' : '${t.done}/${t.total}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFeatures: _tabular),
                  ),
          ),
        ],
      ),
    );
  }
}
