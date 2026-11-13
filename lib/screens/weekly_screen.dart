import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/periodic.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/stale_note.dart';
import '../widgets/common.dart';
import '../widgets/vault_objectives.dart';
import 'vault_objectives_screen.dart';
import 'daily_screen.dart';

/// everything that resets on monday 07:30 utc, plus the vault's special track
class WeeklyScreen extends ConsumerWidget {
  const WeeklyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final weekly = ref.watch(vaultTrackProvider('weekly'));
    final special = ref.watch(vaultTrackProvider('special'));
    final raids = ref.watch(raidsProvider).valueOrNull;
    String? meta(Json? v) =>
        v == null ? null : '${v['meta_progress_current'] ?? 0}/${v['meta_progress_complete'] ?? 0}';
    final weeklyStale = ref.watch(vaultStaleProvider('weekly'));

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [vaultTrackProvider, raidsProvider, periodicAchievementsProvider]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ResetBanner(label: s.t('weekly_reset_in'), at: nextWeeklyReset()),
          const SizedBox(height: 12),
          FoldSection(
            title: s.t('vault_weekly'),
            leading: const VaultIcon(),
            summary: weeklyStale ? null : meta(weekly.valueOrNull),
            initiallyExpanded: true,
            trailing: const VaultHeaderActions(),
            child: AsyncView(
              value: weekly,
              permission: 'progression',
              onRetry: () => ref.invalidate(vaultTrackProvider('weekly')),
              builder: (json) =>
                  weeklyStale ? const VaultAwaitingLogin(track: 'weekly') : VaultObjectives(json, framed: false),
            ),
          ),
          const SizedBox(height: 12),
          FoldSection(
            title: s.t('vault_special'),
            leading: const VaultIcon(),
            summary: meta(special.valueOrNull),
            child: AsyncView(
              value: special,
              permission: 'progression',
              onRetry: () => ref.invalidate(vaultTrackProvider('special')),
              builder: (json) => VaultObjectives(json, framed: false),
            ),
          ),
          const SizedBox(height: 12),
          // weekly achievements that rotate alongside the dailies
          ...[
            for (final c in ref.watch(periodicAchievementsProvider).valueOrNull?.weekly ?? const <PeriodicCategory>[])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FoldSection(
                  title: c.name,
                  leading: GameIcon(url: c.icon),
                  summary: c.done >= c.rows.length ? s.t('all_done') : '${c.done}/${c.rows.length}',
                  child: PeriodicCategoryList(category: c),
                ),
              ),
          ],
          FoldSection(
            title: s.t('raids'),
            leading: Icon(Icons.shield_outlined, size: 20, color: AppColors.gold),
            summary: raids == null
                ? null
                : '${raids.fold<int>(0, (n, w) => n + w.done)}/${raids.fold<int>(0, (n, w) => n + w.encounters.length)}',
            child: AsyncView<List<RaidWing>>(
              value: ref.watch(raidsProvider),
              permission: 'progression',
              onRetry: () => ref.invalidate(raidsProvider),
              builder: (wings) => Column(
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
