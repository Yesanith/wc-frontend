import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/admin.dart';
import '../../theme.dart';
import '../../util.dart';
import '../../widgets/common.dart';
import '../../widgets/meters.dart';
import 'widgets.dart';

class AdminUsersTab extends ConsumerWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<AdminServer>(
      value: ref.watch(adminServerProvider),
      onRetry: () => ref.invalidate(adminServerProvider),
      builder: (s) {
        final size = s.count('server', 'size_bytes');
        final monthly = s.count('auth', 'signed_in_30d');
        final providers = s.map('auth', 'by_provider');
        return AdminTab(
          updated: s.generatedAt,
          onRefresh: () async {
            ref.invalidate(adminServerProvider);
            await ref.read(adminServerProvider.future);
          },
          primary: [
            const Eyebrow('The free plan'),
            AdminLimitBar('Database', size, freeDatabaseBytes, formatBytes(size), formatBytes(freeDatabaseBytes)),
            const SizedBox(height: 10),
            AdminLimitBar(
                'Users who signed in this month', monthly, freeMonthlyUsers, fmtInt(monthly), fmtInt(freeMonthlyUsers)),
            Padding(
              padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                'Traffic, file storage and function calls are counted by Supabase and shown on its dashboard, not in the database.',
                style: TextStyle(fontSize: 12, color: AppColors.hint, height: 1.4),
              ),
            ),
          ],
          secondary: [
            const Eyebrow('Sign in'),
            AdminStatGrid(children: [
              AdminStat('Accounts', fmtInt(s.count('auth', 'users')), 'that can sign in'),
              AdminStat('Today', fmtInt(s.count('auth', 'signed_in_24h')), 'signed in'),
              AdminStat('This week', fmtInt(s.count('auth', 'signed_in_7d')), 'signed in'),
              AdminStat('This month', fmtInt(monthly), 'signed in'),
            ]),
            const Eyebrow('By provider'),
            Panel(
              child: Column(
                children: [
                  if (providers.isEmpty) Text('None.', style: TextStyle(color: AppColors.muted)),
                  for (final e in providers.entries) AdminLine(e.key, fmtInt(asInt(e.value))),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
