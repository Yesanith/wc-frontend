import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/world_bosses.dart';
import '../state/account.dart';
import '../state/navigation.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'events_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) => refreshProviders(ref, [
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
          const _VaultSection(),
        ],
      ),
    );
  }
}

/// the vault has three tracks that reset on different schedules
class _VaultSection extends ConsumerStatefulWidget {
  const _VaultSection();

  @override
  ConsumerState<_VaultSection> createState() => _VaultSectionState();
}

class _VaultSectionState extends ConsumerState<_VaultSection> {
  static const _tracks = ['daily', 'weekly', 'special'];
  String _track = 'daily';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final data = ref.watch(vaultTrackProvider(_track));
    final v = data.valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: s.t('wizards_vault'),
          trailing: v == null
              ? null
              : '${asInt(v['meta_progress_current'])}/${asInt(v['meta_progress_complete'])}',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final track in _tracks) ...[
              ChoiceChip(
                label: Text(s.t('vault_$track')),
                selected: _track == track,
                onSelected: (_) => setState(() => _track = track),
              ),
              if (track != _tracks.last) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 10),
        AsyncView<Json>(
          value: data,
          onRetry: () => ref.invalidate(vaultTrackProvider(_track)),
          builder: (json) => _VaultList(json),
        ),
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
        Text(s.t('welcome'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
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
    final goals = ref.watch(goalsProvider);
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
                icon: Icons.flag_outlined,
                title: s.t('goals'),
                subtitle: s.t('n_goals', {'n': goals.length}),
                onTap: () => open(AppSection.goals),
              ),
            ),
            const SizedBox(width: 8),
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
              const Icon(Icons.chevron_right, color: Color(0xFF6E6859)),
            ],
          ),
           );
  }
}

class _VaultList extends ConsumerWidget {
  const _VaultList(this.data);

  final Json data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final objectives = ((data['objectives'] as List?) ?? const []).whereType<Map>().toList();
    if (objectives.isEmpty) {
      return Panel(child: Text(s.t('vault_empty'), style: const TextStyle(color: AppColors.muted)));
    }
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < objectives.length; i++)
            _VaultRow(Map<String, dynamic>.from(objectives[i]), last: i == objectives.length - 1),
        ],
      ),
    );
  }
}

class _VaultRow extends StatelessWidget {
  const _VaultRow(this.o, {required this.last});

  final Json o;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final cur = asInt(o['progress_current']);
    final total = asInt(o['progress_complete']);
    final done = total > 0 && cur >= total;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: last ? Colors.transparent : AppColors.track)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${o['title'] ?? ''}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: done ? AppColors.muted : AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('$cur/$total',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Bar(value: total == 0 ? 0 : cur / total, color: done ? AppColors.green : AppColors.gold),
        ],
      ),
    );
  }
}
