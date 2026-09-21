import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/settings.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'trading_screen.dart';

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
              const Icon(Icons.chevron_right, color: Color(0xFF6E6859)),
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          title: Text(name, style: display(20)),
          bottom: AppTabBar(labels: [s.t('treasury'), s.t('stash'), s.t('log')]),
        ),
        body: TabBarView(
          children: [
            _TreasuryTab(id: id),
            _StashTab(id: id),
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
