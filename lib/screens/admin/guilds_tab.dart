import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/common.dart';
import '../../widgets/meters.dart';
import 'widgets.dart';

class AdminGuildsTab extends ConsumerWidget {
  const AdminGuildsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<AdminHistory>(
      value: ref.watch(adminHistoryProvider),
      onRetry: () => ref.invalidate(adminHistoryProvider),
      builder: (h) {
        final guilds = h.list('guilds');
        final now = DateTime.now();
        final read = guilds.where((g) => g['leader_read_at'] != null).length;
        final discord = guilds.where((g) => g['discord'] == true).length;
        final active = guilds.where((g) => asInt(g['events_30d']) > 0).length;
        return AdminTab(
          updated: h.generatedAt,
          onRefresh: () async {
            ref.invalidate(adminHistoryProvider);
            await ref.read(adminHistoryProvider.future);
          },
          primary: [
            const Eyebrow('Guilds'),
            AdminStatGrid(children: [
              AdminStat('Guilds', fmtInt(guilds.length), 'that use the app'),
              AdminStat('Read by a leader', fmtInt(read), 'the leader has opened the app'),
              AdminStat('With Discord', fmtInt(discord), 'a server is connected'),
              AdminStat('Made events', fmtInt(active), 'in the last 30 days'),
            ]),
            const SizedBox(height: 10),
            if (h.problem('guilds') != null)
              Panel(child: Text(h.problem('guilds')!, style: const TextStyle(color: AppColors.amber)))
            else
              _GuildList(guilds, now),
          ],
        );
      },
    );
  }
}

class _GuildList extends StatelessWidget {
  const _GuildList(this.guilds, this.now);

  final List<Map<String, dynamic>> guilds;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (guilds.isEmpty)
      return const Panel(child: Text('No guild uses the app yet.', style: TextStyle(color: AppColors.muted)));
    return Panel(
      child: Column(
        children: [
          for (final g in guilds)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${g['name']}${'${g['tag'] ?? ''}'.isEmpty ? '' : ' [${g['tag']}]'}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          [
                            '${g['members']} in the app${g['members_in_game'] == null ? '' : ' of ${g['members_in_game']}'}',
                            if (g['level'] != null) 'level ${g['level']}',
                            if (DateTime.tryParse('${g['leader_read_at'] ?? ''}') != null)
                              'read ${ago(DateTime.parse('${g['leader_read_at']}'), now)}'
                            else
                              'not read by a leader',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${asInt(g['events'])} events', style: const TextStyle(fontSize: 12, color: AppColors.gold)),
                      Text(
                        '${asInt(g['events_30d'])} in 30 d${g['discord'] == true ? ' · Discord' : ''}',
                        style: const TextStyle(fontSize: 11, color: AppColors.hint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
