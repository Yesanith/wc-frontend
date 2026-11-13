import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/account.dart';
import '../state/clock.dart';
import '../state/guilds.dart';
import '../state/reference.dart';
import '../state/settings.dart';
import '../state/wvw.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/clock.dart';
import '../widgets/common.dart';

const _teamColors = {
  'red': Color(0xFFE0605A),
  'blue': Color(0xFF5B9BE0),
  'green': Color(0xFF6CC070),
};

/// world vs world: the live matchup of the account's team, objectives per
/// map, statistics, and the rank and abilities reference
class WvwScreen extends ConsumerWidget {
  const WvwScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          AppTabBar(labels: [s.t('matchup'), s.t('objectives'), s.t('wvw_stats'), s.t('wvw_rank')]),
          const Expanded(
            child: TabBarView(
              children: [_MatchupTab(), _ObjectivesTab(), _StatsTab(), _RankTab()],
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
              children: [Text(s.t('no_wvw_match'), style: TextStyle(color: AppColors.muted))],
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
          // the worlds on each side, for matchups that still list them. team
          // ids have no name in the api and are left out
          final worlds = ref.watch(worldsProvider).valueOrNull ?? const <int, String>{};
          final population = ref.watch(worldPopulationProvider).valueOrNull ?? const <int, String>{};
          final worldNames = {
            for (final c in _teamColors.keys)
              c: wvwWorldNames(match, c, worlds,
                  extra: (id) => population[id] == null ? null : s.t('wvw_pop_${population[id]!.toLowerCase()}')),
          };

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
                      borderRadius: BorderRadius.circular(AppRadius.card),
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
                                style: TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                              if (worldNames[c]!.isNotEmpty)
                                Text(
                                  worldNames[c]!.join(', '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: AppColors.textSoft),
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
                                style: TextStyle(fontSize: 11, color: AppColors.muted)),
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
                            style: TextStyle(fontSize: 12, color: AppColors.textSoft)),
                      if (timers.teamAssignment != null)
                        Text(s.t('wvw_relink', {'d': _dateTime(timers.teamAssignment!)}),
                            style: TextStyle(fontSize: 12, color: AppColors.textSoft)),
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
                      style: TextStyle(fontSize: 11, color: AppColors.muted)),
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
            child: Text(s.t('no_wvw_match'), style: TextStyle(color: AppColors.muted)),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${catalog['${o['id']}']?['name'] ?? o['id']}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              _ObjectiveAge(o),
                            ],
                          ),
                        ),
                        Text('${o['type']}', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        const SizedBox(width: 10),
                        if (catalog['${o['id']}'] != null)
                          Pill(s.t('tier_n', {'n': tier(catalog['${o['id']}']!, asInt(o['yaks_delivered']))})),
                        if (o['claimed_by'] != null) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.flag, size: 14, color: AppColors.gold),
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

/// how long an objective has been held, the points it gives each tick, and for the first minutes after it changed hands the
/// time it is protected, which is five minutes in which it cannot be taken again
class _ObjectiveAge extends ConsumerWidget {
  const _ObjectiveAge(this.o);

  final Map o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final flipped = DateTime.tryParse('${o['last_flipped'] ?? ''}')?.toUtc();
    final tick = asInt(o['points_tick']);
    if (flipped == null && tick <= 0) return const SizedBox.shrink();
    return ClockBuilder(
      step: ClockStep.second,
      builder: (context, now) {
        final held = flipped == null ? null : now.toUtc().difference(flipped);
        final left = flipped == null ? Duration.zero : flipped.add(const Duration(minutes: 5)).difference(now.toUtc());
        final parts = [
          if (held != null && !held.isNegative) s.t('wvw_held', {'t': countdown(held)}),
          if (tick > 0) s.t('wvw_ppt', {'n': tick}),
        ];
        return Row(
          children: [
            Flexible(
              child: Text(parts.join(' · '), style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ),
            if (left > Duration.zero) ...[
              const SizedBox(width: 6),
              Pill(s.t('wvw_immune', {'t': countdown(left)})),
            ],
          ],
        );
      },
    );
  }
}

