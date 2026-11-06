part of '../guilds_screen.dart';

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
          return Padding(padding: const EdgeInsets.all(24), child: EmptyNote(s.t('nothing_here')));
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
                borderRadius: BorderRadius.circular(AppRadius.card),
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
                        Text(
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Bar(value: row.ratio, color: done ? AppColors.green : AppColors.gold),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    row.needed > 0 ? '${fmtInt(row.count)} / ${fmtInt(row.needed)}' : fmtInt(row.count),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: done ? AppColors.green : AppColors.gold,
                    ),
                  ),
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
          return Padding(padding: const EdgeInsets.all(24), child: EmptyNote(s.t('nothing_here')));
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
              GridView(
                gridDelegate: const AdaptiveGridDelegate(
                  minColumns: 8,
                  maxTile: 60,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
          return Padding(padding: const EdgeInsets.all(24), child: EmptyNote(s.t('nothing_here')));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: entries.length,
          separatorBuilder: (_, __) => Divider(color: AppColors.track, height: 16),
          itemBuilder: (context, i) {
            final entry = entries[i];
            final date = '${entry['time'] ?? ''}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_logLine(entry), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                const SizedBox(height: 2),
                Text(
                  date.length >= 10 ? date.substring(0, 10) : date,
                  style: TextStyle(fontSize: 11, color: AppColors.hint),
                ),
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

    // the game opens the member list only to the guild's leader, everybody else
    // reads what the leader's app shared of it
    final listed = ref.watch(guildMembersProvider(id));
    final refused = listed.error;
    if (refused is Gw2ApiException && (refused.status == 401 || refused.status == 403)) {
      return _SharedGuild(gw2Id: id);
    }

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
              for (final r in [...ranks]..sort((a, b) => asInt(a['order']).compareTo(asInt(b['order']))))
                _RankCard(rank: r, members: byRank['${r['id']}'] ?? 0),
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
                        Expanded(
                          child: Text('${t['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Text(
                          s.t('wins_losses', {
                            'w': asInt((t['aggregate'] as Map?)?['wins']),
                            'l': asInt((t['aggregate'] as Map?)?['losses']),
                          }),
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
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
                          ? Icon(Icons.person_outline, size: 18, color: AppColors.muted)
                          : CachedIcon(url: rankIcons['${m['rank']}']!, fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${m['name'] ?? ''}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text('${m['rank'] ?? ''}', style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
                    trailing: Text(
                      fmtInt(u.count),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
