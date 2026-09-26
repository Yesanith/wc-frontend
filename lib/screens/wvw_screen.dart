import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/guilds.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../state/wvw.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';

const _teamColors = {
  'red': Color(0xFFE0605A),
  'blue': Color(0xFF5B9BE0),
  'green': Color(0xFF6CC070),
};

/// world vs world: the live matchup of the account's team, objectives per
/// map, and the rank and abilities reference
class WvwScreen extends ConsumerWidget {
  const WvwScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          AppTabBar(labels: [s.t('matchup'), s.t('objectives'), s.t('wvw_rank')]),
          const Expanded(
            child: TabBarView(
              children: [_MatchupTab(), _ObjectivesTab(), _RankTab()],
            ),
          ),
        ],
      ),
    );
  }
}

String _dateTime(DateTime d) =>
    '${d.day}.${d.month}. ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class _MatchupTab extends ConsumerWidget {
  const _MatchupTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final team = ref.watch(wvwTeamProvider).valueOrNull ?? 0;
    final timers = ref.watch(wvwTimersProvider).valueOrNull;
    final objectives = ref.watch(wvwObjectivesProvider).valueOrNull ?? const <String, Json>{};

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [wvwMatchProvider]),
      child: AsyncView<Json?>(
        value: ref.watch(wvwMatchProvider),
        onRetry: () => ref.invalidate(wvwMatchProvider),
        builder: (match) {
          if (match == null) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [Text(s.t('no_wvw_match'), style: const TextStyle(color: AppColors.muted))],
            );
          }
          final mine = wvwColorOf(match, team);
          Map<String, int> side(String key) {
            final m = match[key];
            return {
              for (final c in _teamColors.keys) c: m is Map ? asInt(m[c]) : 0,
            };
          }

          final victory = side('victory_points');
          final scores = side('scores');
          final kills = side('kills');
          final deaths = side('deaths');
          final maps = ((match['maps'] as List?) ?? const []).whereType<Map>().toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              for (final c in _teamColors.keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c == mine ? _teamColors[c]! : AppColors.line, width: c == mine ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Container(width: 10, height: 36, color: _teamColors[c]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c == mine ? '${s.t('team_$c')} · ${s.t('your_team')}' : s.t('team_$c'),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                s.t('kd_line', {'k': fmtInt(kills[c]!), 'd': fmtInt(deaths[c]!)}),
                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(fmtInt(victory[c]!),
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _teamColors[c])),
                            Text(s.t('score_n', {'n': fmtInt(scores[c]!)}),
                                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (timers != null && (timers.lockout != null || timers.teamAssignment != null)) ...[
                const SizedBox(height: 8),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (timers.lockout != null)
                        Text(s.t('wvw_lockout', {'d': _dateTime(timers.lockout!)}),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
                      if (timers.teamAssignment != null)
                        Text(s.t('wvw_relink', {'d': _dateTime(timers.teamAssignment!)}),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSoft)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SectionHeader(title: s.t('maps')),
              const SizedBox(height: 10),
              for (final map in maps) _MapCard(map: Map<String, dynamic>.from(map), objectives: objectives),
            ],
          );
        },
      ),
    );
  }
}

/// one borderland or the eternal battlegrounds: score and who holds what
class _MapCard extends ConsumerWidget {
  const _MapCard({required this.map, required this.objectives});