/// kills, deaths and score of the matchup in more detail than the matchup
/// tab: per team and per map, skirmish by skirmish, and the best guilds
class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final overview = ref.watch(wvwOverviewProvider).valueOrNull;
    final scores = ref.watch(wvwScoresProvider).valueOrNull;
    final stats = ref.watch(wvwStatsProvider).valueOrNull;
    final mine = ref.watch(wvwMatchProvider).valueOrNull;
    final team = ref.watch(wvwTeamProvider).valueOrNull ?? 0;
    final color = mine == null ? null : wvwColorOf(mine, team);
    final start = DateTime.tryParse('${overview?['start_time'] ?? ''}')?.toLocal();
    final end = DateTime.tryParse('${overview?['end_time'] ?? ''}')?.toLocal();
    final skirmishes = wvwSkirmishes(scores);

    Map<String, int> side(Json? from, String key) {
      final m = from?[key];
      return {for (final c in _teamColors.keys) c: m is Map ? asInt(m[c]) : 0};
    }

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: () => refreshProviders(ref, [
        wvwMatchProvider,
        wvwOverviewProvider,
        wvwScoresProvider,
        wvwStatsProvider,
        wvwTopProvider,
        wvwGuildStatsProvider,
      ]),
      child: AsyncView<Json?>(
        value: ref.watch(wvwMatchProvider),
        onRetry: () => ref.invalidate(wvwMatchProvider),
        builder: (match) {
          if (match == null) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [Text(s.t('no_wvw_match'), style: TextStyle(color: AppColors.muted))],
            );
          }
          final kills = side(stats ?? match, 'kills');
          final deaths = side(stats ?? match, 'deaths');
          final maps = ((stats?['maps'] ?? match['maps']) as List?)?.whereType<Map>().toList() ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (start != null && end != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(s.t('wvw_period', {'a': _dateTime(start), 'b': _dateTime(end)}),
                      style: TextStyle(fontSize: 12, color: AppColors.textSoft)),
                ),
              for (final c in _teamColors.keys)
                _KillsRow(
                  label: c == color ? '${s.t('team_$c')} · ${s.t('your_team')}' : s.t('team_$c'),
                  color: _teamColors[c]!,
                  kills: kills[c]!,
                  deaths: deaths[c]!,
                  highlight: c == color,
                ),
              if (maps.isNotEmpty) ...[
                const SizedBox(height: 20),
                SectionHeader(title: s.t('wvw_per_map')),
                const SizedBox(height: 10),
                for (final map in maps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.t('wvw_map_${'${map['type'] ?? ''}'.toLowerCase()}'),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          for (final c in _teamColors.keys)
                            _KillsRow(
                              compact: true,
                              label: s.t('team_$c'),
                              color: _teamColors[c]!,
                              kills: map['kills'] is Map ? asInt((map['kills'] as Map)[c]) : 0,
                              deaths: map['deaths'] is Map ? asInt((map['deaths'] as Map)[c]) : 0,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (skirmishes.isNotEmpty) ...[
                const SizedBox(height: 20),
                SectionHeader(title: s.t('wvw_skirmishes'), trailing: '${skirmishes.length}'),
                const SizedBox(height: 10),
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      for (final k in skirmishes.take(12))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(s.t('wvw_skirmish_n', {'n': k.id}),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              for (final c in _teamColors.keys)
                                SizedBox(
                                  width: 62,
                                  child: Text(fmtInt(k.scores[c]!),
                                      textAlign: TextAlign.end,
                                      style:
                                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _teamColors[c])),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _TopList(kind: 'kdr', title: s.t('wvw_top_kdr')),
              const SizedBox(height: 20),
              _TopList(kind: 'kills', title: s.t('wvw_top_kills')),
              const _GuildStats(),
            ],
          );
        },
      ),
    );
  }
}

/// one team's kills, deaths and kills per death
class _KillsRow extends ConsumerWidget {
  const _KillsRow({
    required this.label,
    required this.color,
    required this.kills,
    required this.deaths,
    this.highlight = false,
    this.compact = false,
  });

