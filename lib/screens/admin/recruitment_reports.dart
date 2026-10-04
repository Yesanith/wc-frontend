import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/recruitment.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../recruitment/page_screen.dart';

/// the recruitment pages that were reported or are hidden. a page is read by everybody, so the administrator may hide one from everybody but those who manage it, with a reason that they are shown,
/// and show it again. the pages that have been reported most come first, those that are hidden last
class AdminRecruitReports extends ConsumerWidget {
  const AdminRecruitReports({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminRecruitReportsProvider);
    return reports.when(
      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      // a backend that is older than the app has no such list yet: it is said calmly and the rest of the tab is as it was
      error: (_, __) => Panel(
        child: Row(
          children: [
            Expanded(
                child: Text('The recruitment pages could not be read.', style: TextStyle(color: AppColors.muted))),
            TextButton(onPressed: () => ref.invalidate(adminRecruitReportsProvider), child: const Text('Try again')),
          ],
        ),
      ),
      data: (list) => list.isEmpty
          ? Panel(
              child: Text('No recruitment page was reported, and none is hidden.',
                  style: TextStyle(color: AppColors.muted)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in list) ...[
                  _ReportCard(report: r),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});

  final RecruitReport report;

  Future<void> _set(BuildContext context, WidgetRef ref, bool hidden) async {
    String? reason;
    if (hidden) {
      reason = await showDialog<String>(context: context, builder: (_) => const _ReasonDialog());
      if (reason == null) return;
    }
    try {
      await ref.read(recruitBackendProvider).adminSetHidden(report.guildId, hidden, reason);
      // said before the list is asked for again: the card is gone while it is
      if (context.mounted) showToast(context, hidden ? 'Hidden' : 'Shown again');
      ref.invalidate(adminRecruitReportsProvider);
      ref.invalidate(recruitListProvider);
    } catch (_) {
      if (context.mounted) showToast(context, 'That did not work');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(report.title, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(report.hidden ? 'Hidden' : (report.published ? 'Shown' : 'Draft'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: report.hidden ? AppColors.ember : AppColors.muted)),
            ],
          ),
          if (report.headline.isNotEmpty)
            Text(report.headline, style: TextStyle(fontSize: 13, color: AppColors.textSoft)),
          const SizedBox(height: 6),
          Text(report.reports == 1 ? 'Reported by 1 player' : 'Reported by ${report.reports} players',
              style: TextStyle(fontSize: 12, color: AppColors.amber)),
          for (final reason in report.reasons)
            Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SelectableText('“$reason”', style: TextStyle(fontSize: 12, color: AppColors.muted))),
          if (report.hidden && report.hiddenReason != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Hidden because: ${report.hiddenReason}',
                    style: TextStyle(fontSize: 12, color: AppColors.ember))),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: () => showRecruitPage(context, report.guildId), child: const Text('Look')),
              if (report.hidden)
                TextButton(onPressed: () => _set(context, ref, false), child: const Text('Show again'))
              else
                TextButton(
                  onPressed: () => _set(context, ref, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.ember),
                  child: const Text('Hide'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// asks why a page is hidden: the guild is shown it
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hide this page'),
      content: TextField(
        key: const Key('hide-reason'),
        controller: _reason,
        maxLength: 200,
        decoration: const InputDecoration(labelText: 'Why? The guild is shown this'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(context).pop(_reason.text.trim()), child: const Text('Hide')),
      ],
    );
  }
}