  final Json map;
  final Map<String, Json> objectives;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final held = {for (final c in _teamColors.keys) c: 0};
    for (final o in (map['objectives'] as List?) ?? const []) {
      if (o is! Map) continue;
      final owner = '${o['owner'] ?? ''}'.toLowerCase();
      if (held.containsKey(owner)) held[owner] = held[owner]! + 1;
    }
    final scores = map['scores'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.t('wvw_map_${'${map['type'] ?? ''}'.toLowerCase()}'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final c in _teamColors.keys) ...[
                  Container(
                      width: 8, height: 8, decoration: BoxDecoration(color: _teamColors[c], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('${held[c]}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Text(scores is Map ? fmtInt(asInt(scores[c])) : '',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(width: 14),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// every objective of the matchup with its owner and upgrade tier
class _ObjectivesTab extends ConsumerWidget {
  const _ObjectivesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final catalog = ref.watch(wvwObjectivesProvider).valueOrNull ?? const <String, Json>{};
    final upgrades = ref.watch(wvwUpgradesProvider).valueOrNull ?? const <String, Json>{};

    int tier(Json info, int yaks) {
      final upgrade = upgrades['${info['upgrade_id']}'];
      var t = 0;
      for (final step in (upgrade?['tiers'] as List?) ?? const []) {
        if (step is Map && yaks >= asInt(step['yaks_required'])) t++;
      }
      return t;
    }

    return AsyncView<Json?>(
      value: ref.watch(wvwMatchProvider),
      onRetry: () => ref.invalidate(wvwMatchProvider),
      builder: (match) {
        if (match == null) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(s.t('no_wvw_match'), style: const TextStyle(color: AppColors.muted)),
          );
        }
        final maps = ((match['maps'] as List?) ?? const []).whereType<Map>().toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            for (final map in maps) ...[
              SectionHeader(title: s.t('wvw_map_${'${map['type'] ?? ''}'.toLowerCase()}')),
              const SizedBox(height: 8),
              for (final o in ((map['objectives'] as List?) ?? const []).whereType<Map>())
                // camps, towers, keeps and castles, the rest are markers
                if (const {'Camp', 'Tower', 'Keep', 'Castle'}.contains('${o['type']}'))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _teamColors['${o['owner'] ?? ''}'.toLowerCase()] ?? AppColors.muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('${catalog['${o['id']}']?['name'] ?? o['id']}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Text('${o['type']}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        const SizedBox(width: 10),
                        if (catalog['${o['id']}'] != null)
                          Pill(s.t('tier_n', {'n': tier(catalog['${o['id']}']!, asInt(o['yaks_delivered']))})),
                        if (o['claimed_by'] != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.flag, size: 14, color: AppColors.gold),
                        ],
                      ],
                    ),
                  ),
              const SizedBox(height: 18),
            ],
          ],
        );
      },
    );
  }
}

/// the account's rank with its title, and the abilities reference
class _RankTab extends ConsumerWidget {
  const _RankTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final account = ref.watch(accountProvider).valueOrNull;
    final ranks = ref.watch(wvwRanksProvider).valueOrNull ?? const <Json>[];
    final rank = asInt(account?['wvw_rank'] ?? (account?['wvw'] is Map ? (account!['wvw'] as Map)['rank'] : 0));
    final title = wvwRankTitle(ranks, rank);

    return AsyncView<List<Json>>(
      value: ref.watch(wvwAbilitiesProvider),
      onRetry: () => ref.invalidate(wvwAbilitiesProvider),
      builder: (abilities) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Panel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('wvw_rank'), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      if (title != null && title.isNotEmpty) Text(title, style: display(18)),
                    ],
                  ),
                ),
                Text(fmtInt(rank),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.gold)),
              ],
            ),
          ),
          const _GuildTeams(),
          const SizedBox(height: 20),
          SectionHeader(title: s.t('wvw_abilities'), trailing: '${abilities.length}'),
          const SizedBox(height: 10),
          for (final a in abilities)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ItemRow(
                icon: a['icon'] as String?,
                title: '${a['name'] ?? ''}',
                subtitle: '${a['description'] ?? ''}',
                iconSize: 36,
                trailing: Text('${((a['ranks'] as List?) ?? const []).length}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
            ),
        ],
      ),
    );
  }
}


/// which wvw team each of the account's guilds plays for
class _GuildTeams extends ConsumerWidget {
  const _GuildTeams();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final teams = ref.watch(wvwGuildTeamsProvider).valueOrNull ?? const <String, int>{};
    final mine = ref.watch(wvwTeamProvider).valueOrNull ?? 0;
    if (teams.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: s.t('guild_teams')),
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final e in teams.entries) _GuildTeamRow(guildId: e.key, team: e.value, same: e.value == mine),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuildTeamRow extends ConsumerWidget {
  const _GuildTeamRow({required this.guildId, required this.team, required this.same});

  final String guildId;
  final int team;
  final bool same;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final guild = ref.watch(guildProvider(guildId)).valueOrNull;
    final tag = '${guild?['tag'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tag.isEmpty ? '${guild?['name'] ?? '…'}' : '${guild?['name'] ?? '…'} [$tag]',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(same ? s.t('your_team') : '#$team',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: same ? AppColors.green : AppColors.muted)),
        ],
      ),
    );
  }
}
