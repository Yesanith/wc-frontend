import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/icon_cache.dart';
import '../state/guilds.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/coin_text.dart';
import '../widgets/common.dart';
import '../widgets/guild_emblem.dart';
import 'item_sheet.dart';

class GuildsScreen extends ConsumerWidget {
  const GuildsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final ids = ref.watch(guildIdsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(s.t('guilds_note'), style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)),
        const SizedBox(height: 12),
        AsyncView<List<String>>(
          value: ids,
          onRetry: () => ref.invalidate(guildIdsProvider),
          builder: (list) {
            if (list.isEmpty) {
              return Panel(child: Text(s.t('no_guilds'), style: const TextStyle(color: AppColors.muted)));
            }
            return Column(
              children: [
                for (final id in list)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: _GuildCard(id: id)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GuildCard extends ConsumerWidget {
  const _GuildCard({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guild = ref.watch(guildProvider(id)).valueOrNull;
    final name = (guild?['name'] as String?) ?? '...';
    final tag = (guild?['tag'] as String?) ?? '';

    return AppCard(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => GuildDetailScreen(id: id)),
    ),
             padding: const EdgeInsets.all(16),
             radius: 16,
             child: Row(
            children: [
              GuildEmblem(emblem: _emblemOf(guild), size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: display(18)),
                    if (tag.isNotEmpty)
                      Text('[$tag]', style: const TextStyle(fontSize: 13, color: AppColors.gold)),
                  ],
                ),
              ),
              if (asInt(guild?['level']) > 0)
                Text('${asInt(guild?['level'])}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.gold)),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.chevron),
            ],
          ),
           );
  }
}

class GuildDetailScreen extends ConsumerWidget {
  const GuildDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final guild = ref.watch(guildProvider(id)).valueOrNull;
    final name = (guild?['name'] as String?) ?? s.t('guild');

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          title: Text(name, style: display(20)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GuildEmblem(emblem: _emblemOf(guild), size: 36),
            ),
          ],
          bottom: AppTabBar(
            scrollable: true,
            labels: [s.t('treasury'), s.t('stash'), s.t('members'), s.t('upgrades_guild'), s.t('log')],
          ),
        ),
        body: TabBarView(
          children: [
            _TreasuryTab(id: id),
            _StashTab(id: id),
            _MembersTab(id: id),
            _UpgradesTab(id: id),
            _LogTab(id: id),
          ],
        ),
      ),
    );
  }
}

class _TreasuryTab extends ConsumerWidget {
  const _TreasuryTab({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final treasury = ref.watch(guildTreasuryProvider(id));

    return AsyncView<List<TreasuryRow>>(
      permission: 'guilds',
      restricted: s.t('guild_rank_needed'),
      value: treasury,
      onRetry: () => ref.invalidate(guildTreasuryProvider(id)),
      builder: (rows) {
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted))),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final row = rows[i];
            final done = row.needed > 0 && row.count >= row.needed;
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  ItemIcon(url: row.item?['icon'] as String?, rarity: row.item?['rarity'] as String?, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Bar(value: row.ratio, color: done ? AppColors.green : AppColors.gold),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(row.needed > 0 ? '${fmtInt(row.count)} / ${fmtInt(row.needed)}' : fmtInt(row.count),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: done ? AppColors.green : AppColors.gold)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StashTab extends ConsumerWidget {
  const _StashTab({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final stash = ref.watch(guildStashProvider(id));

    return AsyncView<List<GuildStashSlot>>(
      permission: 'guilds',
      restricted: s.t('guild_rank_needed'),
      value: stash,
      onRetry: () => ref.invalidate(guildStashProvider(id)),
      builder: (tabs) {
        if (tabs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted))),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            for (final tab in tabs) ...[
              Row(
                children: [
                  Expanded(child: Text(tab.tabName, style: display(17))),
                  if (tab.coins > 0) CoinText(tab.coins, size: 14),
                ],
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (final slot in tab.slots)
                    if (slot.id == 0)
                      const ItemIcon(empty: true)
                    else
                      GestureDetector(
                        onTap: () => showItemSheet(
                          context,
                          id: slot.id,
                          name: slot.name,
                          icon: slot.icon,
                          rarity: slot.rarity,
                          type: slot.type,
                          count: slot.count,
                        ),
                        child: ItemIcon(url: slot.icon, rarity: slot.rarity, count: slot.count),
                      ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ],
        );
      },
    );
  }
}

class _LogTab extends ConsumerWidget {
  const _LogTab({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final log = ref.watch(guildLogProvider(id));

    return AsyncView<List<Json>>(
      permission: 'guilds',
      restricted: s.t('guild_rank_needed'),
      value: log,
      onRetry: () => ref.invalidate(guildLogProvider(id)),
      builder: (entries) {
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text(s.t('nothing_here'), style: const TextStyle(color: AppColors.muted))),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(color: AppColors.track, height: 16),
          itemBuilder: (context, i) {
            final entry = entries[i];
            final date = '${entry['time'] ?? ''}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_logLine(entry),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                const SizedBox(height: 2),
                Text(date.length >= 10 ? date.substring(0, 10) : date,
                    style: const TextStyle(fontSize: 11, color: AppColors.hint)),
              ],
            );
          },
        );
      },
    );
  }
}

