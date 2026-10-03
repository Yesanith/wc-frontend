import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../state/admin_actions.dart';
import '../../state/admin_logs.dart' show LogLevel;
import '../../state/admin_platform_logs.dart';
import '../../theme.dart';

/// what Supabase itself recorded of the Edge Functions: what they wrote to their console, and the requests that were made to them, which the lines the functions keep for themselves
/// cannot tell: a function that did not start, one that ran out of time, one that was never called. Newest first, of one function or all, over the last hour, six hours or day, a
/// page at a time. Nothing can be changed from here
class PlatformLogsView extends ConsumerStatefulWidget {
  const PlatformLogsView({super.key});

  @override
  ConsumerState<PlatformLogsView> createState() => _PlatformLogsViewState();
}

class _PlatformLogsViewState extends ConsumerState<PlatformLogsView> {
  final _search = TextEditingController();
  PlatformSource _source = PlatformSource.console;
  String? _fnId;
  LogLevel? _level;
  bool _onlyErrors = false;
  int _hours = 1;
  String _text = '';

  /// the times the pages end at. null is the newest page, the others each follow the one before
  List<String?> _pages = [null];

  PlatformQuery _query(String? before) => (
        source: _source,
        fnId: _fnId,
        level: _level,
        search: _text,
        hours: _hours,
        before: before,
        onlyErrors: _onlyErrors
      );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _change(VoidCallback change) => setState(() {
        change();
        _pages = [null];
      });

  @override
  Widget build(BuildContext context) {
    final first = ref.watch(adminPlatformLogsProvider(_query(null)));
    final functions = first.valueOrNull?.functions ?? const <PlatformFunction>[];
    final page = first.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('platform-search'),
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (text) => _change(() => _text = text.trim()),
          decoration: InputDecoration(
            hintText: 'Search what was recorded',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      _change(() => _text = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final source in PlatformSource.values)
              ChoiceChip(
                  label: Text(source.label),
                  selected: _source == source,
                  onSelected: (_) => _change(() => _source = source)),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final hours in platformHours)
              ChoiceChip(
                label: Text(hours == 1 ? 'Last hour' : 'Last $hours hours'),
                selected: _hours == hours,
                onSelected: (_) => _change(() => _hours = hours),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
                label: const Text('All functions'),
                selected: _fnId == null,
                onSelected: (_) => _change(() => _fnId = null)),
            for (final f in functions)
              ChoiceChip(
                label: Text(f.slug.isEmpty ? f.id.substring(0, f.id.length < 8 ? f.id.length : 8) : f.slug),
                selected: _fnId == f.id,
                onSelected: (_) => _change(() => _fnId = f.id),
              ),
            // a function that was chosen stays a chip when the list no longer has it
            if (_fnId != null && !functions.any((f) => f.id == _fnId))
              ChoiceChip(
                  label: Text(page?.nameOf(_fnId!) ?? _fnId!.substring(0, _fnId!.length < 8 ? _fnId!.length : 8)),
                  selected: true,
                  onSelected: (_) {}),
          ],
        ),
        const SizedBox(height: 4),
        if (_source == PlatformSource.console)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                  label: const Text('All levels'),
                  selected: _level == null,
                  onSelected: (_) => _change(() => _level = null)),
              for (final level in LogLevel.values)
                ChoiceChip(
                    label: Text(level.label),
                    selected: _level == level,
                    onSelected: (_) => _change(() => _level = level)),
            ],
          )
        else
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                  label: const Text('Only the ones that failed'),
                  selected: _onlyErrors,
                  onSelected: (on) => _change(() => _onlyErrors = on)),
            ],
          ),
        const SizedBox(height: 12),
        for (var i = 0; i < _pages.length; i++)
          _PlatformPage(
            query: _query(_pages[i]),
            newest: i == 0,
            last: i == _pages.length - 1,
            onOlder: (before) => setState(() => _pages = [..._pages, before]),
            onRetry: () => ref.invalidate(adminPlatformLogsProvider),
          ),
      ],
    );
  }
}

/// one page of lines, watched by itself, so that the older ones are added under the newer and the newer ones are not asked for again
class _PlatformPage extends ConsumerWidget {
  const _PlatformPage(
      {required this.query, required this.newest, required this.last, required this.onOlder, required this.onRetry});

  final PlatformQuery query;
  final bool newest;
  final bool last;
  final void Function(String before) onOlder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(adminPlatformLogsProvider(query));
    return page.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _PlatformNotice(
        problem: e is PlatformLogsException ? e.problem : PlatformProblem.unknown,
        detail: e is PlatformLogsException ? e.detail : null,
        onRetry: onRetry,
      ),
      data: (data) {
        final now = DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newest && data.rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Nothing was recorded in this window. Try a longer one.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                ),
              ),
            for (final line in data.rows) _PlatformCard(line: line, now: now),
            if (last && data.mayHaveOlder && data.oldest != null)
              Align(child: TextButton(onPressed: () => onOlder(data.oldest!), child: const Text('Older'))),
          ],
        );
      },
    );
  }
}

Color _levelColor(LogLevel level) => switch (level) {
      LogLevel.error => AppColors.ember,
      LogLevel.warn => AppColors.amber,
      LogLevel.info => AppColors.muted,
    };

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
    final color = _levelColor(line.level);
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
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border(
                left: BorderSide(color: color, width: 3),
                top: const BorderSide(color: AppColors.line),
                right: const BorderSide(color: AppColors.line),
                bottom: const BorderSide(color: AppColors.line),
              ),
            ),
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
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy, size: 16, color: AppColors.hint),
                      onPressed: () => Clipboard.setData(ClipboardData(text: _copyText(line, text, attrs))),
                    ),
                  ],
                ),
                _open
                    ? SelectableText(text, style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.35))
                    : Text(text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.35)),
                // a request has what the function wrote of it too, as its message
                if (_open && line.isRequest && line.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child:
                        SelectableText(line.message, style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
                  ),
                if (_open && line.at != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child:
                        Text(line.at!.toIso8601String(), style: const TextStyle(fontSize: 11, color: AppColors.hint)),
                  ),
                if (_open && attrs != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SelectableText(attrs,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSoft)),
                  ),
                if (!_open && attrs != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child:
                        Text('Tap for what the platform knows', style: TextStyle(fontSize: 11, color: AppColors.hint)),
                  ),
              ],
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.amber)),
          const SizedBox(height: 8),
          SelectableText(body, style: const TextStyle(fontSize: 13, color: AppColors.textSoft, height: 1.45)),
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
              style: const TextStyle(color: AppColors.amber)),
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
