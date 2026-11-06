part of '../progression.dart';

class DailyProgress {
  const DailyProgress(this.done, this.total);
  final int done;
  final int total;
}

/// daily crafts and map chests: how many of today's are already collected
final dailyProgressProvider = FutureProvider.autoDispose.family<DailyProgress, String>((ref, path) async {
  ref.watch(periodRefreshProvider);
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
  ref.watch(periodRefreshProvider);
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
  ({int done, int total}) get tally =>
      (done: fold<int>(0, (n, w) => n + w.done), total: fold<int>(0, (n, w) => n + w.encounters.length));
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
  ({int done, int total}) get tally =>
      (done: fold<int>(0, (n, d) => n + d.done), total: fold<int>(0, (n, d) => n + d.paths.length));
}
