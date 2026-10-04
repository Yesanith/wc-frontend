import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../state/admin_actions.dart';
import '../../state/admin_logs.dart';
import '../../theme.dart';
import '../../widgets/responsive.dart';
import 'platform_logs_view.dart';

/// what the Edge Functions said, newest first: of one function or all, of one level or all, with a search for the lines that have a text in them. a line opens to what it knew of the
/// matter, which can be selected and copied. the older lines are asked for a page at a time. nothing can be changed from here
class AdminLogsScreen extends ConsumerStatefulWidget {
  const AdminLogsScreen({super.key, this.fn, this.platform = false});

  /// the logs of the platform, which Supabase keeps, are shown first and not the lines the functions kept
  final bool platform;

  /// the function the logs begin with, when they were opened from one
  final String? fn;

  @override
  ConsumerState<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends ConsumerState<AdminLogsScreen> {
  final _search = TextEditingController();
  late String? _fn = widget.fn;
  late bool _platform = widget.platform;
  LogLevel? _level;
  String _text = '';

  /// the numbers the pages begin after. null is the newest page, the others each follow the one before
  List<int?> _pages = [null];

  LogQuery _query(int? before) => (fn: _fn, level: _level, search: _text, before: before);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _change(VoidCallback change) => setState(() {
        change();
        _pages = [null];
      });

  void _refresh() {
    for (final before in _pages) {
      ref.invalidate(adminLogsProvider(_query(before)));
    }
    ref.invalidate(adminPlatformLogsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final first = ref.watch(adminLogsProvider(_query(null)));
    // how each function did is told whatever the query is, so the chips are there when a search finds nothing
    final functions = ref.watch(adminLogsProvider(noLogQuery)).valueOrNull?.functions ?? const <FunctionStat>[];
    final names = {...functions.map((f) => f.fn), if (_fn != null) _fn!}.toList()..sort();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: const Text('Function logs'),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: ContentFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // what the functions kept for themselves, or what the platform recorded of them
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Saved by the functions')),
                ButtonSegment(value: true, label: Text('Supabase platform')),
              ],
              selected: {_platform},
              onSelectionChanged: (choice) => setState(() => _platform = choice.first),
            ),
            const SizedBox(height: 12),
            if (_platform)
              const PlatformLogsView()
            else ...[
              TextField(
                key: const Key('log-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (text) => _change(() => _text = text.trim()),
                decoration: InputDecoration(
                  hintText: 'Search what they said',
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
                  ChoiceChip(
                      label: const Text('All functions'),
                      selected: _fn == null,
                      onSelected: (_) => _change(() => _fn = null)),
                  for (final name in names)
                    ChoiceChip(
                      label: Text(_chipLabel(name, functions)),
                      selected: _fn == name,
                      onSelected: (_) => _change(() => _fn = name),
                    ),
                ],
              ),
              const SizedBox(height: 4),
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
              ),
              const SizedBox(height: 12),
              if (first.valueOrNull case final page?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${page.total} lines kept, for two weeks',
                      style: TextStyle(fontSize: 12, color: AppColors.hint)),
                ),
              for (var i = 0; i < _pages.length; i++)
                _LogPage(
                  query: _query(_pages[i]),
                  newest: i == 0,
                  last: i == _pages.length - 1,
                  onOlder: (before) => setState(() => _pages = [..._pages, before]),
                  onRetry: _refresh,
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// the name of a function, with its errors of the last day when it has any
  String _chipLabel(String name, List<FunctionStat> functions) {
    final errors = functions.where((f) => f.fn == name).fold(0, (sum, f) => sum + f.errors);
    return errors > 0 ? '$name · $errors' : name;
  }
}

/// one page of lines, watched by itself, so that the older ones are added under the newer and the newer ones are not asked for again
class _LogPage extends ConsumerWidget {
  const _LogPage(
      {required this.query, required this.newest, required this.last, required this.onOlder, required this.onRetry});

  final LogQuery query;
  final bool newest;
  final bool last;
  final void Function(int before) onOlder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(adminLogsProvider(query));
    return page.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('The logs could not be read: ${e is Exception ? e : e.toString()}',
                style: TextStyle(color: AppColors.amber, fontSize: 13)),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
      data: (data) {
        final now = DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (newest && data.rows.isEmpty)
              Padding(
                padding: EdgeInsets.all(24),
                child:
                    Center(child: Text('Nothing like that has been said.', style: TextStyle(color: AppColors.muted))),
              ),
            for (final line in data.rows) _LogCard(line: line, now: now),
            if (last && data.mayHaveOlder && data.oldestId != null)
              Align(
                alignment: Alignment.center,
                child: TextButton(onPressed: () => onOlder(data.oldestId!), child: const Text('Older')),
              ),
          ],
        );
      },
    );
  }
}

class _LogCard extends StatefulWidget {
  const _LogCard({required this.line, required this.now});

  final FunctionLogLine line;
  final DateTime now;

  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final detail = line.detailText;
    final color = logLevelColor(line.level);
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
                                        text: line.fn, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                                    TextSpan(text: line.at == null ? '' : ' · ${ago(line.at!, widget.now)}'),
                                    if (line.repeats > 1)
                                      TextSpan(
                                          text: '  ×${line.repeats}',
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ]),
                                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.copy, size: 16, color: AppColors.hint),
                                onPressed: () => Clipboard.setData(ClipboardData(text: _copyText(line, detail))),
                              ),
                            ],
                          ),
                          _open
                              ? SelectableText(line.message,
                                  style: TextStyle(fontSize: 13, color: AppColors.text, height: 1.35))
                              : Text(line.message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: AppColors.text, height: 1.35)),
                          if (_open && line.at != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(line.at!.toIso8601String(),
                                  style: TextStyle(fontSize: 11, color: AppColors.hint)),
                            ),
                          if (_open && detail != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: SelectableText(detail,
                                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.textSoft)),
                            ),
                          if (!_open && detail != null)
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child:
                                  Text('Tap for what it knew', style: TextStyle(fontSize: 11, color: AppColors.hint)),
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

  String _copyText(FunctionLogLine line, String? detail) =>
      '${line.at?.toIso8601String() ?? ''} ${line.level.code} ${line.fn}: ${line.message}${line.repeats > 1 ? ' (x${line.repeats})' : ''}${detail == null ? '' : '\n$detail'}';
}