  final String label;
  final Color color;
  final int kills;
  final int deaths;
  final bool highlight;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final kdr = Text(s.t('wvw_kdr', {'n': wvwKdr(kills, deaths).toStringAsFixed(2)}),
        style: TextStyle(fontSize: compact ? 12 : 16, fontWeight: FontWeight.w800, color: color));
    final line = Text(s.t('kd_line', {'k': fmtInt(kills), 'd': fmtInt(deaths)}),
        style: TextStyle(fontSize: 11, color: AppColors.muted));
    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            line,
            const SizedBox(width: 12),
            SizedBox(width: 70, child: Align(alignment: Alignment.centerRight, child: kdr)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: highlight ? color : AppColors.line, width: highlight ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(width: 10, height: 36, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  line,
                ],
              ),
            ),
            kdr,
          ],
        ),
      ),
    );
  }
}

/// the best guilds of the account's team by kills per death or by kills.
/// the game keeps these lists empty for most of the week
class _TopList extends ConsumerWidget {
  const _TopList({required this.kind, required this.title});

  final String kind;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final rows = [for (final r in ref.watch(wvwTopProvider(kind)).valueOrNull ?? const <Json>[]) wvwTopRow(r)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          Text(s.t('wvw_top_empty'), style: TextStyle(fontSize: 12, color: AppColors.muted))
        else
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _TopRowView(rank: i + 1, row: rows[i], decimals: kind == 'kdr' ? 2 : 0),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopRowView extends ConsumerWidget {
  const _TopRowView({required this.rank, required this.row, required this.decimals});

  final int rank;
  final WvwTopRow row;
  final int decimals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // a list that gives only the guild id has its name looked up
    final guild = row.name.isEmpty && row.guildId.isNotEmpty ? ref.watch(guildProvider(row.guildId)).valueOrNull : null;
    final name = row.name.isNotEmpty ? row.name : '${guild?['name'] ?? '…'}';
    final tag = row.name.isNotEmpty ? row.tag : '${guild?['tag'] ?? ''}';
    final value = row.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 26, child: Text('$rank', style: TextStyle(fontSize: 12, color: AppColors.muted))),
          Expanded(
            child: Text(tag.isEmpty ? name : '$name [$tag]',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          if (value != null)
            Text(decimals == 0 ? fmtInt(value.round()) : value.toStringAsFixed(decimals),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold)),
        ],
      ),
    );
  }
}

/// what each of the account's guilds did in this match, when the game has
/// anything on them
class _GuildStats extends ConsumerWidget {
  const _GuildStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final guilds = ref.watch(wvwGuildTeamsProvider).valueOrNull ?? const <String, int>{};
    if (guilds.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: s.t('wvw_guild_stats')),
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(children: [for (final id in guilds.keys) _GuildStatsRow(guildId: id)]),
          ),
        ],
      ),
    );
  }
}

class _GuildStatsRow extends ConsumerWidget {
  const _GuildStatsRow({required this.guildId});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final guild = ref.watch(guildProvider(guildId)).valueOrNull;
    final stats = ref.watch(wvwGuildStatsProvider(guildId));
    final tag = '${guild?['tag'] ?? ''}';
    final name = tag.isEmpty ? '${guild?['name'] ?? '…'}' : '${guild?['name'] ?? '…'} [$tag]';
    final data = stats.valueOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          if (stats.isLoading)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          else if (data == null)
            Text(s.t('wvw_no_guild_data'), style: TextStyle(fontSize: 11, color: AppColors.muted))
          else
            Text(s.t('kd_line', {'k': fmtInt(asInt(data['kills'])), 'd': fmtInt(asInt(data['deaths']))}),
                style: TextStyle(fontSize: 11, color: AppColors.textSoft)),
        ],
      ),
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
                      Text(s.t('wvw_rank'), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      if (title != null && title.isNotEmpty) Text(title, style: display(18)),
                    ],
                  ),
                ),
                Text(fmtInt(rank), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.gold)),
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
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: same ? AppColors.green : AppColors.muted)),
        ],
      ),
    );
  }
}
