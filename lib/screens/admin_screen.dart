import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/admin.dart';
import '../widgets/common.dart';
import 'admin/activity_tab.dart';
import 'admin/bot_tab.dart';
import 'admin/guilds_tab.dart';
import 'admin/history_tab.dart';
import 'admin/overview_tab.dart';
import 'admin/public_events_tab.dart';
import 'admin/server_tab.dart';
import 'admin/users_tab.dart';

/// the state of the backend for whoever runs it. the database gives these numbers to an administrator only
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // a number on the tab says how many public events wait for a look
    final waiting = ref.watch(adminOpenEventsProvider).valueOrNull?.waiting ?? 0;
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Backend'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(adminDashboardProvider);
                ref.invalidate(adminServerProvider);
                ref.invalidate(adminHistoryProvider);
                ref.invalidate(adminOpenEventsProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            AppTabBar(
              scrollable: true,
              labels: [
                'Overview',
                'Server',
                'Activity',
                'History',
                'Bot',
                'Guilds',
                waiting > 0 ? 'Public events ($waiting)' : 'Public events',
                'Users and limits',
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  AdminOverviewTab(),
                  AdminServerTab(),
                  AdminActivityTab(),
                  AdminHistoryTab(),
                  AdminBotTab(),
                  AdminGuildsTab(),
                  AdminPublicEventsTab(),
                  AdminUsersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