/// the log entries are typed records, turn them into one readable line
String _logLine(Json entry) {
  final type = titleCase('${entry['type'] ?? ''}');
  final user = '${entry['user'] ?? ''}';
  final parts = <String>[
    if (user.isNotEmpty) user,
    type,
    if (entry['item_id'] != null) 'x${asInt(entry['count'])}',
    if (entry['motd'] != null) '${entry['motd']}',
    if (entry['upgrade_id'] != null) '#${entry['upgrade_id']}',
  ];
  return parts.join(' · ');
}


Json? _emblemOf(Json? guild) => guild?['emblem'] is Map ? Map<String, dynamic>.from(guild!['emblem'] as Map) : null;

/// members with their rank, the rank list and the pvp teams
class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final ranks = ref.watch(guildRanksProvider(id)).valueOrNull ?? const <Json>[];
    final teams = ref.watch(guildTeamsProvider(id)).valueOrNull ?? const <Json>[];
    final rankIcons = {for (final r in ranks) '${r['id']}': r['icon'] as String?};

    return AsyncView<List<Json>>(
      permission: 'guilds',
      restricted: s.t('guild_rank_needed'),
      value: ref.watch(guildMembersProvider(id)),
      onRetry: () => ref.invalidate(guildMembersProvider(id)),
      builder: (members) {
        final byRank = <String, int>{};
        for (final m in members) {
          byRank['${m['rank']}'] = (byRank['${m['rank']}'] ?? 0) + 1;
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (ranks.isNotEmpty) ...[
              SectionHeader(title: s.t('ranks'), trailing: '${ranks.length}'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final r in ranks) Pill('${r['id']} · ${byRank['${r['id']}'] ?? 0}')],
              ),
              const SizedBox(height: 20),
            ],
            if (teams.isNotEmpty) ...[
              SectionHeader(title: s.t('pvp_teams'), trailing: '${teams.length}'),
              const SizedBox(height: 10),
              for (final t in teams)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(child: Text('${t['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
                        Text(
                          s.t('wins_losses', {
                            'w': asInt((t['aggregate'] as Map?)?['wins']),
                            'l': asInt((t['aggregate'] as Map?)?['losses']),
                          }),
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            SectionHeader(title: s.t('members'), trailing: '${members.length}'),
            const SizedBox(height: 10),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: rankIcons['${m['rank']}'] == null
                          ? const Icon(Icons.person_outline, size: 18, color: AppColors.muted)
                          : CachedIcon(url: rankIcons['${m['rank']}']!, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('${m['name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Text('${m['rank'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// what the guild hall has built, and what sits in the hall storage
class _UpgradesTab extends ConsumerWidget {
  const _UpgradesTab({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final storage = ref.watch(guildStorageProvider(id)).valueOrNull ?? const <GuildUpgradeRow>[];

    return AsyncView<List<GuildUpgradeRow>>(
      permission: 'guilds',
      restricted: s.t('guild_rank_needed'),
      value: ref.watch(guildBuiltUpgradesProvider(id)),
      onRetry: () => ref.invalidate(guildBuiltUpgradesProvider(id)),
      builder: (built) {
        final byType = <String, List<GuildUpgradeRow>>{};
        for (final u in built) {
          byType.putIfAbsent(u.type, () => []).add(u);
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            SectionHeader(title: s.t('built_upgrades'), trailing: '${built.length}'),
            const SizedBox(height: 10),
            for (final e in byType.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Kicker(titleCase(e.key.isEmpty ? '-' : e.key).toUpperCase()),
              ),
              for (final u in e.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ItemRow(icon: u.icon, title: u.name, iconSize: 32, titleLines: 1),
                ),
            ],
            if (storage.isNotEmpty) ...[
              const SizedBox(height: 18),
              SectionHeader(title: s.t('hall_storage'), trailing: '${storage.length}'),
              const SizedBox(height: 10),
              for (final u in storage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ItemRow(
                    icon: u.icon,
                    title: u.name,
                    iconSize: 32,
                    titleLines: 1,
                    trailing: Text(fmtInt(u.count),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold)),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
