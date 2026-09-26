import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/periodic.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/vault_objectives.dart';
import 'daily_screen.dart';
import 'vault_shop_screen.dart';

/// everything that resets on monday 07:30 utc, plus the vault's special track
class WeeklyScreen extends ConsumerWidget {
  const WeeklyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final weekly = ref.watch(vaultTrackProvider('weekly'));
    final special = ref.watch(vaultTrackProvider('special'));
    String? meta(Json? v) => v == null ? null : '${v['meta_progress_current'] ?? 0}/${v['meta_progress_complete'] ?? 0}';
    void openShop() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VaultShopScreen()));

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [vaultTrackProvider, raidsProvider]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ResetBanner(label: s.t('weekly_reset_in'), at: nextWeeklyReset()),
          const SizedBox(height: 20),
          PeriodicHeader(title: s.t('vault_weekly'), trailing: meta(weekly.valueOrNull), onShop: openShop),
          const SizedBox(height: 10),
          AsyncView(
            value: weekly,
            permission: 'progression',
            onRetry: () => ref.invalidate(vaultTrackProvider('weekly')),
            builder: (json) => VaultObjectives(json),
          ),
          const SizedBox(height: 22),
          PeriodicHeader(title: s.t('vault_special'), trailing: meta(special.valueOrNull)),
          const SizedBox(height: 10),
          AsyncView(
            value: special,
            permission: 'progression',
            onRetry: () => ref.invalidate(vaultTrackProvider('special')),
            builder: (json) => VaultObjectives(json),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: s.t('raids')),
          const SizedBox(height: 10),
          AsyncView<List<RaidWing>>(
            value: ref.watch(raidsProvider),
            permission: 'progression',
            onRetry: () => ref.invalidate(raidsProvider),
            builder: (wings) => Panel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (final w in wings)
                    ChecklistRow(
                      icon: Icons.shield_outlined,
                      label: w.label,
                      value: '${w.done}/${w.encounters.length}',
                      complete: w.encounters.isNotEmpty && w.done >= w.encounters.length,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
