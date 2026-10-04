import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../state/recruitment.dart' show adminRecruitReportsProvider;
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/common.dart';
import '../../widgets/meters.dart';
import 'recruitment_reports.dart';
import 'widgets.dart';

/// somebody who is kept from making public events, and the way to let them make them again
class _BanRow extends ConsumerWidget {
  const _BanRow(this.ban);

  final Map<String, dynamic> ban;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = '${ban['user_id']}';
    final name = ban['name'] == null ? 'A player with no linked account' : '${ban['name']}';
    final since = '${ban['banned_at'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (since.length >= 10)
                    Text('since ${since.substring(0, 10)}',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await unbanOpenCreator(ref, id);
                  if (context.mounted) showToast(context, 'They may make public events again');
                } catch (_) {
                  if (context.mounted) showToast(context, 'That did not work');
                }
              },
              child: const Text('Let them make events'),
            ),
          ],
        ),
      ),
    );
  }
}

/// what to do with a public event somebody reported, or that is hidden, or was made lately
class AdminPublicEventsTab extends ConsumerWidget {
  const AdminPublicEventsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // the official server is shown when it has been read, the tab does not wait for it
    final official = ref.watch(adminOfficialProvider).valueOrNull;
    return AsyncView<AdminOpenEvents>(
      value: ref.watch(adminOpenEventsProvider),
      onRetry: () => ref.invalidate(adminOpenEventsProvider),
      builder: (o) {
        return AdminTab(
          updated: o.generatedAt,
          onRefresh: () async {
            ref.invalidate(adminOpenEventsProvider);
            ref.invalidate(adminRecruitReportsProvider);
            ref.invalidate(adminOfficialProvider);
            await ref.read(adminOpenEventsProvider.future);
          },
          primary: [
            const Eyebrow('Waiting for a look'),
            if (o.reports.isEmpty)
              Panel(
                  child: Text('No event was reported, or all that were have been looked at.',
                      style: TextStyle(color: AppColors.muted)))
            else
              for (final e in o.reports) ...[
                _EventCard(e, context: context, ref: ref, reported: true),
                const SizedBox(height: 10),
              ],
            const Eyebrow('Hidden'),
            if (o.hidden.isEmpty)
              Panel(child: Text('Nothing is hidden.', style: TextStyle(color: AppColors.muted)))
            else
              for (final e in o.hidden) ...[
                _EventCard({...e, 'hidden': true}, context: context, ref: ref),
                const SizedBox(height: 10),
              ],
            const Eyebrow('Guild recruitment pages'),
            const AdminRecruitReports(),
          ],
          secondary: [
            const Eyebrow('Public events'),
            AdminStatGrid(children: [
              AdminStat('To come', fmtInt(o.count('upcoming')), '${o.count('going_upcoming')} going'),
              AdminStat('Made this week', fmtInt(o.count('created_7d')), '${o.count('created_30d')} in 30 days'),
              AdminStat('Organizers', fmtInt(o.count('creators_30d')), 'in 30 days'),
              AdminStat('Joined this week', fmtInt(o.count('joined_7d')), 'signups'),
            ]),
            const SizedBox(height: 10),
            AdminHealth(o.health()),
            if (official != null) ...[
              const Eyebrow('Official Discord'),
              AdminHealth(official.health()),
              if (official.bans.isNotEmpty) ...[
                const Eyebrow('Kept from making events'),
                for (final b in official.bans) _BanRow(b),
              ],
            ],
            const Eyebrow('Made lately'),
            if (o.recent.isEmpty)
              Panel(child: Text('No public event has been made yet.', style: TextStyle(color: AppColors.muted)))
            else
              for (final e in o.recent) ...[
                _EventCard(e, context: context, ref: ref, recent: true),
                const SizedBox(height: 10),
              ],
          ],
        );
      },
    );
  }
}

/// one public event with what to do with it. an action that cannot be taken back asks first
class _EventCard extends StatelessWidget {
  const _EventCard(this.event, {required this.context, required this.ref, this.reported = false, this.recent = false});

  final Map<String, dynamic> event;
  final BuildContext context;
  final WidgetRef ref;
  final bool reported;
  final bool recent;

  Future<void> _act(String action, {String? ask, String yes = 'Yes'}) async {
    if (ask != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(ask),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(yes, style: TextStyle(color: AppColors.red))),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await moderateOpenEvent(ref, '${event['id']}', action);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Done')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime.tryParse('${event['start_at'] ?? ''}');
    final hidden = event['hidden'] == true;
    final reasons = event['reasons'] is List ? [for (final r in event['reasons'] as List) '$r'] : const <String>[];
    final notes = event['notes'] is List ? [for (final n in event['notes'] as List) '$n'] : const <String>[];
    final detail = [
      '${event['organizer']}',
      if (event['activity'] != null) '${event['activity']}',
      if (event['language'] != null && event['language'] != 'any') '${event['language']}',
      if (start != null) 'starts ${whenText(start.toLocal(), now)}',
      if (event['going'] != null) '${asInt(event['going'])} going',
      if (event['status'] == 'cancelled') 'cancelled',
    ].join(' · ');
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${event['title']}', style: const TextStyle(fontWeight: FontWeight.w700))),
              if (hidden) Text('hidden', style: TextStyle(fontSize: 11, color: AppColors.amber)),
              if (reported)
                Text('${asInt(event['reports'])} reports',
                    style: TextStyle(fontSize: 12, color: AppColors.amber)),
            ],
          ),
          const SizedBox(height: 2),
          Text(detail, style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35)),
          if (event['reason'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('hidden because: ${event['reason']}',
                  style: TextStyle(fontSize: 12, color: AppColors.amber)),
            ),
          if (reasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(reasons.join(', '), style: TextStyle(fontSize: 12, color: AppColors.gold)),
            ),
          for (final n in notes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('"$n"',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.muted, fontStyle: FontStyle.italic, height: 1.35)),
            ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              if (reported) _Action('Keep', () => _act('keep')),
              if (hidden) _Action('Show', () => _act('unhide')) else _Action('Hide', () => _act('hide')),
              _Action('Delete', () => _act('delete', ask: 'Delete this event for good?', yes: 'Delete'), danger: true),
              _Action(
                'Ban organizer',
                () => _act('ban_creator',
                    ask: 'Keep the organizer from making public events? Their events that are to come are hidden too.',
                    yes: 'Ban'),
                danger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.onTap, {this.danger = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: danger ? AppColors.red : AppColors.gold,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}
