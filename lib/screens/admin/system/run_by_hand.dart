part of '../system_tab.dart';

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
