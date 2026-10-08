import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../state/admin_actions.dart';
import '../../state/admin_logs.dart';
import '../../state/admin_system.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/common.dart';
import '../../widgets/meters.dart';
import 'logs_screen.dart';
import 'table_screen.dart';
import 'widgets.dart';

part 'system/alerts.dart';
part 'system/run_by_hand.dart';

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
            ref.invalidate(adminAlertsProvider);
            ref.invalidate(adminLogsProvider);
            await ref.read(adminSystemProvider.future);
          },
          primary: [
            const Eyebrow('Run by hand'),
            const _RunByHand(),
            const Eyebrow('Alerts'),
            const _AlertsPanel(),
            const Eyebrow('Edge function logs'),
            const _EdgeFunctions(),
            const Eyebrow('Sync functions, last hour'),
            AdminHealth(sys.syncLines(now)),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'What each function answered to the call the database made to wake it. ${sys.syncCallsKept} calls are kept, for three hours.',
                style: TextStyle(fontSize: 12, color: AppColors.hint),
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
                      asInt(p['attempts']) == 0
                          ? 'waiting'
                          : '${asInt(p['attempts'])} tries: ${p['last_error'] ?? 'no reason given'}',
                    ),
                ]),
              ],
            ],
          ],
          secondary: [
            const Eyebrow('Scheduled jobs'),
            cron.isEmpty
                ? Panel(child: Text('The schedule could not be read.', style: TextStyle(color: AppColors.muted)))
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
              _Panel(
                  title: 'Still to come, by region',
                  rows: [for (final e in sys.upcomingByRegion) (e.label, '${e.count}')]),
            ],
            if (sys.byActivity.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Panel(
                  title: 'Made in the last 30 days, by kind',
                  rows: [for (final e in sys.byActivity) (e.label, '${e.count}')]),
            ],
            if (sys.byRole.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Panel(title: 'Going, by role', rows: [for (final e in sys.byRole) (e.label, '${e.count}')]),
            ],
            if (sys.byProfession.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Panel(
                  title: 'Signed up, by profession', rows: [for (final e in sys.byProfession) (e.label, '${e.count}')]),
            ],
            const Eyebrow('Every table'),
            AdminHealth([sys.databaseLine()]),
            const SizedBox(height: 10),
            _Tables(sys.tables, now),
            if (sys.hidden.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Panel(title: "Outside the app's tables", rows: [
                for (final h in sys.hidden) (h.name, '${formatBytes(h.bytes)} · about ${fmtInt(h.rows)} rows'),
              ]),
            ],
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
          Text(title.toUpperCase(),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.hint)),
          const SizedBox(height: 4),
          for (final (label, value) in rows) AdminLine(label, value),
        ],
      ),
    );
  }
}

/// what the Edge Functions said in the last day: how each did, and a way into the lines themselves, all of them or those of one
class _EdgeFunctions extends ConsumerWidget {
  const _EdgeFunctions();

  void _open(BuildContext context, {String? fn}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AdminLogsScreen(fn: fn)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(adminLogsProvider(noLogQuery));
    final now = DateTime.now();
    return logs.when(
      loading: () => Panel(child: Text('Reading the logs…', style: TextStyle(color: AppColors.hint, fontSize: 13))),
      // an older backend has no logs to give: said, and nothing else is held up by it
      error: (_, __) => Panel(
        child: Text('The logs of the functions could not be read. The backend may not have them yet.',
            style: TextStyle(color: AppColors.amber, fontSize: 13)),
      ),
      data: (page) => Panel(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (page.functions.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nothing has been said in the last day.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ),
            for (final f in page.functions)
              InkWell(
                onTap: () => _open(context, fn: f.fn),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AdminLine(
                    f.fn,
                    f.lastAt == null ? f.summary : '${f.summary} · ${ago(f.lastAt!, now)}',
                    valueColor: f.errors > 0 ? AppColors.ember : (f.warnings > 0 ? AppColors.amber : null),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _open(context), child: Text('All logs (${page.total})')),
            ),
          ],
        ),
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
      return Panel(child: Text('No table was listed.', style: TextStyle(color: AppColors.muted)));
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
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSoft),
          ),
          Text('Tap a table to see its rows.', style: TextStyle(fontSize: 12, color: AppColors.hint)),
          const SizedBox(height: 6),
          for (final t in tables)
            InkWell(
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AdminTableScreen(table: t.name))),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: AppColors.textSoft)),
                          // what is dead takes room: told when there is much of it
                          if (t.dead >= 1000)
                            Text(
                              '${fmtInt(t.dead)} dead rows${t.vacuumed == null ? '' : ', vacuumed ${ago(t.vacuumed!, now)}'}',
                              style: TextStyle(fontSize: 11, color: t.bloated ? AppColors.ember : AppColors.hint),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(fmtInt(t.rows),
                          textAlign: TextAlign.right, style: TextStyle(fontSize: 13, color: AppColors.gold)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(formatBytes(t.bytes),
                          textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        t.newest == null ? '' : ago(t.newest!, now),
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, color: AppColors.hint),
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
