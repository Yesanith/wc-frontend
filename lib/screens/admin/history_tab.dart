import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/common.dart';
import '../../widgets/meters.dart';
import 'widgets.dart';

/// the numbers of each day, kept, so that how they grow is seen
class AdminHistoryTab extends ConsumerWidget {
  const AdminHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<AdminHistory>(
      value: ref.watch(adminHistoryProvider),
      onRetry: () => ref.invalidate(adminHistoryProvider),
      builder: (h) {
        List<({String day, int count})> last30(String field) => tail(h.snapshotSeries(field), 30);
        String now(List<int> v) => v.isEmpty ? '' : 'now ${fmtInt(v.last)}';
        final days = h.daysToDatabaseLimit;
        final problem = h.problem('snapshots');
        final mb = tail(h.databaseMegabytes, 30);
        return AdminTab(
          updated: h.generatedAt,
          onRefresh: () async {
            ref.invalidate(adminHistoryProvider);
            await ref.read(adminHistoryProvider.future);
          },
          primary: [
            const Eyebrow('Players'),
            if (problem != null)
              Panel(child: Text(problem, style: const TextStyle(color: AppColors.amber)))
            else ...[
              AdminBars(title: 'Players', days: last30('users'), summary: now),
              const SizedBox(height: 10),
              AdminBars(title: 'Active in a day', days: last30('active_24h'), summary: now),
              const SizedBox(height: 10),
              AdminBars(title: 'Active in a month', days: last30('active_30d'), summary: now),
              const SizedBox(height: 10),
              AdminBars(title: 'Devices with notifications', days: last30('devices'), summary: now),
            ],
          ],
          secondary: [
            const Eyebrow('What they use'),
            if (problem == null) ...[
              AdminBars(title: 'Game accounts', days: last30('gw2_accounts'), summary: now),
              const SizedBox(height: 10),
              AdminBars(title: 'Guilds', days: last30('guilds'), summary: now),
              const SizedBox(height: 10),
              AdminBars(title: 'Guilds read by a leader', days: last30('guilds_read'), summary: now),
              const SizedBox(height: 10),
              AdminBars(title: 'Discord servers', days: last30('discord_servers'), summary: now),
              const SizedBox(height: 10),
              AdminBars(title: 'Events to come', days: last30('events_upcoming'), summary: now),
            ],
            const Eyebrow('App versions this week'),
            AdminVersions(h),
            const Eyebrow('Database'),
            if (problem == null) ...[
              AdminBars(
                  title: 'Size in megabytes',
                  days: mb,
                  summary: (v) => v.isEmpty ? '' : 'now ${v.last} MB of ${freeDatabaseBytes ~/ 1048576}'),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  days == null
                      ? 'Not enough days yet, or not growing, to say when it fills.'
                      : (days == 0
                          ? 'It has reached the limit of the free plan.'
                          : 'At this rate it reaches the limit of the free plan in about ${fmtInt(days)} days.'),
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: days != null && days < 60 ? AppColors.amber : AppColors.hint),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ the bot
