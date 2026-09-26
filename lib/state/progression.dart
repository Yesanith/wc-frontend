import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache.dart';
import '../util.dart';
import 'api.dart';
import 'settings.dart';

/// world bosses, daily crafts and map chests already done today.
/// needs the progression permission, empty when it is missing
final doneTodayProvider = FutureProvider.autoDispose.family<Set<String>, String>((ref, path) async {
  final api = accountApi(ref);
  try {
    return (await api.get('/account/$path') as List).map((e) => '$e').toSet();
  } catch (_) {
    return <String>{};
  }
});

class AchievementRow {
  const AchievementRow(this.id, this.detail, this.current, this.max, this.done);
  final int id;
  final Json? detail;
  final int current;
  final int max;
  final bool done;

  String get name => (detail?['name'] as String?) ?? 'Achievement #$id';

  /// only repeatable achievements carry a point_cap, everything else adds up
  /// the points of its tiers
  int get points {
    final cap = asInt(detail?['point_cap']);
    if (cap > 0) return cap;
    var sum = 0;
    for (final t in (detail?['tiers'] as List?) ?? const []) {
      if (t is Map) sum += asInt(t['points']);
    }
    return sum;
  }

  double get ratio => max == 0 ? 0 : current / max;
}

/// achievements the account has started but not finished, most complete first
final achievementsProvider = FutureProvider<List<AchievementRow>>((ref) async {
  final api = accountApi(ref);
  final rows = await api.accountAchievements();
  final started = [
    for (final r in rows)
      if (r['done'] != true && asInt(r['current']) > 0) r,
  ];
  started.sort((a, b) {
    final ra = asInt(a['max']) == 0 ? 0.0 : asInt(a['current']) / asInt(a['max']);
    final rb = asInt(b['max']) == 0 ? 0.0 : asInt(b['current']) / asInt(b['max']);
    return rb.compareTo(ra);
  });
  final top = started.take(150).toList();
  final details = await api.achievements(top.map((r) => asInt(r['id'])));
  return [
    for (final r in top)
      AchievementRow(
        asInt(r['id']),
        details[asInt(r['id'])],
        asInt(r['current']),
        asInt(r['max']),
        r['done'] == true,
      ),
  ];
});

class AchievementSummary {
  const AchievementSummary(this.done, this.inProgress);

  final int done;

  /// started but not finished. the in progress list is capped for display,
  /// this is the real count
  final int inProgress;
}

/// both counts off the one account call the tab already makes
final achievementSummaryProvider = FutureProvider<AchievementSummary>((ref) async {
  final rows = await accountApi(ref).accountAchievements();
  var done = 0;
  var started = 0;
  for (final r in rows) {
    if (r['done'] == true) {
      done++;
    } else if (asInt(r['current']) > 0) {
      started++;
    }
  }
  return AchievementSummary(done, started);
});

class AchievementCategory {
  const AchievementCategory(this.id, this.name, this.icon, this.achievementIds);
  final int id;
  final String name;
  final String? icon;
  final List<int> achievementIds;
}

class AchievementGroup {
  const AchievementGroup(this.id, this.name, this.categories);
  final String id;
  final String name;
  final List<AchievementCategory> categories;

  int get achievementCount => categories.fold<int>(0, (n, c) => n + c.achievementIds.length);
}

/// the whole achievement catalogue, groups in game order with their
/// categories. static data, so it lives on disk for a month
final achievementCatalogueProvider = FutureProvider<List<AchievementGroup>>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);

  final groupRows = await cachedList(
    cache,
    'ach_groups_${lang.apiLang}',
    'rows',
    () async => api.details('/achievements/groups', await api.idList('/achievements/groups')),
  );
  final categoryRows = await cachedList(
    cache,
    'ach_categories_${lang.apiLang}',
    'rows',
    () async => api.details('/achievements/categories', await api.idList('/achievements/categories')),
  );

  final byId = <int, AchievementCategory>{};
  for (final raw in categoryRows.whereType<Map>()) {
    final c = Map<String, dynamic>.from(raw);
    final id = asInt(c['id']);
    byId[id] = AchievementCategory(
      id,
      '${c['name'] ?? ''}',
      c['icon'] as String?,
      // entries are {"id": n} objects, not bare ids
      [
        for (final a in (c['achievements'] as List?) ?? const []) asInt(a is Map ? a['id'] : a),
      ],
    );
  }

  final groups = <AchievementGroup>[];
  for (final raw in groupRows.whereType<Map>()) {
    final g = Map<String, dynamic>.from(raw);
    final categories = [
      for (final cid in (g['categories'] as List?) ?? const [])
        if (byId[asInt(cid)] != null) byId[asInt(cid)]!,
    ];
    if (categories.isEmpty) continue;
    groups.add(AchievementGroup('${g['id']}', '${g['name'] ?? ''}', categories));
  }
  groups.sort((a, b) => a.name.compareTo(b.name));
  return groups;
});

