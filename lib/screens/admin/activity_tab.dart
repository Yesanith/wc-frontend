import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/meters.dart';
import 'widgets.dart';

class AdminActivityTab extends ConsumerWidget {
  const AdminActivityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<AdminServer>(
      value: ref.watch(adminServerProvider),
      onRetry: () => ref.invalidate(adminServerProvider),
      builder: (s) {
        final now = DateTime.now();
        final problem = s.problem('activity');
        const labels = {
          'event_created': 'Last event created',
          'signup': 'Last sign up for an event',
          'reminder_sent': 'Last Discord reminder',
          'roles_synced': 'Last Discord role sync',
          'guild_read': 'Last guild read by a leader',
          'player_active': 'Last player seen',
          'device_registered': 'Last device registered',
          'report_added': 'Last report added',
          'server_connected': 'Last server connected',
        };
        final feeds = s.section('feeds');
        final errors = [
          for (final e in (feeds['errors'] is List ? feeds['errors'] as List : const []))
            if (e is Map) Map<String, dynamic>.from(e)
        ];
        return AdminTab(
          updated: s.generatedAt,
          onRefresh: () async {
            ref.invalidate(adminServerProvider);
            await ref.read(adminServerProvider.future);
          },
          primary: [
            const Eyebrow('Last 30 days'),
            if (problem != null)
              Panel(child: Text(problem, style: const TextStyle(color: AppColors.amber)))
            else ...[
              AdminBars(title: 'Events created', days: s.series('events')),
              const SizedBox(height: 10),
              AdminBars(title: 'Sign ups for events', days: s.series('signups')),
              const SizedBox(height: 10),
              AdminBars(title: 'Discord reminders sent', days: s.series('reminders')),
              const SizedBox(height: 10),
              AdminBars(title: 'Reports added', days: s.series('reports')),
              const SizedBox(height: 10),
              AdminBars(title: 'Players by the day they last signed in', days: s.series('sign_ins')),
            ],
          ],
          secondary: [
            const Eyebrow('When each part last did something'),
            Panel(
              child: Column(
                children: [
                  for (final e in labels.entries)
                    AdminLine(e.value, s.at('latest', e.key) == null ? 'never' : ago(s.at('latest', e.key)!, now)),
                ],
              ),
            ),
            const Eyebrow('Queues and what the bot keeps'),
            Panel(
              child: Column(
                children: [
                  AdminLine('Message deletions waiting', '${s.count('queues', 'deletions_waiting')}'),
                  AdminLine('Event drafts open', '${s.count('queues', 'drafts')}'),
                  AdminLine('Events posted in Discord', '${s.count('queues', 'posted_events')}'),
                  AdminLine('Discord threads', '${s.count('queues', 'threads')}'),
                  AdminLine('Discord scheduled events', '${s.count('queues', 'scheduled_events')}'),
                  AdminLine('Role mappings', '${s.count('queues', 'role_mappings')}'),
                  AdminLine('Guild lists kept', '${s.count('queues', 'guild_parts')}'),
                ],
              ),
            ),
            const Eyebrow('News feeds'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AdminLine('Feeds set up', '${s.count('feeds', 'total')}'),
                  AdminLine('Failing', '${s.count('feeds', 'with_error')}',
                      valueColor: s.count('feeds', 'with_error') > 0 ? AppColors.amber : null),
                  for (final e in errors)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${e['guild']} · ${e['kind']}: ${feedProblemText('${e['error']}')}',
                        style: const TextStyle(fontSize: 12, color: AppColors.amber, height: 1.35),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ users and limits
