import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/progression.dart';
import '../state/pvp.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'achievements_screen.dart';
import 'pvp_screen.dart';

part 'progression/achievements_tab.dart';
part 'progression/masteries_tab.dart';
part 'progression/instances_tab.dart';
part 'progression/pvp_tab.dart';

class ProgressionScreen extends ConsumerWidget {
  const ProgressionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          AppTabBar(
            scrollable: true,
            labels: [s.t('achievements'), s.t('masteries'), s.t('instances'), s.t('pvp_wvw')],
          ),
          const Expanded(
            child: TabBarView(
              children: [_AchievementsTab(), _MasteriesTab(), _InstancesTab(), _PvpTab()],
            ),
          ),
        ],
      ),
    );
  }
}
