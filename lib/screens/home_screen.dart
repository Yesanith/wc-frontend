import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/metas.dart';
import '../services/icon_cache.dart';
import '../state/account.dart';
import '../state/alerts.dart';
import '../state/clock.dart';
import '../state/navigation.dart';
import '../state/periodic.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import '../widgets/meters.dart';
import '../widgets/pin_button.dart';
import '../state/news.dart';
import 'events_screen.dart';

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
          Eyebrow(s.t('wizards_vault')),
          const _Vault(),
          Eyebrow(
            s.t('up_next'),
            trailing: TextButton(
              onPressed: () => ref.read(sectionProvider.notifier).state = AppSection.bosses,
              child: Text(s.t('all_timers')),
            ),
          ),
          const _UpNext(),
          Eyebrow(s.t('daily_checklist')),
          const _Checklist(),
          Eyebrow(s.t('wallet')),
          const _Wallet(),
          const _PinnedAchievements(),
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
        style: const TextStyle(fontSize: 16, color: AppColors.textSoft),
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
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now().toUtc();
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
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
          Container(width: 1, height: 40, color: AppColors.line, margin: const EdgeInsets.symmetric(horizontal: 12)),
          half(s.t('weekly_reset'), nextWeeklyReset(now), weekProgress(now), AppColors.blue, AppSection.weekly),
        ],
      ),
    );
  }
}

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
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.gold.withValues(alpha: 0.18),
                selectedForegroundColor: AppColors.text,
                foregroundColor: AppColors.muted,
                side: const BorderSide(color: AppColors.line),
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
                            Text(s.t('objectives_done', {'a': finished, 'b': objectives.length}),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(s.t('acclaim_left', {'n': fmtInt(left)}),
                                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontFeatures: _tabular)),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text('${asInt(o['acclaim'])}',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
          ),
        ],
      ),
    );
  }
}

/// what can still be joined: fresh runs and upcoming ones, not the ones
/// already looted today
class _UpNext extends ConsumerWidget {
  const _UpNext();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now =
        ref.watch(clockProvider.select((t) => t.valueOrNull?.copyWith(second: 0, millisecond: 0, microsecond: 0))) ??
            DateTime.now().toUtc();
    final looted = ref.watch(doneTodayProvider('worldbosses')).valueOrNull ?? const <String>{};
    final next = upNext(
      now,
      count: 5,
      where: (o) => !lootedRun(o, looted, now) && now.difference(o.start) < const Duration(minutes: 10),
    );
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: [for (final o in next) MetaRow(occurrence: o, looted: false)]),
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
                ? const Icon(Icons.lock_outline, size: 16, color: AppColors.hint)
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

class _Wallet extends ConsumerWidget {
  const _Wallet();

  /// karma, laurels, gems, astral acclaim and spirit shards
  static const _highlights = [2, 3, 4, 63, 23];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<List<WalletEntry>>(
      value: ref.watch(walletProvider),
      onRetry: () => ref.invalidate(walletProvider),
      builder: (w) {
        final byId = {for (final e in w) e.id: e};
        return Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.card),
              onTap: () => ref.read(sectionProvider.notifier).state = AppSection.account,
              child: GlowCard(
                glow: AppColors.amber,
                child: Row(
                  children: [
                    Expanded(child: CoinDots(byId[1]?.value ?? 0, size: 22, weight: FontWeight.w800)),
                    if (byId[1] != null)
                      Text(byId[1]!.name, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.25,
              children: [
                for (final id in _highlights)
                  if (byId[id] != null) _CurrencyTile(byId[id]!),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile(this.entry);

  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final icon = entry.icon;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox.square(dimension: 22, child: icon == null ? null : CachedIcon(url: icon)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(compact(entry.value),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFeatures: _tabular)),
              Text(entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// shows up only while at least one price alert is met
class _AlertBanner extends ConsumerWidget {
  const _AlertBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final fired = ref.watch(triggeredAlertsProvider).valueOrNull ?? const <int>{};
    if (fired.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        onTap: () => ref.read(sectionProvider.notifier).state = AppSection.trading,
        child: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppColors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.t('alerts_fired', {'n': fired.length}),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.chevron),
          ],
        ),
      ),
    );
  }
}

/// the achievements the player pinned, with how far along each one is.
/// nothing at all until something is pinned
class _PinnedAchievements extends ConsumerWidget {
  const _PinnedAchievements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    if (ref.watch(pinnedAchievementsProvider).isEmpty) return const SizedBox.shrink();
    final rows = ref.watch(pinnedAchievementRowsProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: s.t('pinned_achievements'), trailing: '${ref.watch(pinnedAchievementsProvider).length}'),
          const SizedBox(height: 10),
          AsyncView<List<AchievementRow>>(
            value: rows,
            onRetry: () => ref.invalidate(pinnedAchievementRowsProvider),
            builder: (list) => Panel(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Column(
                children: [
                  for (final a in list)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (a.done) ...[
                                      const Icon(Icons.check_circle, size: 16, color: AppColors.green),
                                      const SizedBox(width: 6),
                                    ],
                                    Expanded(
                                      child: Text(a.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                    ),
                                    if (a.max > 0)
                                      Text('${fmtInt(a.current)} / ${fmtInt(a.max)}',
                                          style: const TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
                                  ],
                                ),
                                if (a.max > 0) ...[
                                  const SizedBox(height: 7),
                                  Bar(value: a.done ? 1 : a.ratio, color: a.done ? AppColors.green : AppColors.gold),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          AchievementPinButton(id: a.id),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// "new articles" while the feed has something the user has not seen yet
class _NewsBanner extends ConsumerWidget {
  const _NewsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    // the first time the feed loads, what is there counts as seen
    ref.listen<AsyncValue<List<NewsItem>>>(newsProvider, (_, next) {
      final items = next.valueOrNull;
      final newest = items == null || items.isEmpty ? null : items.first.date;
      if (newest != null && ref.read(newsSeenProvider) == null) {
        ref.read(newsSeenProvider.notifier).markSeen(newest);
      }
    });
    final count = ref.watch(unseenNewsProvider);
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => ref.read(sectionProvider.notifier).state = AppSection.news,
        child: Row(
          children: [
            const Icon(Icons.newspaper, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(s.t('news_new', {'n': count}), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.chevron),
          ],
        ),
      ),
    );
  }
}
