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
          for (final e in ((raw['attributes'] as Map?) ?? const {}).entries)
            attributeName('${e.key}'): asInt(e.value),
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


/// the top of a season's ladder. key is "seasonId|region", region na or eu
final pvpLadderProvider = FutureProvider.family<List<Json>, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length != 2 || parts[0].isEmpty) return const [];
  final rows = await ref.watch(gw2ApiProvider).pvpLadder(parts[0], parts[1]);
  rows.sort((a, b) => asInt(a['rank']).compareTo(asInt(b['rank'])));
  return rows;
});
