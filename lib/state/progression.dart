import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache.dart';
import '../util.dart';
import 'api.dart';

/// world bosses, daily crafts and map chests already done today.
/// needs the progression permission, empty when it is missing
final doneTodayProvider = FutureProvider.family<Set<String>, String>((ref, path) async {
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
  int get points => asInt(detail?['point_cap']);
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

/// how many achievements the game has, so the completed count has something
/// to sit against. the id list only changes with a patch
final achievementTotalProvider = FutureProvider<int>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final ids = await cachedList(cache, 'achievement_ids', 'ids', () => api.idList('/achievements'));
  return ids.length;
});

class MasteryRow {
  const MasteryRow(this.id, this.detail, this.level);
  final int id;
  final Json? detail;

  /// how many levels of this track are done
  final int level;

  String get name => (detail?['name'] as String?) ?? 'Mastery #$id';
  String get region => (detail?['region'] as String?) ?? '';
  int get total => ((detail?['levels'] as List?) ?? const []).length;
}

final masteriesProvider = FutureProvider<List<MasteryRow>>((ref) async {
  final api = accountApi(ref);
  final owned = await api.accountMasteries();
  final byId = {for (final m in owned) asInt(m['id']): asInt(m['level'])};
  final details = await api.masteries(byId.keys);
  final rows = [
    for (final e in byId.entries) MasteryRow(e.key, details[e.key], e.value + 1),
  ];
  rows.sort((a, b) => '${a.region}${a.name}'.compareTo('${b.region}${b.name}'));
  return rows;
});

/// mastery levels finished against the levels in the tracks you own
extension MasteryProgress on List<MasteryRow> {
  ({int done, int total}) get tally => (
        done: fold<int>(0, (n, m) => n + m.level),
        total: fold<int>(0, (n, m) => n + m.total),
      );
}

final masteryPointsProvider = FutureProvider<List<Json>>((ref) async {
  final raw = await accountApi(ref).masteryPoints();
  return ((raw['totals'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
});

class DailyProgress {
  const DailyProgress(this.done, this.total);
  final int done;
  final int total;
}

/// daily crafts and map chests: how many of today's are already collected
final dailyProgressProvider = FutureProvider.family<DailyProgress, String>((ref, path) async {
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
          if (p is Map)
            DungeonPath('${p['id']}', '${p['type'] ?? ''}', cleared.contains('${p['id']}')),
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
