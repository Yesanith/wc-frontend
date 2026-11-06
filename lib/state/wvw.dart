import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'account.dart';
import 'api.dart';
import 'guilds.dart';

/// the team the account is assigned to. world vs world moved from worlds to
/// teams, older accounts may still only report a world
final wvwTeamProvider = FutureProvider<int>((ref) async {
  try {
    final wvw = await ref.watch(accountWvwProvider.future);
    final team = asInt(wvw['team'] ?? wvw['team_id']);
    if (team > 0) return team;
  } catch (_) {
    // fall back to the account object below
  }
  final account = await ref.watch(accountProvider.future);
  final nested = account['wvw'];
  final team = nested is Map ? asInt(nested['team_id'] ?? nested['team']) : 0;
  return team > 0 ? team : asInt(account['world']);
});

/// the live matchup of the account's team. never cached, it changes by the minute
final wvwMatchProvider = FutureProvider<Json?>((ref) async {
  final team = await ref.watch(wvwTeamProvider.future);
  if (team <= 0) return null;
  return ref.watch(gw2ApiProvider).wvwMatch(team);
});

/// old world ids are 1xxx in north america and 2xxx in europe, team ids
/// put the region in the second digit instead: 11xxx and 12xxx
String wvwRegion(int id) {
  final digits = '$id';
  final region = id >= 10000 && digits.length > 1 ? digits[1] : digits[0];
  return region == '2' ? 'eu' : 'na';
}

class WvwTimers {
  const WvwTimers(this.lockout, this.teamAssignment);
  final DateTime? lockout;
  final DateTime? teamAssignment;
}

final wvwTimersProvider = FutureProvider<WvwTimers>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final region = wvwRegion(await ref.watch(wvwTeamProvider.future));
  Future<DateTime?> read(String kind) async {
    try {
      final raw = await api.wvwTimer(kind);
      return DateTime.tryParse('${raw[region] ?? ''}')?.toLocal();
    } catch (_) {
      return null;
    }
  }

  final results = await Future.wait([read('lockout'), read('teamAssignment')]);
  return WvwTimers(results[0], results[1]);
});

/// which colour of the match the given team plays as
String? wvwColorOf(Json match, int team) {
  for (final key in ['all_worlds', 'worlds']) {
    final table = match[key];
    if (table is! Map) continue;
    for (final color in ['red', 'blue', 'green']) {
      final value = table[color];
      if (value is List && value.map(asInt).contains(team)) return color;
      if (value != null && asInt(value) == team) return color;
    }
  }
  return null;
}

/// the team each of the account's guilds is assigned to, by guild id
final wvwGuildTeamsProvider = FutureProvider<Map<String, int>>((ref) async {
  final team = await ref.watch(wvwTeamProvider.future);
  final ids = await ref.watch(guildIdsProvider.future);
  if (ids.isEmpty) return const {};
  final all = await ref.watch(gw2ApiProvider).wvwGuildTeams(wvwRegion(team));
  return {
    for (final id in ids)
      if (all[id.toUpperCase()] != null) id: all[id.toUpperCase()]!,
  };
});

/// names of the worlds fighting as [color] in a match, from all_worlds (or
/// worlds on older matches). ids the world list does not know are skipped
List<String> wvwWorldNames(Json match, String color, Map<int, String> worlds) {
  for (final key in ['all_worlds', 'worlds']) {
    final side = match[key];
    if (side is! Map) continue;
    final ids = side[color];
    final list = ids is List ? ids.map(asInt).toList() : [asInt(ids)];
    final names = [
      for (final id in list)
        if (worlds[id]?.isNotEmpty ?? false) worlds[id]!,
    ];
    if (names.isNotEmpty) return names;
  }
  return const [];
}

/// the id of the account's matchup, such as "2-1"
final wvwMatchIdProvider = FutureProvider<String?>((ref) async {
  final match = await ref.watch(wvwMatchProvider.future);
  final id = match?['id'];
  return id == null ? null : '$id';
});

Future<Json?> _matchPart(Ref ref, String part) async {
  final id = await ref.watch(wvwMatchIdProvider.future);
  return id == null ? null : ref.watch(gw2ApiProvider).wvwMatchPart(part, id);
}

/// who fights in the match and when it starts and ends
final wvwOverviewProvider = FutureProvider<Json?>((ref) => _matchPart(ref, 'overview'));

/// the score of the match and of every skirmish, per map
final wvwScoresProvider = FutureProvider<Json?>((ref) => _matchPart(ref, 'scores'));

/// kills and deaths of the match, per team and per map
final wvwStatsProvider = FutureProvider<Json?>((ref) => _matchPart(ref, 'stats'));

/// the best guilds of the account's team, [kind] is kdr or kills
final wvwTopProvider = FutureProvider.family<List<Json>, String>((ref, kind) async {
  final id = await ref.watch(wvwMatchIdProvider.future);
  final team = await ref.watch(wvwTeamProvider.future);
  if (id == null || team <= 0) return const [];
  return ref.watch(gw2ApiProvider).wvwTopGuilds(id, team, kind);
});

/// what one of the account's guilds did in the match, null without data
final wvwGuildStatsProvider = FutureProvider.family<Json?, String>((ref, guildId) async {
  final id = await ref.watch(wvwMatchIdProvider.future);
  return id == null ? null : ref.watch(gw2ApiProvider).wvwGuildStats(id, guildId);
});

/// kills per death, a team that has not died yet has its kills
double wvwKdr(int kills, int deaths) => deaths <= 0 ? kills.toDouble() : kills / deaths;

/// one skirmish of the match: its number and each colour's points
class WvwSkirmish {
  const WvwSkirmish(this.id, this.scores);
  final int id;
  final Map<String, int> scores;
}

/// the skirmishes of a scores answer, the newest first
List<WvwSkirmish> wvwSkirmishes(Json? scores) {
  final raw = scores?['skirmishes'];
  if (raw is! List) return const [];
  final list = [
    for (final s in raw.whereType<Map>())
      WvwSkirmish(asInt(s['id']), {
        for (final c in const ['red', 'blue', 'green']) c: s['scores'] is Map ? asInt((s['scores'] as Map)[c]) : 0,
      }),
  ]..sort((a, b) => b.id.compareTo(a.id));
  return list;
}

/// a row of a top list: a guild with the number the list is ranked by.
/// the game gives a guild id and, for some lists, its name and tag
class WvwTopRow {
  const WvwTopRow(this.guildId, this.name, this.tag, this.value);
  final String guildId;
  final String name;
  final String tag;

  /// kdr or kills, whichever the row carries, null when it carries neither
  final num? value;
}

WvwTopRow wvwTopRow(Json row) {
  final raw = row['kdr'] ?? row['kills'] ?? row['value'];
  return WvwTopRow(
      '${row['id'] ?? row['guild_id'] ?? ''}', '${row['name'] ?? ''}', '${row['tag'] ?? ''}', raw is num ? raw : null);
}
