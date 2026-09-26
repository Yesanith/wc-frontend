import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/world_bosses.dart';
import '../state/account.dart';
import '../state/navigation.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../state/periodic.dart';
import '../state/alerts.dart';
import 'events_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) => refreshProviders(ref, [
        triggeredAlertsProvider,
        accountProvider,
        walletProvider,
        vaultTrackProvider,
      ]);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final wallet = ref.watch(walletProvider);

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => _refresh(ref),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          AsyncView<Json>(
            value: account,
            onRetry: () => ref.invalidate(accountProvider),
            builder: (a) => _AccountHeader(a),
          ),
          const SizedBox(height: 14),
          AsyncView<List<WalletEntry>>(
            value: wallet,
            onRetry: () => ref.invalidate(walletProvider),
            builder: (w) => _WalletStrip(w),
          ),
          const SizedBox(height: 14),
          const _QuickLinks(),
          const SizedBox(height: 24),
          const _AlertBanner(),
          const _PeriodicLinks(),
        ],
      ),
    );
  }
}

/// daily and weekly at a glance, each opens its own section
class _PeriodicLinks extends ConsumerWidget {
  const _PeriodicLinks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    String meta(String track) {
      final v = ref.watch(vaultTrackProvider(track)).valueOrNull;
      return v == null ? '…' : '${v['meta_progress_current'] ?? 0}/${v['meta_progress_complete'] ?? 0}';
    }

    Widget card(String title, String value, String reset, AppSection target, IconData icon) => Expanded(
          child: AppCard(
            onTap: () => ref.read(sectionProvider.notifier).state = target,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gold)),
                Text(reset, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
        );

    return Row(
      children: [
        card(s.t('daily'), meta('daily'), timeUntil(nextDailyReset()), AppSection.daily, Icons.today),
        const SizedBox(width: 10),
        card(s.t('weekly'), meta('weekly'), timeUntil(nextWeeklyReset()), AppSection.weekly, Icons.date_range),
      ],
    );
  }
}

class _AccountHeader extends ConsumerWidget {
  const _AccountHeader(this.a);

  final Json a;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final wvw = a['wvw'];
    final rank = wvw is Map ? asInt(wvw['rank']) : asInt(a['wvw_rank']);
    final created = '${a['created'] ?? ''}';
    final year = created.length >= 4 ? created.substring(0, 4) : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.t('welcome'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
        Text('${a['name'] ?? ''}', style: display(26)),
        const SizedBox(height: 14),
        Panel(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: StatTile(label: s.t('playtime'), value: fmtHours(a['age'], s.t('hours_short')))),
                  Expanded(child: StatTile(label: s.t('wvw_rank'), value: rank > 0 ? fmtInt(rank) : '-')),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: StatTile(label: s.t('fractal_level'), value: '${asInt(a['fractal_level'])}')),
                  Expanded(child: StatTile(label: s.t('account_created'), value: year)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalletStrip extends ConsumerWidget {
  const _WalletStrip(this.entries);

  final List<WalletEntry> entries;

  int _value(int id) {
    for (final e in entries) {
      if (e.id == id) return e.value;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    // wallet ids: 1 coin, 2 karma, 3 laurel
    final coins = Coins(_value(1));
    return Row(
      children: [
        Expanded(
          child: _MiniCard(
            dot: AppColors.gold,
            label: s.t('gold'),
            value: '${fmtInt(coins.gold)} g',
            sub: '${coins.silver} s ${coins.copper} c',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniCard(dot: const Color(0xFFD58CF0), label: s.t('karma'), value: compact(_value(2))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniCard(dot: AppColors.green, label: s.t('laurels'), value: fmtInt(_value(3))),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.dot, required this.label, required this.value, this.sub});

  final Color dot;
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final s = sub;
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          if (s != null) Text(s, style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
        ],
      ),
    );
  }
}

class _QuickLinks extends ConsumerWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final watch = ref.watch(watchlistProvider);
    final now = DateTime.now().toUtc();
    final spawns = upcomingSpawns(now, ahead: const Duration(hours: 3));
    final next = spawns.isEmpty ? null : spawns.first;

    void open(AppSection section) => ref.read(sectionProvider.notifier).state = section;

    return Column(
      children: [
        _LinkTile(
          icon: Icons.schedule,
          title: s.t('world_bosses'),
          subtitle: next == null
              ? '-'
              : next.isActive(now)
                  ? '${next.boss.name} · ${s.t('active_now')}'
                  : '${next.boss.name} · ${untilText(s, next.start, now)}',
          onTap: () => open(AppSection.bosses),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _LinkTile(
                icon: Icons.storefront_outlined,
                title: s.t('watchlist'),
                subtitle: s.t('n_items', {'n': watch.length}),
                onTap: () => open(AppSection.trading),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: 16,
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.chevron),
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
      padding: const EdgeInsets.only(bottom: 12),
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
