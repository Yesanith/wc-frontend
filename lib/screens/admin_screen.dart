import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/admin.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/meters.dart';
import '../widgets/responsive.dart';

/// the state of the backend for whoever runs it. the database gives these numbers to an administrator only
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Backend'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(adminDashboardProvider);
                ref.invalidate(adminServerProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: const Column(
          children: [
            AppTabBar(scrollable: true, labels: ['Overview', 'Server', 'Activity', 'Users and limits']),
            Expanded(
              child: TabBarView(children: [_OverviewTab(), _ServerTab(), _ActivityTab(), _UsersTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// a tab of numbers: pull to refresh, a width it can be read in, and the parts in two columns where there is room
class _Tab extends StatelessWidget {
  const _Tab({required this.updated, required this.onRefresh, required this.primary, this.secondary = const []});

  final DateTime? updated;
  final Future<void> Function() onRefresh;
  final List<Widget> primary;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    return ContentFrame(
      child: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              updated == null ? '' : 'Updated ${ago(updated!, DateTime.now())}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            SplitColumns(primary: primary, secondary: secondary),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ overview

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<AdminDashboard>(
      value: ref.watch(adminDashboardProvider),
      onRetry: () => ref.invalidate(adminDashboardProvider),
      builder: (d) => _Tab(
        updated: d.generatedAt,
        onRefresh: () async {
          ref.invalidate(adminDashboardProvider);
          await ref.read(adminDashboardProvider.future);
        },
        primary: [
          const Eyebrow('Overview'),
          _Overview(d),
          const Eyebrow('New players'),
          _Bars(title: 'New players', days: d.signups),
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
    return _StatGrid(children: [
      _Stat('Players', fmtInt(d.count('users', 'total')), '+${d.count('users', 'new_7d')} this week'),
      _Stat('Active today', fmtInt(d.count('users', 'active_24h')), '${d.count('users', 'active_7d')} in 7 days'),
      _Stat('Game accounts', fmtInt(d.count('accounts', 'gw2_accounts')),
          '${d.count('accounts', 'users_with_account')} players linked one'),
      _Stat('Guilds', fmtInt(d.count('accounts', 'guilds')), '${d.count('accounts', 'guilds_read_by_leader')} read by a leader'),
      _Stat('Discord servers', fmtInt(d.count('discord', 'servers')), '${d.count('discord', 'following_ranks')} follow the ranks'),
      _Stat('Devices', fmtInt(d.count('push', 'devices')), languages.isEmpty ? 'with notifications' : languages),
      _Stat('Events to come', fmtInt(d.count('events', 'upcoming')),
          '${d.count('events', 'going_upcoming')} going · ${d.count('events', 'weekly_series')} weekly'),
      _Stat('Database', formatBytes(d.count('database', 'size_bytes')), '${d.count('events', 'reports')} reports kept'),
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
          _Line('Size', formatBytes(d.count('database', 'size_bytes')), valueColor: AppColors.gold, bold: true),
          const Divider(height: 20, color: AppColors.line),
          for (final t in tables) _Line('${t['name']}', fmtInt(asInt(t['rows']))),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ server

class _ServerTab extends ConsumerWidget {
  const _ServerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<AdminServer>(
      value: ref.watch(adminServerProvider),
      onRetry: () => ref.invalidate(adminServerProvider),
      builder: (s) {
        final now = DateTime.now();
        final started = s.at('server', 'started_at');
        final conn = s.map('server', 'connections');
        final hit = s.cacheHitPercent;
        final size = s.count('server', 'size_bytes');
        return _Tab(
          updated: s.generatedAt,
          onRefresh: () async {
            ref.invalidate(adminServerProvider);
            await ref.read(adminServerProvider.future);
          },
          primary: [
            const Eyebrow('Server'),
            _StatGrid(children: [
              _Stat('Up for', started == null ? '?' : uptime(started, now), started == null ? '' : 'since ${_day(started)}'),
              _Stat('Connections', '${asInt(conn['total'])}', 'of ${s.count('server', 'max_connections')}, ${asInt(conn['active'])} active'),
              _Stat('Cache', hit == null ? '?' : '${hit.toStringAsFixed(1)}%', 'reads from memory'),
              _Stat('Size', formatBytes(size), '${(100 * size / freeDatabaseBytes).toStringAsFixed(0)}% of the free plan'),
              _Stat('Commits', compact(s.count('server', 'commits')), '${compact(s.count('server', 'rollbacks'))} rolled back'),
              _Stat('Temp files', compact(s.count('server', 'temp_files')), formatBytes(s.count('server', 'temp_bytes'))),
            ]),
            if ('${s.section('server')['version'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text('${s.section('server')['version']}'.split(' on ').first,
                    style: const TextStyle(fontSize: 11, color: AppColors.hint)),
              ),
            const Eyebrow('Health'),
            _Health(s.health(now)),
            const Eyebrow('Slowest queries'),
            _Queries(s.list('slow'), problem: s.problem('slow'), empty: 'Nothing is counted (the extension that counts queries is not on).', slow: true),
            const Eyebrow('Running now'),
            _Queries(s.list('running'), problem: s.problem('running'), empty: 'Nothing has run for more than 5 seconds.', slow: false),
          ],
          secondary: [
            const Eyebrow('Tables'),
            _Tables(s.list('tables'), problem: s.problem('tables')),
            const Eyebrow('Scheduled jobs'),
            _Jobs(s.list('cron_history'), problem: s.problem('cron_history')),
          ],
        );
      },
    );
  }
}

String _day(DateTime t) => '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}';

class _Tables extends StatelessWidget {
  const _Tables(this.tables, {this.problem});

  final List<Map<String, dynamic>> tables;
  final String? problem;

  @override
  Widget build(BuildContext context) {
    if (problem != null) return Panel(child: Text(problem!, style: const TextStyle(color: AppColors.amber)));
    final total = tables.fold<int>(0, (a, t) => a + asInt(t['total_bytes']));
    return Panel(
      child: Column(
        children: [
          _Line('${tables.length} tables', formatBytes(total), valueColor: AppColors.gold, bold: true),
          const Divider(height: 20, color: AppColors.line),
          for (final t in tables)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text('${t['name']}', style: const TextStyle(fontSize: 13, color: AppColors.textSoft))),
                  SizedBox(
                    width: 70,
                    child: Text(fmtInt(asInt(t['rows'])), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ),
                  SizedBox(
                    width: 76,
                    child: Text(formatBytes(asInt(t['total_bytes'])),
                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          const Text('rows · size with its indexes', style: TextStyle(fontSize: 11, color: AppColors.hint)),
        ],
      ),
    );
  }
}

class _Queries extends StatelessWidget {
  const _Queries(this.queries, {required this.problem, required this.empty, required this.slow});

  final List<Map<String, dynamic>> queries;
  final String? problem;
  final String empty;
  final bool slow;

  @override
  Widget build(BuildContext context) {
    if (problem != null) return Panel(child: Text(problem!, style: const TextStyle(color: AppColors.amber)));
    if (queries.isEmpty) return Panel(child: Text(empty, style: const TextStyle(color: AppColors.muted)));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final q in queries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slow
                        ? '${fmtInt(asInt(q['calls']))} calls · ${fmtInt(asInt(q['total_ms']))} ms in all · ${q['mean_ms']} ms each · at most ${fmtInt(asInt(q['max_ms']))} ms'
                        : '${q['state']} for ${q['seconds']} s${q['wait'] == null ? '' : ' · waiting on ${q['wait']}'}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold),
                  ),
                  const SizedBox(height: 2),
                  Text('${q['query']}', maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.35, fontFamily: 'monospace')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Jobs extends StatelessWidget {
  const _Jobs(this.runs, {this.problem});

  final List<Map<String, dynamic>> runs;
  final String? problem;

  @override
  Widget build(BuildContext context) {
    if (problem != null) return Panel(child: Text(problem!, style: const TextStyle(color: AppColors.amber)));
    if (runs.isEmpty) {
      return const Panel(child: Text('The scheduler keeps no log here.', style: TextStyle(color: AppColors.muted)));
    }
    final now = DateTime.now();
    return Panel(
      child: Column(
        children: [
          for (final r in runs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  _Dot(r['status'] == 'succeeded' ? HealthLevel.good : (r['status'] == 'failed' ? HealthLevel.bad : HealthLevel.warn)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${r['job']}', style: const TextStyle(fontSize: 13))),
                  Text(
                    '${DateTime.tryParse('${r['started_at'] ?? ''}') == null ? '' : ago(DateTime.parse('${r['started_at']}'), now)} · ${r['seconds'] ?? '?'} s',
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

// ------------------------------------------------------------------ activity

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<AdminServer>(
      value: ref.watch(adminServerProvider),
      onRetry: () => ref.invalidate(adminServerProvider),
      builder: (s) {
        final now = DateTime.now();
        final problem = s.problem('activity');
        const labels = {
          'event_created': 'Last event created',
          'signup': 'Last sign up for an event',
          'reminder_sent': 'Last Discord reminder',
          'roles_synced': 'Last Discord role sync',
          'guild_read': 'Last guild read by a leader',
          'player_active': 'Last player seen',
          'device_registered': 'Last device registered',
          'report_added': 'Last report added',
          'server_connected': 'Last server connected',
        };
        final feeds = s.section('feeds');
        final errors = [for (final e in (feeds['errors'] is List ? feeds['errors'] as List : const [])) if (e is Map) Map<String, dynamic>.from(e)];
        return _Tab(
          updated: s.generatedAt,
          onRefresh: () async {
            ref.invalidate(adminServerProvider);
            await ref.read(adminServerProvider.future);
          },
          primary: [
            const Eyebrow('Last 30 days'),
            if (problem != null)
              Panel(child: Text(problem, style: const TextStyle(color: AppColors.amber)))
            else ...[
              _Bars(title: 'Events created', days: s.series('events')),
              const SizedBox(height: 10),
              _Bars(title: 'Sign ups for events', days: s.series('signups')),
              const SizedBox(height: 10),
              _Bars(title: 'Discord reminders sent', days: s.series('reminders')),
              const SizedBox(height: 10),
              _Bars(title: 'Reports added', days: s.series('reports')),
              const SizedBox(height: 10),
              _Bars(title: 'Players by the day they last signed in', days: s.series('sign_ins')),
            ],
          ],
          secondary: [
            const Eyebrow('When each part last did something'),
            Panel(
              child: Column(
                children: [
                  for (final e in labels.entries)
                    _Line(e.value, s.at('latest', e.key) == null ? 'never' : ago(s.at('latest', e.key)!, now)),
                ],
              ),
            ),
            const Eyebrow('Queues and what the bot keeps'),
            Panel(
              child: Column(
                children: [
                  _Line('Message deletions waiting', '${s.count('queues', 'deletions_waiting')}'),
                  _Line('Event drafts open', '${s.count('queues', 'drafts')}'),
                  _Line('Events posted in Discord', '${s.count('queues', 'posted_events')}'),
                  _Line('Discord threads', '${s.count('queues', 'threads')}'),
                  _Line('Discord scheduled events', '${s.count('queues', 'scheduled_events')}'),
                  _Line('Role mappings', '${s.count('queues', 'role_mappings')}'),
                  _Line('Guild lists kept', '${s.count('queues', 'guild_parts')}'),
                ],
              ),
            ),
            const Eyebrow('News feeds'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Line('Feeds set up', '${s.count('feeds', 'total')}'),
                  _Line('Failing', '${s.count('feeds', 'with_error')}',
                      valueColor: s.count('feeds', 'with_error') > 0 ? AppColors.amber : null),
                  for (final e in errors)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${e['guild']} · ${e['kind']}: ${e['error']}',
                        style: const TextStyle(fontSize: 12, color: AppColors.amber, height: 1.35),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ users and limits

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<AdminServer>(
      value: ref.watch(adminServerProvider),
      onRetry: () => ref.invalidate(adminServerProvider),
      builder: (s) {
        final size = s.count('server', 'size_bytes');
        final monthly = s.count('auth', 'signed_in_30d');
        final providers = s.map('auth', 'by_provider');
        return _Tab(
          updated: s.generatedAt,
          onRefresh: () async {
            ref.invalidate(adminServerProvider);
            await ref.read(adminServerProvider.future);
          },
          primary: [
            const Eyebrow('The free plan'),
            _LimitBar('Database', size, freeDatabaseBytes, formatBytes(size), formatBytes(freeDatabaseBytes)),
            const SizedBox(height: 10),
            _LimitBar('Users who signed in this month', monthly, freeMonthlyUsers, fmtInt(monthly), fmtInt(freeMonthlyUsers)),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                'Traffic, file storage and function calls are counted by Supabase and shown on its dashboard, not in the database.',
                style: TextStyle(fontSize: 12, color: AppColors.hint, height: 1.4),
              ),
            ),
          ],
          secondary: [
            const Eyebrow('Sign in'),
            _StatGrid(children: [
              _Stat('Accounts', fmtInt(s.count('auth', 'users')), 'that can sign in'),
              _Stat('Today', fmtInt(s.count('auth', 'signed_in_24h')), 'signed in'),
              _Stat('This week', fmtInt(s.count('auth', 'signed_in_7d')), 'signed in'),
              _Stat('This month', fmtInt(monthly), 'signed in'),
            ]),
            const Eyebrow('By provider'),
            Panel(
              child: Column(
                children: [
                  if (providers.isEmpty) const Text('None.', style: TextStyle(color: AppColors.muted)),
                  for (final e in providers.entries) _Line(e.key, fmtInt(asInt(e.value))),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LimitBar extends StatelessWidget {
  const _LimitBar(this.label, this.used, this.limit, this.usedText, this.limitText);

  final String label;
  final int used;
  final int limit;
  final String usedText;
  final String limitText;

  @override
  Widget build(BuildContext context) {
    final fraction = limit == 0 ? 0.0 : used / limit;
    final color = switch (levelOfUse(fraction)) {
      HealthLevel.good => AppColors.green,
      HealthLevel.warn => AppColors.amber,
      HealthLevel.bad => AppColors.red,
    };
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('$usedText of $limitText', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.track,
            ),
          ),
          const SizedBox(height: 6),
          Text('${(fraction * 100).toStringAsFixed(fraction < 0.1 ? 1 : 0)} percent', style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ parts they share

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
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
      children: children,
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
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.hint)),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.gold)),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.valueColor, this.bold = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: bold ? AppColors.text : AppColors.textSoft)),
          ),
          Text(value, style: TextStyle(fontSize: 13, color: valueColor ?? AppColors.muted)),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.level);

  final HealthLevel level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      HealthLevel.good => AppColors.green,
      HealthLevel.warn => AppColors.amber,
      HealthLevel.bad => AppColors.red,
    };
    return Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _Health extends StatelessWidget {
  const _Health(this.lines);

  final List<HealthLine> lines;

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
                  Padding(padding: const EdgeInsets.only(top: 5), child: _Dot(line.level)),
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

class _Bars extends StatelessWidget {
  const _Bars({required this.title, required this.days});

  final String title;
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
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('$total in 30 days', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(height: 70, width: double.infinity, child: CustomPaint(painter: _BarsPainter(values))),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(days.isEmpty ? '' : short(days.first.day), style: const TextStyle(fontSize: 11, color: AppColors.hint)),
              Text('most in a day: $peak', style: const TextStyle(fontSize: 11, color: AppColors.hint)),
              Text(days.isEmpty ? '' : short(days.last.day), style: const TextStyle(fontSize: 11, color: AppColors.hint)),
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
