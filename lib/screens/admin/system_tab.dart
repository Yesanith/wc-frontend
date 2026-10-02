import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../state/admin_actions.dart';
import '../../state/admin_system.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/common.dart';
import '../../widgets/meters.dart';
import 'table_screen.dart';
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
            ref.invalidate(adminAlertsProvider);
            await ref.read(adminSystemProvider.future);
          },
          primary: [
            const Eyebrow('Run by hand'),
            const _RunByHand(),
            const Eyebrow('Alerts'),
            const _AlertsPanel(),
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
          Text(title.toUpperCase(),
              style:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.hint)),
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
          const Text('Tap a table to see its rows.', style: TextStyle(fontSize: 12, color: AppColors.hint)),
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
                      child: Text(t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSoft)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(fmtInt(t.rows),
                          textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppColors.gold)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(formatBytes(t.bytes),
                          textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
            ),
        ],
      ),
    );
  }
}

/// the jobs that run by themselves, to run now: a sync function is woken and its answer is waited for and told, a job of the database is run and
/// what it says is told. one that lets go of data asks first
class _RunByHand extends ConsumerStatefulWidget {
  const _RunByHand();

  @override
  ConsumerState<_RunByHand> createState() => _RunByHandState();
}

class _RunByHandState extends ConsumerState<_RunByHand> {
  final _running = <String>{};

