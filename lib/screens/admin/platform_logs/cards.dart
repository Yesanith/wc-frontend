part of '../platform_logs_view.dart';

class _PlatformCard extends StatefulWidget {
  const _PlatformCard({required this.line, required this.now});

  final PlatformLogLine line;
  final DateTime now;

  @override
  State<_PlatformCard> createState() => _PlatformCardState();
}

class _PlatformCardState extends State<_PlatformCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final color = logLevelColor(line.level);
    final attrs = line.attrsText;
    // a request is told by its line, a line of the console by what it said
    final text = line.isRequest ? line.requestLine : line.message;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => setState(() => _open = !_open),
          // one border all round, which a rounded corner needs, and the colour of the level as a strip along its edge
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.line),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(
                                      text: line.fn.isEmpty
                                          ? (line.fnId.isEmpty
                                              ? 'platform'
                                              : line.fnId.substring(0, line.fnId.length < 8 ? line.fnId.length : 8))
                                          : line.fn,
                                      style: TextStyle(fontWeight: FontWeight.w700, color: color),
                                    ),
                                    TextSpan(text: line.at == null ? '' : ' · ${ago(line.at!, widget.now)}'),
                                  ]),
                                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.copy, size: 16, color: AppColors.hint),
                                onPressed: () => Clipboard.setData(ClipboardData(text: _copyText(line, text, attrs))),
                              ),
                            ],
                          ),
                          _open
                              ? SelectableText(text,
                                  style: TextStyle(fontSize: 13, color: AppColors.text, height: 1.35))
                              : Text(text,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: AppColors.text, height: 1.35)),
                          // a request has what the function wrote of it too, as its message
                          if (_open && line.isRequest && line.message.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: SelectableText(line.message,
                                  style: TextStyle(fontSize: 12, color: AppColors.textSoft)),
                            ),
                          if (_open && line.at != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(line.at!.toIso8601String(),
                                  style: TextStyle(fontSize: 11, color: AppColors.hint)),
                            ),
                          if (_open && attrs != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: SelectableText(attrs,
                                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSoft)),
                            ),
                          if (!_open && attrs != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('Tap for what the platform knows',
                                  style: TextStyle(fontSize: 11, color: AppColors.hint)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _copyText(PlatformLogLine line, String text, String? attrs) =>
      '${line.at?.toIso8601String() ?? ''} ${line.level.code} ${line.fn.isEmpty ? line.fnId : line.fn}: $text${attrs == null ? '' : '\n$attrs'}';
}

/// what is said where the lines would be, when they could not be read: what is wrong, and what to do about it
class _PlatformNotice extends ConsumerWidget {
  const _PlatformNotice({required this.problem, required this.onRetry, this.detail});

  final PlatformProblem problem;
  final String? detail;
  final VoidCallback onRetry;

  /// where a token is made
  static const tokensPage = 'https://supabase.com/dashboard/account/tokens';

  /// what the secret is called, in the repository and at the project
  static const secretName = 'PLATFORM_LOGS_TOKEN';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, body) = switch (problem) {
      PlatformProblem.notConfigured => (
          'The platform logs are not set up',
          '1. Open $tokensPage and generate a new token. Make it a scoped one, for this project only, with the permission "Analytics logs: read" (and "Edge Functions: read" for the names of the functions).\n'
              '2. In the backend repository: Settings → Secrets and variables → Actions → New repository secret, named $secretName, with the token.\n'
              '3. Run the Deploy workflow again, so that the function has it.',
        ),
      PlatformProblem.tokenRejected => (
          'Supabase turned the token down',
          'It may be wrong, revoked, or not allowed to read logs: it needs the permission "Analytics logs: read". Make a new one, replace the secret $secretName and run the Deploy workflow again.',
        ),
      PlatformProblem.plan => (
          'The logs are not in the plan',
          'The plan of this project does not include the logs of the platform.'
        ),
      PlatformProblem.rateLimited => (
          'Supabase is limiting the logs',
          'The logs may be asked for only so often. Wait a minute and try again.'
        ),
      PlatformProblem.upstream => (
          'Supabase did not give the logs',
          'It did not answer, or answered with something that is no logs. Try again in a moment.'
        ),
      PlatformProblem.queryError => (
          'Supabase refused the query',
          'A field may not be called what the query thinks. What the platform said:\n${detail ?? 'nothing'}',
        ),
      PlatformProblem.notAdmin => ('Only for an administrator', 'The platform logs are shown to administrators only.'),
      PlatformProblem.notSignedIn => (
          'Sign in again',
          'The session is no longer valid. Sign in and open the logs again.'
        ),
      PlatformProblem.tooFar => (
          'That is as far back as the logs go',
          'The platform keeps its logs for a short time, and does not have anything older.'
        ),
      PlatformProblem.unknown => ('The platform logs could not be read', 'Try again in a moment.'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.amber)),
          const SizedBox(height: 8),
          SelectableText(body, style: TextStyle(fontSize: 13, color: AppColors.textSoft, height: 1.45)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (problem == PlatformProblem.notConfigured) ...[
                OutlinedButton(
                  onPressed: () => Clipboard.setData(const ClipboardData(text: secretName)),
                  child: const Text('Copy the secret name'),
                ),
                OutlinedButton(
                  onPressed: () => Clipboard.setData(const ClipboardData(text: tokensPage)),
                  child: const Text('Copy the token page'),
                ),
              ],
              if (problem == PlatformProblem.queryError)
                OutlinedButton(onPressed: () => _showKeys(context, ref), child: const Text('Show what the logs have')),
              if (problem != PlatformProblem.notAdmin && problem != PlatformProblem.tooFar)
                TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showKeys(BuildContext context, WidgetRef ref) => showDialog<void>(
        context: context,
        builder: (_) => const _KeysDialog(),
      );
}

/// the keys the lines of the two sources really carry, with how many lines have each: what to look at to put a refused query right
class _KeysDialog extends ConsumerWidget {
  const _KeysDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(adminPlatformKeysProvider);
    return AlertDialog(
      title: const Text('What the logs have'),
      content: SizedBox(
        width: 420,
        child: keys.when(
          loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('That could not be read: ${e is PlatformLogsException ? e.problem.name : e}',
              style: TextStyle(color: AppColors.amber)),
          data: (list) => list.isEmpty
              ? const Text('No lines in the last minute.')
              : SingleChildScrollView(
                  child: SelectableText(
                    [for (final k in list) '${k.source}  ${k.key}  ×${k.events}'].join('\n'),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
