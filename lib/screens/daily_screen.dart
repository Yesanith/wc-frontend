import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/account.dart';
import '../state/periodic.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
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
        periodicAchievementsProvider,
        doneTodayProvider,
        dailyProgressProvider,
        dungeonsProvider,
      ]),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          ResetBanner(label: s.t('daily_reset_in'), at: nextDailyReset()),
          const SizedBox(height: 12),
          // the quick counters first, they fit on one screen
          _ChecklistGrid(
            tiles: [
              _Tile(Icons.schedule, s.t('world_bosses'), bosses == null ? null : '${bosses.length}', false),
              _Tile(Icons.construction, s.t('daily_crafts'), crafts == null ? null : '${crafts.done}/${crafts.total}',
                  crafts != null && crafts.total > 0 && crafts.done >= crafts.total),
              _Tile(Icons.inventory_2_outlined, s.t('map_chests'), chests == null ? null : '${chests.done}/${chests.total}',
                  chests != null && chests.total > 0 && chests.done >= chests.total),
              _Tile(Icons.castle_outlined, s.t('dungeon_paths'),
                  dungeons == null ? null : '${dungeons.fold<int>(0, (n, d) => n + d.done)}', false),
            ],
          ),
          const SizedBox(height: 12),
          FoldSection(
            title: s.t('wizards_vault'),
            summary: _vaultSummary(s, v),
            initiallyExpanded: !_vaultDone(v),
            trailing: IconButton(
              tooltip: s.t('vault_shop'),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VaultShopScreen())),
              icon: const Icon(Icons.storefront_outlined, color: AppColors.gold, size: 20),
            ),
            child: AsyncView(
              value: vault,
              permission: 'progression',
              onRetry: () => ref.invalidate(vaultTrackProvider('daily')),
              builder: (json) => VaultObjectives(json, framed: false),
            ),
          ),
          const SizedBox(height: 12),
          AsyncView<PeriodicAchievements>(
            value: ref.watch(periodicAchievementsProvider),
            onRetry: () => ref.invalidate(periodicAchievementsProvider),
            builder: (split) => Column(
              children: [
                for (final c in split.daily)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FoldSection(
                      title: c.name,
                      summary: c.done >= c.rows.length ? s.t('all_done') : '${c.done}/${c.rows.length}',
                      child: PeriodicCategoryList(category: c),
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

String? _vaultSummary(S s, Json? v) {
  if (v == null) return null;
  return _vaultDone(v) ? s.t('all_done') : '${v['meta_progress_current'] ?? 0}/${v['meta_progress_complete'] ?? 0}';
}

bool _vaultDone(Json? v) {
  if (v == null) return false;
  final total = asInt(v['meta_progress_complete']);
  return total > 0 && asInt(v['meta_progress_current']) >= total;
}

class _Tile {
  const _Tile(this.icon, this.label, this.value, this.complete);
  final IconData icon;
  final String label;
  final String? value;
  final bool complete;
}

/// small counters two to a row instead of a long list
class _ChecklistGrid extends StatelessWidget {
  const _ChecklistGrid({required this.tiles});

  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.6,
      children: [
        for (final t in tiles)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(t.complete ? Icons.check_circle : t.icon,
                    size: 18, color: t.complete ? AppColors.green : AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                      Text(t.value ?? '…', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// a titled panel that folds away, with a short summary kept in the header
class FoldSection extends StatelessWidget {
  const FoldSection({
    super.key,
    required this.title,
    required this.child,
    this.summary,
    this.trailing,
    this.initiallyExpanded = false,
  });

  final String title;
  final String? summary;
  final Widget? trailing;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final extra = trailing;
    final note = summary;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.only(left: 16, right: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          iconColor: AppColors.gold,
          collapsedIconColor: AppColors.muted,
          title: Row(
            children: [
              Expanded(child: Text(title, style: display(16), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (note != null)
                Text(note, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
              if (extra != null) extra,
            ],
          ),
          children: [child],
        ),
      ),
    );
  }
}

/// the entries of one rotating category, unfinished ones first
class PeriodicCategoryList extends StatelessWidget {
  const PeriodicCategoryList({super.key, required this.category});

  final PeriodicCategory category;

  @override
  Widget build(BuildContext context) {
    final rows = [...category.rows]..sort((a, b) => (a.done ? 1 : 0).compareTo(b.done ? 1 : 0));
    return Column(
      children: [
        for (final r in rows)
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
