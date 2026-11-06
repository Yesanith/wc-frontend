import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache.dart';
import '../util.dart';
import 'api.dart';
import 'maps.dart';
import 'settings.dart';

/// one of the nine rank tiers, Rabbit through Dragon
class PvpRank {
  const PvpRank(this.name, this.icon, this.minRank, this.maxRank);
  final String name;
  final String? icon;
  final int minRank;
  final int maxRank;
}

/// the tier a pvp rank falls in. the last tier has no real ceiling, so
/// anything above the highest floor belongs to it
PvpRank? rankTierFor(List<PvpRank> tiers, int pvpRank) {
  PvpRank? best;
  for (final tier in tiers) {
    if (pvpRank >= tier.minRank && (best == null || tier.minRank > best.minRank)) {
      best = tier;
    }
  }
  return best;
}

final pvpRanksProvider = FutureProvider<List<PvpRank>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);
  final rows = await cachedList(cache, 'pvp_ranks_${lang.apiLang}', 'rows', () => api.pvpRanks());
  final tiers = [
    for (final raw in rows.whereType<Map>())
      PvpRank(
        '${raw['name'] ?? ''}',
        raw['icon'] as String?,
        asInt(raw['min_rank']),
        asInt(raw['max_rank']),
      ),
  ];
  tiers.sort((a, b) => a.minRank.compareTo(b.minRank));
  return tiers;
});

class PvpAmulet {
  const PvpAmulet(this.id, this.name, this.icon, this.attributes);
  final int id;
  final String name;
  final String? icon;

  /// attribute name to value, already using the names the game shows
  final Map<String, int> attributes;
}

final pvpAmuletsProvider = FutureProvider<List<PvpAmulet>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);
  final rows = await cachedList(cache, 'pvp_amulets_${lang.apiLang}', 'rows', () => api.pvpAmulets());
  final out = [
    for (final raw in rows.whereType<Map>())
      PvpAmulet(
        asInt(raw['id']),
        '${raw['name'] ?? ''}',
        raw['icon'] as String?,
        {
          for (final e in ((raw['attributes'] as Map?) ?? const {}).entries) attributeName('${e.key}'): asInt(e.value),
        },
      ),
  ];
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
});

/// one match from the history the api keeps
class PvpGame {
  const PvpGame({
    required this.id,
    required this.mapName,
    required this.profession,
    required this.result,
    required this.team,
    required this.ownScore,
    required this.otherScore,
    required this.ratingType,
    required this.ratingChange,
    required this.ended,
  });

  final String id;
  final String mapName;
  final String profession;

  /// Victory or Defeat as the api spells it
  final String result;
  final String team;
  final int ownScore;
  final int otherScore;
  final String ratingType;
  final int ratingChange;
  final DateTime? ended;

  bool get won => result.toLowerCase() == 'victory';
}

/// recent matches, newest first, with the map resolved to its name
final pvpGamesProvider = FutureProvider<List<PvpGame>>((ref) async {
  final api = accountApi(ref);
  final rows = await api.pvpGames();
  if (rows.isEmpty) return const [];

  // the match only carries a map id, the names come from the map list
  var names = const <int, String>{};
  try {
    final maps = await ref.watch(mapsProvider.future);
    names = {for (final m in maps) m.id: m.name};
  } catch (_) {
    // a missing map list only costs the label
  }

  final games = <PvpGame>[];
  for (final raw in rows) {
    final team = '${raw['team'] ?? ''}'.toLowerCase();
    final scores = (raw['scores'] as Map?) ?? const {};
    final mapId = asInt(raw['map_id']);
    games.add(PvpGame(
      id: '${raw['id'] ?? ''}',
      mapName: names[mapId] ?? 'Map #$mapId',
      profession: titleCase('${raw['profession'] ?? ''}'),
      result: '${raw['result'] ?? ''}',
      team: titleCase(team),
      ownScore: asInt(scores[team]),
      otherScore: asInt(scores[team == 'red' ? 'blue' : 'red']),
      ratingType: '${raw['rating_type'] ?? ''}',
      ratingChange: asInt(raw['rating_change']),
      ended: DateTime.tryParse('${raw['ended'] ?? ''}'),
    ));
  }
  games.sort((a, b) {
    final at = a.ended, bt = b.ended;
    if (at == null || bt == null) return 0;
    return bt.compareTo(at);
  });
  return games;
});

/// where the account stands in a league season
class PvpStanding {
  const PvpStanding({
    required this.seasonId,
    required this.seasonName,
    required this.divisionName,
    required this.tier,
    required this.points,
    required this.rating,
    required this.totalPoints,
  });