/// one category's achievements with this account's progress on each
final categoryAchievementsProvider = FutureProvider.family<List<AchievementRow>, int>((ref, categoryId) async {
  final api = accountApi(ref);
  final groups = await ref.watch(achievementCatalogueProvider.future);

  var ids = const <int>[];
  for (final g in groups) {
    for (final c in g.categories) {
      if (c.id == categoryId) ids = c.achievementIds;
    }
  }
  if (ids.isEmpty) return const [];

  final details = await api.achievements(ids);
  var progress = const <int, Json>{};
  try {
    progress = {for (final r in await api.accountAchievements()) asInt(r['id']): r};
  } catch (_) {
    // no progression permission: the catalogue still reads fine without it
  }

  return [
    for (final id in ids)
      AchievementRow(
        id,
        details[id],
        asInt(progress[id]?['current']),
        // without account progress the target is the last tier's count
        progress[id]?['max'] != null ? asInt(progress[id]?['max']) : _topTier(details[id]),
        progress[id]?['done'] == true,
      ),
  ];
});

/// the count the final tier asks for, which is what finishing it takes
int _topTier(Json? detail) {
  var top = 0;
  for (final t in (detail?['tiers'] as List?) ?? const []) {
    if (t is Map && asInt(t['count']) > top) top = asInt(t['count']);
  }
  return top;
}

/// how many achievements the game has, so the completed count has something
/// to sit against. the id list only changes with a patch
final achievementTotalProvider = FutureProvider<int>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final ids = await cachedList(cache, 'achievement_ids', 'ids', () => api.idList('/achievements'));
  return ids.length;
});

/// the api names a mastery region after the part of the world it belongs to,
/// the game groups the same tracks by the release that introduced them. the
/// order here is release order, which is how the hero panel lists them
const _masteryRegions = <String, String>{
  'Tyria': 'Central Tyria',
  'Maguuma': 'Heart of Thorns',
  'Desert': 'Path of Fire',
  'Tundra': 'Icebrood Saga',
  'Jade': 'End of Dragons',
  'Sky': 'Secrets of the Obscure',
  'Wild': 'Janthir Wilds',
  'Magic': 'Visions of Eternity',
};

/// the release name for an api mastery region, unchanged when a new one ships
/// before this table knows about it
String masteryRegionName(String apiRegion) => _masteryRegions[apiRegion] ?? apiRegion;

/// where a region sits in release order, unknown ones last
int masteryRegionRank(String apiRegion) {
  final index = _masteryRegions.keys.toList().indexOf(apiRegion);
  return index < 0 ? _masteryRegions.length : index;
}

class MasteryRow {
  const MasteryRow(this.id, this.detail, this.level);
  final int id;
  final Json? detail;

  /// how many levels of this track are done
  final int level;

  String get name => (detail?['name'] as String?) ?? 'Mastery #$id';

  /// the api's own region name, used for ordering
  String get regionKey => (detail?['region'] as String?) ?? '';

  /// the release the game files this track under
  String get region => masteryRegionName(regionKey);
  String get requirement => (detail?['requirement'] as String?) ?? '';
  List<Json> get levels => [
        for (final l in (detail?['levels'] as List?) ?? const [])
          if (l is Map) Map<String, dynamic>.from(l),
      ];
  int get total => levels.length;
  bool get started => level > 0;
}

/// every mastery track in the game, with how far this account took each one.
/// the account endpoint only names tracks you already started, so the
/// catalogue comes from the static list and the owned level is laid over it
final masteriesProvider = FutureProvider<List<MasteryRow>>((ref) async {
  final api = accountApi(ref);
  final ids = await api.idList('/masteries');
  final details = await api.masteries([for (final id in ids) asInt(id)]);

  var owned = const <int, int>{};
  try {
    // the level the api reports is the last one finished, counting from zero
    owned = {for (final m in await api.accountMasteries()) asInt(m['id']): asInt(m['level']) + 1};
  } catch (_) {
    // no progression permission: the catalogue is still worth showing
  }

  final rows = [
    for (final id in ids) MasteryRow(asInt(id), details[asInt(id)], owned[asInt(id)] ?? 0),
  ];
  rows.sort((a, b) {
    final byRelease = masteryRegionRank(a.regionKey).compareTo(masteryRegionRank(b.regionKey));
    if (byRelease != 0) return byRelease;
    return asInt(a.detail?['order']).compareTo(asInt(b.detail?['order']));
  });
  return rows;
});

