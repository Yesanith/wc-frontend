import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../state/admin_actions.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/responsive.dart';

/// a table of the database, a page at a time, newest first, with a search that finds the rows that have the text in them. a row opens to all of
/// its columns, which can be selected and copied. nothing can be changed from here
class AdminTableScreen extends ConsumerStatefulWidget {
  const AdminTableScreen({super.key, required this.table});

  final String table;

  @override
  ConsumerState<AdminTableScreen> createState() => _AdminTableScreenState();
}

class _AdminTableScreenState extends ConsumerState<AdminTableScreen> {
  final _search = TextEditingController();
  String _filter = '';
  int _offset = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _apply(String text) => setState(() {
        _filter = text.trim();
        _offset = 0;
      });

  @override
  Widget build(BuildContext context) {
    final query = (table: widget.table, offset: _offset, filter: _filter);
    final page = ref.watch(adminTableProvider(query));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(widget.table),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminTableProvider(query)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ContentFrame(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: _apply,
                decoration: InputDecoration(
                  hintText: 'Search the rows for a text',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _filter.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            _apply('');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: AsyncView<AdminTablePage>(
                value: page,
                onRetry: () => ref.invalidate(adminTableProvider(query)),
                builder: (p) => _Rows(
                  page: p,
                  onPrevious:
                      p.hasPrevious ? () => setState(() => _offset = (_offset - p.limit).clamp(0, 1 << 30)) : null,
                  onNext: p.hasNext ? () => setState(() => _offset += p.limit) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.page, required this.onPrevious, required this.onNext});

  final AdminTablePage page;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final columns = page.columns;
    final rows = page.rows;
    final now = DateTime.now();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              _Columns(columns, orderedBy: page.orderedBy),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No row has that.', style: TextStyle(color: AppColors.muted))),
                ),
              for (final row in rows) _RowCard(columns: columns, row: row, orderedBy: page.orderedBy, now: now),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(tooltip: 'Previous page', onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
              Text(rowsLabel(page.offset, rows.length, page.total),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(tooltip: 'Next page', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ),
      ],
    );
  }
}

/// the columns of the table with their types, shut until asked for
class _Columns extends StatelessWidget {
  const _Columns(this.columns, {required this.orderedBy});

  final List<TableColumn> columns;
  final String? orderedBy;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      // a tile paints on the material above it, which would be hidden by the colour of the panel: it has one of its own
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text('${columns.length} columns', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              orderedBy == null ? 'In no order that is known' : 'Newest first, by $orderedBy',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in columns)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(c.key ? Icons.key : (c.hidden ? Icons.visibility_off_outlined : Icons.circle),
                          size: c.key || c.hidden ? 14 : 5, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c.name, style: const TextStyle(fontSize: 13))),
                      Text(c.type, style: TextStyle(fontSize: 12, color: AppColors.hint)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// a row: what it is called, when it was made, and all of its columns when it is opened
class _RowCard extends StatelessWidget {
  const _RowCard({required this.columns, required this.row, required this.orderedBy, required this.now});

  final List<TableColumn> columns;
  final Map<String, dynamic> row;
  final String? orderedBy;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final stamp = orderedBy == null ? null : DateTime.tryParse('${row[orderedBy]}')?.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(rowTitle(columns, row),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: stamp == null
                  ? null
                  : Text(ago(stamp, now), style: TextStyle(fontSize: 12, color: AppColors.muted)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in columns)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: TextStyle(fontSize: 11, color: AppColors.hint)),
                        SelectableText(cellText(row[c.name]), style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: rowJson(row)));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Row copied')));
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy as JSON'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
