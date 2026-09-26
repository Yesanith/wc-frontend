import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/periodic.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/vault_objectives.dart';
import 'vault_shop_screen.dart';

/// everything that resets at midnight utc on one page
class DailyScreen extends ConsumerWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final vault = ref.watch(vaultTrackProvider('daily'));
    final v = vault.valueOrNull;
    final bosses = ref.watch(doneTodayProvider('worldbosses')).valueOrNull;
    final crafts = ref.watch(dailyProgressProvider('dailycrafting')).valueOrNull;
    final chests = ref.watch(dailyProgressProvider('mapchests')).valueOrNull;
    final dungeons = ref.watch(dungeonsProvider).valueOrNull;

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [
        vaultTrackProvider,
        dailyAchievementsProvider,
        doneTodayProvider,
        dailyProgressProvider,
        dungeonsProvider,
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ResetBanner(label: s.t('daily_reset_in'), at: nextDailyReset()),
          const SizedBox(height: 20),
          PeriodicHeader(
            title: s.t('wizards_vault'),
            trailing: v == null ? null : '${v['meta_progress_current'] ?? 0}/${v['meta_progress_complete'] ?? 0}',
            onShop: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VaultShopScreen())),
          ),
          const SizedBox(height: 10),
          AsyncView(
            value: vault,
            permission: 'progression',
            onRetry: () => ref.invalidate(vaultTrackProvider('daily')),
            builder: (json) => VaultObjectives(json),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: s.t('daily_achievements')),
          const SizedBox(height: 10),
          AsyncView<List<PeriodicCategory>>(
            value: ref.watch(dailyAchievementsProvider),
            onRetry: () => ref.invalidate(dailyAchievementsProvider),
            builder: (cats) => cats.isEmpty
                ? Panel(child: Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted)))
                : Column(children: [for (final c in cats) PeriodicCategoryCard(category: c)]),
          ),
          const SizedBox(height: 22),
          SectionHeader(title: s.t('daily_checklist')),
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                ChecklistRow(
                  icon: Icons.schedule,
                  label: s.t('world_bosses'),
                  value: bosses == null ? null : '${bosses.length}',
                ),
                ChecklistRow(
                  icon: Icons.construction,
                  label: s.t('daily_crafts'),
                  value: crafts == null ? null : '${crafts.done}/${crafts.total}',
                  complete: crafts != null && crafts.total > 0 && crafts.done >= crafts.total,
                ),
                ChecklistRow(
                  icon: Icons.inventory_2_outlined,
                  label: s.t('map_chests'),
                  value: chests == null ? null : '${chests.done}/${chests.total}',
                  complete: chests != null && chests.total > 0 && chests.done >= chests.total,
                ),
                if (dungeons != null)
                  for (final d in dungeons)
                    if (d.done > 0)
                      ChecklistRow(
                        icon: Icons.castle_outlined,
                        label: d.label,
                        value: '${d.done}/${d.paths.length}',
                        complete: d.done >= d.paths.length,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// time left until the next reset
class ResetBanner extends StatelessWidget {
  const ResetBanner({super.key, required this.label, required this.at});

  final String label;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSoft))),
          Text(timeUntil(at), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.gold)),
        ],
      ),
    );
  }
}

/// a section title with the vault's meta progress and a way into the shop
class PeriodicHeader extends ConsumerWidget {
  const PeriodicHeader({super.key, required this.title, this.trailing, this.onShop});

  final String title;
  final String? trailing;
  final VoidCallback? onShop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final shop = onShop;
    return Row(
      children: [
        Expanded(child: SectionHeader(title: title, trailing: trailing)),
        if (shop != null)
          IconButton(
            tooltip: s.t('vault_shop'),
            visualDensity: VisualDensity.compact,
            onPressed: shop,
            icon: const Icon(Icons.storefront_outlined, color: AppColors.gold),
          ),
      ],
    );
  }
}

/// one rotating achievement category, each entry ticked when done
class PeriodicCategoryCard extends StatelessWidget {
  const PeriodicCategoryCard({super.key, required this.category});

  final PeriodicCategory category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(category.name, style: display(16))),
                Text('${category.done}/${category.rows.length}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
              ],
            ),
            const SizedBox(height: 4),
            for (final r in category.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(r.done ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18, color: r.done ? AppColors.green : AppColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: r.done ? AppColors.muted : AppColors.text,
                          )),
                    ),
                    if (!r.done && r.max > 0 && r.current > 0)
                      Text('${r.current}/${r.max}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// a line of the checklist: what it is and how far along
class ChecklistRow extends StatelessWidget {
  const ChecklistRow({super.key, required this.icon, required this.label, this.value, this.complete = false});

  final IconData icon;
  final String label;
  final String? value;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(complete ? Icons.check_circle : icon, size: 18, color: complete ? AppColors.green : AppColors.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Text(value ?? '…', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
        ],
      ),
    );
  }
}
