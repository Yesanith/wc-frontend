import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../state/admin_actions.dart';
import '../../state/admin_logs.dart' show LogLevel;
import '../../state/admin_platform_logs.dart';
import '../../theme.dart';

part 'platform_logs/cards.dart';

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
              Padding(
                padding: const EdgeInsets.all(24),
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

Color logLevelColor(LogLevel level) => switch (level) {
      LogLevel.error => AppColors.ember,
      LogLevel.warn => AppColors.amber,
      LogLevel.info => AppColors.muted,
    };
