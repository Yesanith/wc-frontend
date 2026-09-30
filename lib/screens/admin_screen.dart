import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/admin.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/meters.dart';
import '../widgets/responsive.dart';

/// the state of the backend for whoever runs it: how many players, guilds and servers, whether the queues
/// empty and the nightly jobs ran. the database gives these to an administrator only
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(adminDashboardProvider);
    await ref.read(adminDashboardProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminDashboardProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncView<AdminDashboard>(
        value: ref.watch(adminDashboardProvider),
        onRetry: () => ref.invalidate(adminDashboardProvider),
        builder: (d) => ContentFrame(
          child: RefreshIndicator(
            color: AppColors.gold,
            onRefresh: () => _refresh(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  d.generatedAt == null ? '' : 'Updated ${ago(d.generatedAt!, DateTime.now())}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                SplitColumns(
                  primary: [
                    const Eyebrow('Overview'),
                    _Overview(d),
                    const Eyebrow('New players'),
                    _Signups(d.signups),
                    const Eyebrow('Health'),
                    _Health(d.health(DateTime.now())),
                  ],
                  secondary: [
                    const Eyebrow('Discord servers'),
                    _Servers(d.rows('discord', 'servers_list')),
                    const Eyebrow('Database'),
                    _Database(d),
                  ],
                ),
              ],
            ),
          ),
        ),
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
    return GridView(
      gridDelegate: const AdaptiveGridDelegate(
        minColumns: 2,
        maxTile: 230,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 104,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _Stat('Players', fmtInt(d.count('users', 'total')), '+${d.count('users', 'new_7d')} this week'),
        _Stat('Active today', fmtInt(d.count('users', 'active_24h')), '${d.count('users', 'active_7d')} in 7 days'),
        _Stat('Game accounts', fmtInt(d.count('accounts', 'gw2_accounts')),
            '${d.count('accounts', 'users_with_account')} players linked one'),
        _Stat('Guilds', fmtInt(d.count('accounts', 'guilds')),
            '${d.count('accounts', 'guilds_read_by_leader')} read by a leader'),
        _Stat('Discord servers', fmtInt(d.count('discord', 'servers')),
            '${d.count('discord', 'following_ranks')} follow the ranks'),
        _Stat('Devices', fmtInt(d.count('push', 'devices')), languages.isEmpty ? 'with notifications' : languages),
        _Stat('Events to come', fmtInt(d.count('events', 'upcoming')),
            '${d.count('events', 'going_upcoming')} going · ${d.count('events', 'weekly_series')} weekly'),
        _Stat(
            'Database', formatBytes(d.count('database', 'size_bytes')), '${d.count('events', 'reports')} reports kept'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.note);

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.hint)),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.gold)),
          Text(note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _Signups extends StatelessWidget {
  const _Signups(this.days);

  final List<({String day, int count})> days;

  @override
  Widget build(BuildContext context) {
    final values = [for (final d in days) d.count];
    final total = values.fold<int>(0, (a, b) => a + b);
    final peak = values.isEmpty ? 0 : values.reduce(math.max);
    String short(String day) => day.length >= 10 ? day.substring(5) : day;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$total in the last 30 days', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(painter: _BarsPainter(values)),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(days.isEmpty ? '' : short(days.first.day),
                  style: const TextStyle(fontSize: 11, color: AppColors.hint)),
              Text('most in a day: $peak', style: const TextStyle(fontSize: 11, color: AppColors.hint)),
              Text(days.isEmpty ? '' : short(days.last.day),
                  style: const TextStyle(fontSize: 11, color: AppColors.hint)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final top = values.reduce(math.max);
    final slot = size.width / values.length;
    final full = Paint()..color = AppColors.gold;
    final none = Paint()..color = AppColors.track;
    for (var i = 0; i < values.length; i++) {
      final h = top == 0 ? 0.0 : size.height * values[i] / top;
      final bar = math.max(h, 2.0);
      final rect = Rect.fromLTWH(i * slot + slot * 0.15, size.height - bar, slot * 0.7, bar);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), values[i] == 0 ? none : full);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) => oldDelegate.values != values;
}

class _Health extends StatelessWidget {
  const _Health(this.lines);

  final List<HealthLine> lines;

  Color _color(HealthLevel level) => switch (level) {
        HealthLevel.good => AppColors.green,
        HealthLevel.warn => AppColors.amber,
        HealthLevel.bad => AppColors.red,
      };

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: _color(line.level), shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(line.detail, style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
          Row(
            children: [
              const Expanded(child: Text('Size', style: TextStyle(fontWeight: FontWeight.w700))),
              Text(formatBytes(d.count('database', 'size_bytes')), style: const TextStyle(color: AppColors.gold)),
            ],
          ),
          const Divider(height: 20, color: AppColors.line),
          for (final t in tables)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                      child: Text('${t['name']}', style: const TextStyle(fontSize: 13, color: AppColors.textSoft))),
                  Text(fmtInt(asInt(t['rows'])), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
