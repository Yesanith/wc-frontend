part of '../progression.dart';

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

  final rows = [for (final id in ids) MasteryRow(asInt(id), details[asInt(id)], owned[asInt(id)] ?? 0)];
  rows.sort((a, b) {
    final byRelease = masteryRegionRank(a.regionKey).compareTo(masteryRegionRank(b.regionKey));
    if (byRelease != 0) return byRelease;
    return asInt(a.detail?['order']).compareTo(asInt(b.detail?['order']));
  });
  return rows;
});

/// mastery levels finished against the levels in the tracks you own
extension MasteryProgress on List<MasteryRow> {
  ({int done, int total}) get tally =>
      (done: fold<int>(0, (n, m) => n + m.level), total: fold<int>(0, (n, m) => n + m.total));
}

/// spent and earned points per release, in the same order as the tracks
final masteryPointsProvider = FutureProvider<List<Json>>((ref) async {
  final raw = await accountApi(ref).masteryPoints();
  final totals = ((raw['totals'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  totals.sort((a, b) => masteryRegionRank('${a['region']}').compareTo(masteryRegionRank('${b['region']}')));
  return totals;
});
