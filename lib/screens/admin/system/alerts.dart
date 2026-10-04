part of '../system_tab.dart';

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
