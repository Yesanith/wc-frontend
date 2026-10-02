import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../state/admin_system.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/common.dart';
import '../../widgets/meters.dart';
import 'widgets.dart';

/// everything the backend keeps in one place: what the sync functions answered, the scheduled jobs with when they run next, the trading post, the
/// official server in detail, the public events in numbers, and every table with its rows and its size
class AdminSystemTab extends ConsumerWidget {
  const AdminSystemTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<AdminSystem>(
      value: ref.watch(adminSystemProvider),
      onRetry: () => ref.invalidate(adminSystemProvider),
      builder: (sys) {
        final now = DateTime.now();
        // the jobs are the dashboard's: the schedule, when it ran last and how it went
        final cron = ref.watch(adminDashboardProvider).valueOrNull?.cron ?? const <Map<String, dynamic>>[];
        return AdminTab(
          updated: sys.generatedAt,
          onRefresh: () async {
            ref.invalidate(adminSystemProvider);
            ref.invalidate(adminDashboardProvider);
            await ref.read(adminSystemProvider.future);
          },
          primary: [
            const Eyebrow('Sync functions, last hour'),
            AdminHealth(sys.syncLines(now)),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'What each function answered to the call the database made to wake it. ${sys.syncCallsKept} calls are kept, for three hours.',
                style: const TextStyle(fontSize: 12, color: AppColors.hint),
              ),
            ),
            const Eyebrow('Trading post'),
            AdminHealth(sys.tradingLines(now)),
            if (sys.historyByDay.isNotEmpty) ...[
              const SizedBox(height: 10),
              AdminBars(title: 'Points of the history, by day', days: sys.historyByDay),
            ],
            if (sys.recentlyAsked.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Panel(title: 'Asked for last', rows: [
                for (final r in sys.recentlyAsked) ('Item ${r.itemId}', r.at == null ? '' : ago(r.at!, now)),
              ]),
            ],
            const Eyebrow('Official Discord server'),
            AdminHealth(sys.officialLines(now)),
            if (sys.officialConfigured) ...[
              const SizedBox(height: 10),
              _Panel(title: 'Kinds with a channel', rows: [
                ('Europe', sys.kinds('eu').isEmpty ? 'none' : sys.kinds('eu').join(', ')),
                ('North America', sys.kinds('na').isEmpty ? 'none' : sys.kinds('na').join(', ')),
              ]),
              if (sys.active.isNotEmpty) ...[
                const SizedBox(height: 10),
                _Panel(title: 'Events going on', rows: [
                  for (final a in sys.active)
                    (
                      '${a['title']} (${a['region']})',
                      '${a['voice'] == true ? 'text and voice' : 'text only'}, ${asInt(a['granted'])} let in',
                    ),
                ]),
              ],
              if (sys.outbox.isNotEmpty) ...[
                const SizedBox(height: 10),
                _Panel(title: 'Posts that wait', rows: [
                  for (final p in sys.outbox)
                    (
                      '${p['title']} (${p['region']})',
                      asInt(p['attempts']) == 0 ? 'waiting' : '${asInt(p['attempts'])} tries: ${p['last_error'] ?? 'no reason given'}',
                    ),
                ]),
              ],
            ],
          ],
          secondary: [
            const Eyebrow('Scheduled jobs'),
            cron.isEmpty
                ? const Panel(child: Text('The schedule could not be read.', style: TextStyle(color: AppColors.muted)))
                : AdminHealth(cronLines(cron, now)),
            const Eyebrow('Public events'),
            AdminHealth(sys.publicLines()),
            const SizedBox(height: 10),
            AdminBars(title: 'Events made, by day', days: sys.createdByDay),
            const SizedBox(height: 10),
            AdminBars(title: 'Signed up, by day', days: sys.signupsByDay),
            if (sys.byStatus.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Panel(title: 'By state', rows: [for (final e in sys.byStatus) (e.label, '${e.count}')]),
            ],
            if (sys.upcomingByRegion.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Panel(title: 'Still to come, by region', rows: [for (final e in sys.upcomingByRegion) (e.label, '${e.count}')]),
            ],
            if (sys.byActivity.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Panel(title: 'Made in the last 30 days, by kind', rows: [for (final e in sys.byActivity) (e.label, '${e.count}')]),
            ],
            if (sys.byRole.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Panel(title: 'Going, by role', rows: [for (final e in sys.byRole) (e.label, '${e.count}')]),
            ],
            if (sys.byProfession.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Panel(title: 'Signed up, by profession', rows: [for (final e in sys.byProfession) (e.label, '${e.count}')]),
            ],
            const Eyebrow('Every table'),
            _Tables(sys.tables, now),
          ],
        );
      },
    );
  }
}

/// a titled list of rows, each a name and a value
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.hint)),
          const SizedBox(height: 4),
          for (final (label, value) in rows) AdminLine(label, value),
        ],
      ),
    );
  }
}

/// every table of the database, the biggest first: its rows, its size and when something was last put in it
class _Tables extends StatelessWidget {
  const _Tables(this.tables, this.now);

  final List<SystemTable> tables;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (tables.isEmpty) {
      return const Panel(child: Text('No table was listed.', style: TextStyle(color: AppColors.muted)));
    }
    final rows = tables.fold<int>(0, (sum, t) => sum + t.rows);
    final bytes = tables.fold<int>(0, (sum, t) => sum + t.bytes);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${tables.length} tables, ${fmtInt(rows)} rows, ${formatBytes(bytes)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSoft),
          ),
          const SizedBox(height: 6),
          for (final t in tables)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(fmtInt(t.rows), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppColors.gold)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(formatBytes(t.bytes), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      t.newest == null ? '' : ago(t.newest!, now),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: AppColors.hint),
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