  final String seasonId;
  final String seasonName;
  final String divisionName;
  final int tier;
  final int points;
  final int rating;
  final int totalPoints;
}

/// the standing for the most recent season the account played
final pvpStandingProvider = FutureProvider<PvpStanding?>((ref) async {
  final api = accountApi(ref);
  final rows = await api.pvpStandings();
  if (rows.isEmpty) return null;

  // the api lists seasons oldest first, the last one is the current run
  final raw = rows.last;
  final current = (raw['current'] as Map?) ?? const {};
  final seasonId = '${raw['season_id'] ?? ''}';

  var seasonName = '';
  var divisionName = '';
  final divisionIndex = asInt(current['division']);
  try {
    final season = await api.pvpSeason(seasonId);
    seasonName = '${season?['name'] ?? ''}';
    final divisions = (season?['divisions'] as List?) ?? const [];
    if (divisionIndex >= 0 && divisionIndex < divisions.length) {
      final d = divisions[divisionIndex];
      if (d is Map) divisionName = '${d['name'] ?? ''}';
    }
  } catch (_) {
    // the season lookup is decoration, the numbers still stand on their own
  }

  return PvpStanding(
    seasonId: seasonId,
    seasonName: seasonName,
    divisionName: divisionName,
    tier: asInt(current['tier']),
    points: asInt(current['points']),
    rating: asInt(current['rating']),
    totalPoints: asInt(current['total_points']),
  );
});

/// every league season, newest first. a day on disk is enough, a season
/// only changes when one starts or ends
final pvpSeasonsProvider = FutureProvider<List<Json>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);
  final raw = await cachedList(cache, 'pvp_seasons_${lang.apiLang}', 'rows', () => api.pvpSeasons(),
      maxAge: const Duration(days: 1));
  final rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  rows.sort((a, b) => '${b['start'] ?? ''}'.compareTo('${a['start'] ?? ''}'));
  return rows;
});

/// the boards one season keeps, ladder first
final pvpBoardsProvider = FutureProvider.autoDispose.family<List<String>, String>((ref, seasonId) async {
  if (seasonId.isEmpty) return const [];
  final boards = await ref.watch(gw2ApiProvider).pvpBoards(seasonId);
  return sortBoards(boards);
});

/// ladder first, then the rest in a fixed order
List<String> sortBoards(List<String> boards) {
  const order = ['ladder', 'legendary', 'guild'];
  int rank(String b) {
    final i = order.indexOf(b);
    return i < 0 ? order.length : i;
  }

  return [...boards]..sort((a, b) => rank(a) == rank(b) ? a.compareTo(b) : rank(a).compareTo(rank(b)));
}

/// one row of a leaderboard: who, where and every score with its name
class BoardRow {
  const BoardRow(this.rank, this.name, this.scores);
  final int rank;
  final String name;

  /// (label, value) pairs in the order the season lists its scorings
  final List<(String, int)> scores;
}

/// turns raw board rows into [BoardRow]s, naming every score with the
/// scoring the season defines for that board
List<BoardRow> boardRows(List<Json> rows, Json? season, String board) {
  final boardInfo = season?['leaderboards'] is Map ? (season!['leaderboards'] as Map)[board] : null;
  final scorings = <String, String>{
    for (final sc in (boardInfo is Map ? boardInfo['scorings'] as List? : null) ?? const [])
      if (sc is Map) '${sc['id']}': '${sc['name'] ?? sc['description'] ?? ''}',
  };
  final out = [
    for (final r in rows)
      BoardRow(
        asInt(r['rank']),
        // guild boards name the guild and the team that played
        r['team'] != null && r['name'] != null && r['team'] != r['name']
            ? '${r['name']} · ${r['team']}'
            : '${r['name'] ?? r['team'] ?? r['id'] ?? ''}',
        [
          for (final sc in (r['scores'] as List?) ?? const [])
            if (sc is Map) (scorings['${sc['id']}'] ?? '', asInt(sc['value'])),
        ],
      ),
  ];
  out.sort((a, b) => a.rank.compareTo(b.rank));
  return out;
}

/// one board of a season. key is "seasonId|board|region", region na or eu
final pvpLeaderboardProvider = FutureProvider.autoDispose.family<List<BoardRow>, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length != 3 || parts[0].isEmpty) return const [];
  final api = ref.watch(gw2ApiProvider);
  final seasons = await ref.watch(pvpSeasonsProvider.future);
  Json? season;
  for (final s in seasons) {
    if ('${s['id']}' == parts[0]) season = s;
  }
  final rows = await api.pvpLeaderboard(parts[0], parts[1], parts[2]);
  return boardRows(rows, season, parts[1]);
});