  Future<void> _say(String title, String headline, String body, {bool good = false}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline,
                style: TextStyle(fontWeight: FontWeight.w800, color: good ? AppColors.gold : AppColors.ember)),
            const SizedBox(height: 10),
            Flexible(child: SingleChildScrollView(child: SelectableText(body, style: const TextStyle(fontSize: 13)))),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _run(AdminJob job) async {
    if (job.danger) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Run ${job.name}?'),
          content: Text('${job.what}. This lets go of data and cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Run it')),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => _running.add(job.name));
    final backend = ref.read(adminBackendProvider);
    final every = ref.read(adminPollEveryProvider);
    final messenger = ScaffoldMessenger.of(context);
    // what is to be told when it is over: a title, what happened, and what it said. told once the button has stopped turning
    ({String headline, String body, bool good})? outcome;
    try {
      final result = await backend.run(job.name);
      if (!mounted) return;
      final request = result.requestId;
      if (!result.ok) {
        outcome = (headline: 'It failed', body: result.error ?? 'No reason was given', good: false);
      } else if (job.wakes && request != null) {
        messenger.showSnackBar(SnackBar(content: Text('${job.name}: called, waiting for its answer')));
        final answer = await waitForAnswer(() => backend.callResult(request), every: every);
        if (!mounted) return;
        messenger.hideCurrentSnackBar();
        outcome = answer == null
            ? (
                headline: 'No answer yet',
                body:
                    'It has not answered in fifteen seconds. It may still be working: look at the sync functions below in a minute.',
                good: false,
              )
            : (
                headline: 'Answered ${answer.summary}',
                body: answer.content.isEmpty ? 'It said nothing.' : answer.content,
                good: answer.ok,
              );
      } else {
        messenger.showSnackBar(SnackBar(content: Text('${job.name}: done')));
      }
      ref.invalidate(adminSystemProvider);
      ref.invalidate(adminDashboardProvider);
    } catch (e) {
      outcome = (headline: 'It failed', body: '$e', good: false);
    } finally {
      if (mounted) setState(() => _running.remove(job.name));
    }
    if (outcome != null && mounted) await _say(job.name, outcome.headline, outcome.body, good: outcome.good);
  }

  @override
  Widget build(BuildContext context) {
    return ref.watch(adminJobsProvider).when(
          loading: () => const Panel(
              child:
                  Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))),
          error: (e, _) => Panel(
            child: Row(
              children: [
                const Expanded(
                    child: Text('The list of jobs could not be read.', style: TextStyle(color: AppColors.muted))),
                TextButton(onPressed: () => ref.invalidate(adminJobsProvider), child: const Text('Retry')),
              ],
            ),
          ),
          data: (jobs) => Panel(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                for (final job in jobs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(job.what, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(job.name, style: const TextStyle(fontSize: 12, color: AppColors.hint)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_running.contains(job.name))
                          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          FilledButton.tonal(onPressed: () => _run(job), child: Text(job.danger ? 'Run…' : 'Run')),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
  }
}

/// where the alerts go and what is wrong now: the address of the webhook is set here and never shown again, a test can be sent and its answer is told,
/// and what was sent lately is listed
class _AlertsPanel extends ConsumerStatefulWidget {
  const _AlertsPanel();

  @override
  ConsumerState<_AlertsPanel> createState() => _AlertsPanelState();
}

class _AlertsPanelState extends ConsumerState<_AlertsPanel> {
  bool _busy = false;

  Future<void> _tell(String title, String headline, String body, {bool good = false}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline,
                style: TextStyle(fontWeight: FontWeight.w800, color: good ? AppColors.gold : AppColors.ember)),
            const SizedBox(height: 10),
            Flexible(child: SingleChildScrollView(child: SelectableText(body, style: const TextStyle(fontSize: 13)))),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _set(AdminAlerts alerts) async {
    final url = await showDialog<String>(context: context, builder: (_) => const _WebhookDialog());
    if (url == null || !mounted) return;
    await _work(() async {
      await ref.read(adminBackendProvider).setAlertWebhook(url);
      ref.invalidate(adminAlertsProvider);
    }, 'The webhook could not be kept');
  }

  Future<void> _remove() async {
    await _work(() async {
      await ref.read(adminBackendProvider).setAlertWebhook(null);
      ref.invalidate(adminAlertsProvider);
    }, 'The webhook could not be taken away');
  }

  Future<void> _test() async {
    final backend = ref.read(adminBackendProvider);
    final every = ref.read(adminPollEveryProvider);
    CallAnswer? answer;
    String? error;
    await _work(() async {
      final request = await backend.testAlert();
      answer = await waitForAnswer(() => backend.callResult(request), every: every);
      ref.invalidate(adminAlertsProvider);
    }, 'The test could not be sent', onError: (e) => error = e);
    if (!mounted || error != null) return;
    final a = answer;
    await _tell(
      'Test of the alerts',
      a == null ? 'No answer yet' : (a.ok ? 'Discord accepted it (${a.summary})' : 'Discord answered ${a.summary}'),
      a == null
          ? 'Discord has not answered in fifteen seconds. Look in the channel in a minute.'
          : (a.ok
              ? 'Look for it in the channel of the webhook.'
              : (a.content.isEmpty ? 'It said nothing.' : a.content)),
      good: a?.ok == true,
    );
  }

  /// does something that asks the database, with the buttons held while it does, and says if it could not
  Future<void> _work(Future<void> Function() job, String failure, {void Function(String)? onError}) async {
    setState(() => _busy = true);
    try {
      await job();
    } catch (e) {
      onError?.call('$e');
      if (mounted) await _tell('Alerts', failure, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return ref.watch(adminAlertsProvider).when(
          loading: () => const Panel(
              child:
                  Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))),
          error: (e, _) => Panel(
            child: Row(
              children: [
                const Expanded(child: Text('The alerts could not be read.', style: TextStyle(color: AppColors.muted))),
                TextButton(onPressed: () => ref.invalidate(adminAlertsProvider), child: const Text('Retry')),
              ],
            ),
          ),
          data: (alerts) {
            final problems = alerts.problemsNow;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Panel(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alerts.webhookSet
                            ? 'Sent to a Discord webhook (…${alerts.webhookTail})'
                            : 'Nowhere: set a Discord webhook to be told when something is wrong',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: alerts.webhookSet ? AppColors.textSoft : AppColors.ember),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Looked for every five minutes. A new problem is sent at once, one that stays every six hours, one that is gone is told to be.',
                        style: TextStyle(fontSize: 12, color: AppColors.hint),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: _busy ? null : () => _set(alerts),
                            child: Text(alerts.webhookSet ? 'Change webhook' : 'Set webhook'),
                          ),
                          if (alerts.webhookSet) ...[
                            FilledButton.tonal(onPressed: _busy ? null : _test, child: const Text('Send a test')),
                            TextButton(onPressed: _busy ? null : _remove, child: const Text('Remove')),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                problems.isEmpty
                    ? const AdminHealth([HealthLine('Right now', 'Nothing is wrong', HealthLevel.good)])
                    : AdminHealth([
                        for (final p in problems)
                          HealthLine('Wrong now', p.message, p.severity == 'bad' ? HealthLevel.bad : HealthLevel.warn),
                      ]),
                if (alerts.recent.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Panel(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SENT LATELY',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.hint)),
                        const SizedBox(height: 4),
                        for (final e in alerts.recent)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_icon(e.kind), style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(e.message,
                                        style: const TextStyle(fontSize: 13, color: AppColors.textSoft))),
                                const SizedBox(width: 8),
                                Text(
                                  '${e.at == null ? '' : ago(e.at!, now)}${e.sent ? '' : ' · not sent'}',
                                  style: TextStyle(fontSize: 11, color: e.sent ? AppColors.hint : AppColors.ember),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        );
  }

  String _icon(String kind) => switch (kind) {
        'raised' => '🔴',
        'reminder' => '🟠',
        'resolved' => '✅',
        _ => '🔔',
      };
}

/// the address of the webhook, asked for once: it is checked to be one before it is sent, and is not shown again
class _WebhookDialog extends StatefulWidget {
  const _WebhookDialog();

  @override
  State<_WebhookDialog> createState() => _WebhookDialogState();
}

class _WebhookDialogState extends State<_WebhookDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final url = _controller.text.trim();
    if (!isDiscordWebhook(url)) {
      setState(() =>
          _error = 'That is not the address of a Discord webhook. It begins with https://discord.com/api/webhooks/');
      return;
    }
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Discord webhook'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Make one in the settings of a channel (Integrations, Webhooks) and paste its address here. It is kept secret: it is not shown again.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration:
                InputDecoration(hintText: 'https://discord.com/api/webhooks/…', errorText: _error, errorMaxLines: 3),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Keep it')),
      ],
    );
  }
}
