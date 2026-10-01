import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/common.dart';
import '../../widgets/meters.dart';
import 'widgets.dart';

class AdminBotTab extends ConsumerWidget {
  const AdminBotTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<AdminHistory>(
      value: ref.watch(adminHistoryProvider),
      onRetry: () => ref.invalidate(adminHistoryProvider),
      builder: (h) {
        final now = DateTime.now();
        final used = h.top('discord', 'command:/');
        final other = [...h.top('discord', 'component:', limit: 5), ...h.top('discord', 'modal:', limit: 3)];
        final refused = h.top('discord', 'refused:');
        final broken = h.top('discord', 'rpc_error:');
        final linkErrors = h.top('gw2-link', 'error:');
        final servers = h.list('servers');
        return AdminTab(
          updated: h.generatedAt,
          onRefresh: () async {
            ref.invalidate(adminHistoryProvider);
            await ref.read(adminHistoryProvider.future);
          },
          primary: [
            const Eyebrow('Health'),
            AdminHealth(h.health(now)),
            const Eyebrow('Functions'),
            h.list('functions').isEmpty
                ? const Panel(
                    child: Text('No function has reported a run yet.', style: TextStyle(color: AppColors.muted)))
                : AdminHealth(h.functionLines(now)),
            const Eyebrow('Last 30 days'),
            AdminBars(title: 'Commands used', days: h.series('commands')),
            const SizedBox(height: 10),
            AdminBars(title: 'Buttons and forms used', days: h.series('buttons')),
            const SizedBox(height: 10),
            AdminBars(title: 'Bot calls that broke', days: h.series('bot_errors')),
            const SizedBox(height: 10),
            AdminBars(title: 'Game accounts linked', days: h.series('links_ok')),
            const SizedBox(height: 10),
            AdminBars(title: 'Linking that failed', days: h.series('links_failed')),
          ],
          secondary: [
            const Eyebrow('Most used'),
            _Counts(used, empty: 'No command has been used since the counters began.'),
            if (other.isNotEmpty) ...[const SizedBox(height: 10), _Counts(other, empty: '')],
            const Eyebrow('Refused'),
            _Counts(refused, empty: 'Nothing was refused.'),
            const Eyebrow('Broke'),
            _Counts([...broken, ...linkErrors], empty: 'Nothing broke.'),
            const Eyebrow('Discord servers'),
            _ServerStatus(servers, now),
          ],
        );
      },
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts(this.counts, {required this.empty});

  final List<({String key, int total})> counts;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return Panel(child: Text(empty, style: const TextStyle(color: AppColors.muted)));
    return Panel(
      child: Column(children: [for (final c in counts) AdminLine(c.key, fmtInt(c.total))]),
    );
  }
}

class _ServerStatus extends StatelessWidget {
  const _ServerStatus(this.servers, this.now);

  final List<Map<String, dynamic>> servers;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (servers.isEmpty)
      return const Panel(child: Text('No server is connected.', style: TextStyle(color: AppColors.muted)));
    return Panel(
      child: Column(
        children: [
          for (final s in servers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AdminDot(s['last_error'] == null ? HealthLevel.good : HealthLevel.warn),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${s['guild']}${'${s['tag'] ?? ''}'.isEmpty ? '' : ' [${s['tag']}]'}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      Text(
                        DateTime.tryParse('${s['roles_synced_at'] ?? ''}') == null
                            ? 'roles: never'
                            : 'roles ${ago(DateTime.parse('${s['roles_synced_at']}'), now)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.hint),
                      ),
                    ],
                  ),
                  if (s['last_error'] != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 19, top: 2),
                      child: Text(
                        '${s['last_error']}${DateTime.tryParse('${s['last_error_at'] ?? ''}') == null ? '' : ' · ${ago(DateTime.parse('${s['last_error_at']}'), now)}'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.amber, height: 1.35),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ guilds
