import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/metas.dart';
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
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/meters.dart';
import '../widgets/pin_button.dart';
import '../state/news.dart';
import 'events_screen.dart';

part 'home/banners.dart';
part 'home/vault.dart';
part 'home/wallet.dart';

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
          const _Greeting(),
          const SizedBox(height: 16),
          const _Resets(),
          const _AlertBanner(),
          const _NewsBanner(),
          // a guest has no vault, checklist or wallet to show
          if (!hasKey) const _GuestCard(),
          // one column while narrow, in this order; two when there is room: what to do on the left,
          // what the account holds on the right
          SplitColumns(
            primary: [
              if (hasKey) ...[
                Eyebrow(s.t('wizards_vault')),
                const _Vault(),
              ],
              Eyebrow(
                s.t('up_next'),
                trailing: TextButton(
                  onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.bosses,
                  child: Text(s.t('all_timers')),
                ),
              ),
              const _UpNext(),
              if (hasKey) ...[
                Eyebrow(s.t('daily_checklist')),
                const _Checklist(),
              ],
            ],
            secondary: [
              if (hasKey) ...[
                Eyebrow(s.t('wallet')),
                const _Wallet(),
                const _PinnedAchievements(),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final name = '${ref.watch(accountProvider).valueOrNull?['name'] ?? ''}';
    // the handle without the four digit suffix
    final short = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    final hour = DateTime.now().hour;
    final key = hour < 12
        ? 'good_morning'
        : hour < 18
            ? 'good_afternoon'
            : 'good_evening';
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        short.isEmpty ? s.t('welcome') : s.t(key, {'name': short}),
        style: TextStyle(fontSize: 16, color: AppColors.textSoft),
      ),
    );
  }
}

/// the two clocks everyone plans around
class _Resets extends ConsumerWidget {
  const _Resets();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return ClockBuilder(
      step: ClockStep.second,
      builder: (context, now) {
        Widget half(String label, DateTime next, double progress, Color color, AppSection target) => Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.frame),
                onTap: () => ref.read(sectionProvider.notifier).state = target,
                child: Row(
                  children: [
                    Ring(value: progress, size: 46, stroke: 5, colors: [color, color]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          const SizedBox(height: 2),
                          Text(
                            countdown(next.difference(now)),
                            style: display(18).copyWith(fontFeatures: _tabular),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
        return GlowCard(
          glow: AppColors.gold,
          child: Row(
            children: [
              half(s.t('daily_reset'), nextDailyReset(now), dayProgress(now), AppColors.gold, AppSection.daily),
              Container(
                  width: 1, height: 40, color: AppColors.line, margin: const EdgeInsets.symmetric(horizontal: 12)),
              half(s.t('weekly_reset'), nextWeeklyReset(now), weekProgress(now), AppColors.blue, AppSection.weekly),
            ],
          ),
        );
      },
    );
  }
}

/// what can still be joined: fresh runs and upcoming ones, not the ones
/// already looted today
class _UpNext extends ConsumerWidget {
  const _UpNext();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // providers are watched here, outside the clock: its ticks rebuild only
    // the clock, where the consumer's ref may not watch anything new
    final looted = ref.watch(doneTodayProvider('worldbosses')).valueOrNull ?? const <String>{};
    return ClockBuilder(
      step: ClockStep.minute,
      builder: (context, now) {
        final next = upNext(
          now,
          count: 5,
          where: (o) => !lootedRun(o, looted, now) && now.difference(o.start) < const Duration(minutes: 10),
        );
        return Panel(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [for (final o in next) MetaRow(occurrence: o, looted: false)]),
        );
      },
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
