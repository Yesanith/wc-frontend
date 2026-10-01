import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/common.dart';
import '../../widgets/meters.dart';
import 'widgets.dart';

class AdminOverviewTab extends ConsumerWidget {
  const AdminOverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<AdminDashboard>(
      value: ref.watch(adminDashboardProvider),
      onRetry: () => ref.invalidate(adminDashboardProvider),
      builder: (d) => AdminTab(
        updated: d.generatedAt,
        onRefresh: () async {
          ref.invalidate(adminDashboardProvider);
          await ref.read(adminDashboardProvider.future);
        },
        primary: [
          const Eyebrow('Overview'),
          _Overview(d),
          const Eyebrow('New players'),
          AdminBars(title: 'New players', days: d.signups),
          const Eyebrow('Health'),
          AdminHealth(d.health(DateTime.now())),
        ],
        secondary: [
          const Eyebrow('Discord servers'),
          _Servers(d.rows('discord', 'servers_list')),
          const Eyebrow('Database'),
          _Database(d),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview(this.d);

  final AdminDashboard d;

  @override
  Widget build(BuildContext context) {
    final byLanguage = d.section('push')['by_language'];
    final languages = byLanguage is Map ? byLanguage.entries.map((e) => '${e.key} ${e.value}').join(' · ') : '';
    return AdminStatGrid(children: [
      AdminStat('Players', fmtInt(d.count('users', 'total')), '+${d.count('users', 'new_7d')} this week'),
      AdminStat('Active today', fmtInt(d.count('users', 'active_24h')), '${d.count('users', 'active_7d')} in 7 days'),
      AdminStat('Game accounts', fmtInt(d.count('accounts', 'gw2_accounts')),
          '${d.count('accounts', 'users_with_account')} players linked one'),
      AdminStat('Guilds', fmtInt(d.count('accounts', 'guilds')),
          '${d.count('accounts', 'guilds_read_by_leader')} read by a leader'),
      AdminStat('Discord servers', fmtInt(d.count('discord', 'servers')),
          '${d.count('discord', 'following_ranks')} follow the ranks'),
      AdminStat('Devices', fmtInt(d.count('push', 'devices')), languages.isEmpty ? 'with notifications' : languages),
      AdminStat('Events to come', fmtInt(d.count('events', 'upcoming')),
          '${d.count('events', 'going_upcoming')} going · ${d.count('events', 'weekly_series')} weekly'),
      AdminStat('Database', formatBytes(d.count('database', 'size_bytes')), '${d.count('events', 'reports')} reports kept'),
    ]);
  }
}

class _Servers extends StatelessWidget {
  const _Servers(this.servers);

  final List<Map<String, dynamic>> servers;

  @override
  Widget build(BuildContext context) {
    if (servers.isEmpty) {
      return const Panel(child: Text('No server is connected.', style: TextStyle(color: AppColors.muted)));
    }
    final now = DateTime.now();
    return Panel(
      child: Column(
        children: [
          for (final s in servers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s['name']}${'${s['tag'] ?? ''}'.isEmpty ? '' : ' [${s['tag']}]'}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          [
                            '${s['language'] ?? 'en'}',
                            if (s['follow_ranks'] == true) 'follows ranks',
                            if (s['use_threads'] == true) 'threads',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateTime.tryParse('${s['roles_synced_at'] ?? ''}') == null
                        ? 'roles: never'
                        : 'roles ${ago(DateTime.parse('${s['roles_synced_at']}'), now)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.hint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Database extends StatelessWidget {
  const _Database(this.d);

  final AdminDashboard d;

  @override
  Widget build(BuildContext context) {
    final tables = d.rows('database', 'tables');
    return Panel(
      child: Column(
        children: [
          AdminLine('Size', formatBytes(d.count('database', 'size_bytes')), valueColor: AppColors.gold, bold: true),
          const Divider(height: 20, color: AppColors.line),
          for (final t in tables) AdminLine('${t['name']}', fmtInt(asInt(t['rows']))),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ server
