import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/account.dart';
import '../state/periodic.dart';
import '../state/progression.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../services/icon_cache.dart';
import '../widgets/stale_note.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/vault_objectives.dart';
import 'vault_objectives_screen.dart';

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
    // on the site the lists stand open, two side by side, as a checklist on a page does
    final site = SiteScope.of(context);
    final dailyStale = ref.watch(vaultStaleProvider('daily'));

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
              _Tile(
                  Icons.inventory_2_outlined,
                  s.t('map_chests'),
                  chests == null ? null : '${chests.done}/${chests.total}',
                  chests != null && chests.total > 0 && chests.done >= chests.total),
              _Tile(Icons.castle_outlined, s.t('dungeon_paths'),
                  dungeons == null ? null : '${dungeons.fold<int>(0, (n, d) => n + d.done)}', false),
            ],
          ),
          const SizedBox(height: 12),
          _Columns(two: site, children: [
            FoldSection(
              title: s.t('wizards_vault'),
              leading: const VaultIcon(),
              summary: dailyStale ? null : _vaultSummary(s, v),
              initiallyExpanded: dailyStale || !_vaultDone(v),
              trailing: const VaultHeaderActions(),
              child: AsyncView(
                value: vault,
                permission: 'progression',
                onRetry: () => ref.invalidate(vaultTrackProvider('daily')),
                builder: (json) =>
                    dailyStale ? const VaultAwaitingLogin(track: 'daily') : VaultObjectives(json, framed: false),
              ),
            ),
            ...?ref.watch(periodicAchievementsProvider).whenOrNull(
                  data: (split) => [
                    for (final c in split.daily)
                      FoldSection(
                        title: c.name,
                        leading: _GameIcon(url: c.icon),
                        summary: c.done >= c.rows.length ? s.t('all_done') : '${c.done}/${c.rows.length}',
                        initiallyExpanded: site && c.done < c.rows.length,
                        child: PeriodicCategoryList(category: c),
                      ),
                  ],
                ),
          ]),
          if (!ref.watch(periodicAchievementsProvider).hasValue)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AsyncView<PeriodicAchievements>(
                value: ref.watch(periodicAchievementsProvider),
                onRetry: () => ref.invalidate(periodicAchievementsProvider),
                builder: (_) => const SizedBox.shrink(),
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

/// the folding lists one under another, or on the site in two columns that fill side by side
class _Columns extends StatelessWidget {
  const _Columns({required this.two, required this.children});

  final bool two;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    Widget column(Iterable<Widget> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final w in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: w)],
        );
    if (!two) return column(children);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column([for (var i = 0; i < children.length; i += 2) children[i]])),
        const SizedBox(width: 20),
        Expanded(child: column([for (var i = 1; i < children.length; i += 2) children[i]])),
      ],
    );
  }
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
    return GridView(
      gridDelegate: AdaptiveGridDelegate(
        minColumns: 2,
        maxTile: 330,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        // on the site the counters are a short strip, not tiles to tap
        childAspectRatio: SiteScope.of(context) ? 4.8 : 2.6,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
                          style: TextStyle(fontSize: 11, color: AppColors.muted)),
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
    this.leading,
    this.initiallyExpanded = false,
  });

  final String title;

  /// an icon before the title, a game icon when the api has one
  final Widget? leading;
  final String? summary;
  final Widget? trailing;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final extra = trailing;
    final note = summary;
    final lead = leading;
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
              if (lead != null) ...[
                SizedBox(width: 26, height: 26, child: Center(child: lead)),
                const SizedBox(width: 10)
              ],
              Expanded(child: Text(title, style: display(16), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (note != null)
                Text(note, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.gold)),
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
                // the achievement's own icon, or its category's, with the tick over a corner
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: r.done ? 0.45 : 1,
                          child: _GameIcon(url: (r.detail?['icon'] as String?) ?? category.icon),
                        ),
                      ),
                      if (r.done)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Icon(Icons.check_circle, size: 14, color: AppColors.green),
                        ),
                    ],
                  ),
                ),
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
                  Text('${r.current}/${r.max}', style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
          Icon(Icons.hourglass_bottom, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppColors.textSoft))),
          Text(timeUntil(at), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.gold)),
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
          Text(value ?? '…', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// a game icon from the api, or a quiet placeholder when there is none
class _GameIcon extends StatelessWidget {
  const _GameIcon({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return Icon(Icons.emoji_events_outlined, size: 20, color: AppColors.gold);
    return ClipRRect(borderRadius: BorderRadius.circular(4), child: CachedIcon(url: u, fit: BoxFit.contain));
  }
}

/// the Astral Acclaim coin, the currency of the Wizard's Vault
class VaultIcon extends ConsumerWidget {
  const VaultIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(astralAcclaimIconProvider).valueOrNull;
    return url == null
        ? Icon(Icons.auto_awesome, size: 20, color: AppColors.gold)
        : CachedIcon(url: url, fit: BoxFit.contain);
  }
}

/// the api's own icon for a game category, used by the weekly page too
class GameIcon extends StatelessWidget {
  const GameIcon({super.key, this.url});

  final String? url;

  @override
  Widget build(BuildContext context) => _GameIcon(url: url);
}
