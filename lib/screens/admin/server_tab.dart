import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/common.dart';
import '../../widgets/meters.dart';
import 'widgets.dart';

class AdminServerTab extends ConsumerWidget {
  const AdminServerTab({super.key});

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
        return AdminTab(
          updated: s.generatedAt,
          onRefresh: () async {
            ref.invalidate(adminServerProvider);
            await ref.read(adminServerProvider.future);
          },
          primary: [
            const Eyebrow('Server'),
            AdminStatGrid(children: [
              AdminStat('Up for', started == null ? '?' : uptime(started, now),
                  started == null ? '' : 'since ${_day(started)}'),
              AdminStat('Connections', '${asInt(conn['total'])}',
                  'of ${s.count('server', 'max_connections')}, ${asInt(conn['active'])} active'),
              AdminStat('Cache', hit == null ? '?' : '${hit.toStringAsFixed(1)}%', 'reads from memory'),
              AdminStat('Size', formatBytes(size),
                  '${(100 * size / freeDatabaseBytes).toStringAsFixed(0)}% of the free plan'),
              AdminStat('Commits', compact(s.count('server', 'commits')),
                  '${compact(s.count('server', 'rollbacks'))} rolled back'),
              AdminStat(
                  'Temp files', compact(s.count('server', 'temp_files')), formatBytes(s.count('server', 'temp_bytes'))),
            ]),
            if ('${s.section('server')['version'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text('${s.section('server')['version']}'.split(' on ').first,
                    style: const TextStyle(fontSize: 11, color: AppColors.hint)),
              ),
            const Eyebrow('Health'),
            AdminHealth(s.health(now)),
            const Eyebrow('Slowest queries'),
            _Queries(s.list('slow'),
                problem: s.problem('slow'),
                empty: 'Nothing is counted (the extension that counts queries is not on).',
                slow: true),
            const Eyebrow('Running now'),
            _Queries(s.list('running'),
                problem: s.problem('running'), empty: 'Nothing has run for more than 5 seconds.', slow: false),
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
          AdminLine('${tables.length} tables', formatBytes(total), valueColor: AppColors.gold, bold: true),
          const Divider(height: 20, color: AppColors.line),
          for (final t in tables)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                      child: Text('${t['name']}', style: const TextStyle(fontSize: 13, color: AppColors.textSoft))),
                  SizedBox(
                    width: 70,
                    child: Text(fmtInt(asInt(t['rows'])),
                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
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
                  Text('${q['query']}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted, height: 1.35, fontFamily: 'monospace')),
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
                  AdminDot(r['status'] == 'succeeded'
                      ? HealthLevel.good
                      : (r['status'] == 'failed' ? HealthLevel.bad : HealthLevel.warn)),
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