/// mastery levels finished against the levels in the tracks you own
extension MasteryProgress on List<MasteryRow> {
  ({int done, int total}) get tally => (
        done: fold<int>(0, (n, m) => n + m.level),
        total: fold<int>(0, (n, m) => n + m.total),
      );
}

/// spent and earned points per release, in the same order as the tracks
final masteryPointsProvider = FutureProvider<List<Json>>((ref) async {
  final raw = await accountApi(ref).masteryPoints();
  final totals =
      ((raw['totals'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  totals.sort((a, b) => masteryRegionRank('${a['region']}').compareTo(masteryRegionRank('${b['region']}')));
  return totals;
});

class DailyProgress {
  const DailyProgress(this.done, this.total);
  final int done;
  final int total;
}

/// daily crafts and map chests: how many of today's are already collected
final dailyProgressProvider = FutureProvider.autoDispose.family<DailyProgress, String>((ref, path) async {
  final api = accountApi(ref);
  final all = await api.dailyAll(path);
  try {
    final done = await api.dailyDone(path);
    return DailyProgress(done.where(all.contains).length, all.length);
  } catch (_) {
    return DailyProgress(0, all.length);
  }
});

class RaidEncounter {
  const RaidEncounter(this.id, this.type, this.done);
  final String id;
  final String type;
  final bool done;

  String get label => titleCase(id);
}

class RaidWing {
  const RaidWing(this.id, this.encounters);
  final String id;
  final List<RaidEncounter> encounters;

  String get label => titleCase(id);
  int get done => encounters.where((e) => e.done).length;
}

/// raid wings with this week's clears marked
final raidsProvider = FutureProvider<List<RaidWing>>((ref) async {
  final api = accountApi(ref);
  final wings = await api.raidWings();
  Set<String> cleared;
  try {
    cleared = (await api.accountRaids()).toSet();
  } catch (_) {
    cleared = <String>{};
  }
  final out = <RaidWing>[];
  for (final raid in wings) {
    for (final wing in (raid['wings'] as List?) ?? const []) {
      if (wing is! Map) continue;
      final encounters = <RaidEncounter>[];
      for (final event in (wing['events'] as List?) ?? const []) {
        if (event is! Map) continue;
        final id = '${event['id']}';
        encounters.add(RaidEncounter(id, '${event['type'] ?? ''}', cleared.contains(id)));
      }
      out.add(RaidWing('${wing['id']}', encounters));
    }
  }
  return out;
});

/// encounters cleared this week against every encounter there is
extension RaidProgress on List<RaidWing> {
  ({int done, int total}) get tally => (
        done: fold<int>(0, (n, w) => n + w.done),
        total: fold<int>(0, (n, w) => n + w.encounters.length),
      );
}

class DungeonPath {
  const DungeonPath(this.id, this.type, this.done);
  final String id;
  final String type;
  final bool done;
}

class Dungeon {
  const Dungeon(this.id, this.paths);
  final String id;
  final List<DungeonPath> paths;

  String get label => titleCase(id);
  int get done => paths.where((p) => p.done).length;
}

/// dungeon paths, reset daily
final dungeonsProvider = FutureProvider<List<Dungeon>>((ref) async {
  final api = accountApi(ref);
  final all = await api.dungeons();
  Set<String> cleared;
  try {
    cleared = (await api.accountDungeons()).toSet();
  } catch (_) {
    cleared = <String>{};
  }
  return [
    for (final d in all)
      Dungeon('${d['id']}', [
        for (final p in (d['paths'] as List?) ?? const [])
          if (p is Map) DungeonPath('${p['id']}', '${p['type'] ?? ''}', cleared.contains('${p['id']}')),
      ]),
  ];
});

/// paths run today against every path there is
extension DungeonProgress on List<Dungeon> {
  ({int done, int total}) get tally => (
        done: fold<int>(0, (n, d) => n + d.done),
        total: fold<int>(0, (n, d) => n + d.paths.length),
      );
}

final pvpStatsProvider = FutureProvider<Json>((ref) => accountApi(ref).pvpStats());
