import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache.dart';
import '../util.dart';
import 'api.dart';
import 'settings.dart';

/// a whole static endpoint, kept on disk for a month per language
Future<List<Json>> _static(Ref ref, String name, String path) async {
  final api = ref.watch(gw2ApiProvider);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);
  final rows = await cachedList(cache, 'ref_${name}_${lang.apiLang}', 'rows', () => api.allOf(path));
  return rows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

Map<String, Json> _byId(List<Json> rows) => {for (final r in rows) '${r['id']}': r};

// -------------------------------------------------------------------------
// items

/// stat combination names, e.g. 161 -> "Berserker's"
final itemStatsProvider = FutureProvider<Map<int, String>>((ref) async {
  final rows = await _static(ref, 'itemstats', '/itemstats');
  return {
    for (final r in rows)
      if ('${r['name'] ?? ''}'.trim().isNotEmpty) asInt(r['id']): '${r['name']}'.trim(),
  };
});

/// material storage categories in game order
final materialCategoriesProvider = FutureProvider<List<Json>>((ref) async {
  final rows = await _static(ref, 'materials', '/materials');
  rows.sort((a, b) => asInt(a['order']).compareTo(asInt(b['order'])));
  return rows;
});

// -------------------------------------------------------------------------
// world vs world

final wvwObjectivesProvider =
    FutureProvider<Map<String, Json>>((ref) async => _byId(await _static(ref, 'wvw_objectives', '/wvw/objectives')));

final wvwRanksProvider = FutureProvider<List<Json>>((ref) async {
  final rows = await _static(ref, 'wvw_ranks', '/wvw/ranks');
  rows.sort((a, b) => asInt(a['min_rank']).compareTo(asInt(b['min_rank'])));
  return rows;
});

final wvwAbilitiesProvider = FutureProvider<List<Json>>((ref) => _static(ref, 'wvw_abilities', '/wvw/abilities'));

final wvwUpgradesProvider =
    FutureProvider<Map<String, Json>>((ref) async => _byId(await _static(ref, 'wvw_upgrades', '/wvw/upgrades')));

/// the title of a wvw rank number, from the highest tier it reached
String? wvwRankTitle(List<Json> ranks, int rank) {
  String? title;
  for (final r in ranks) {
    if (asInt(r['min_rank']) <= rank) title = '${r['title'] ?? ''}';
  }
  return title;
}

// -------------------------------------------------------------------------
// guilds

/// every guild upgrade and scribe decoration
final guildUpgradeCatalogProvider =
    FutureProvider<Map<String, Json>>((ref) async => _byId(await _static(ref, 'guild_upgrades', '/guild/upgrades')));

final emblemBackgroundsProvider =
    FutureProvider<Map<String, Json>>((ref) async => _byId(await _static(ref, 'emblem_bg', '/emblem/backgrounds')));

final emblemForegroundsProvider =
    FutureProvider<Map<String, Json>>((ref) async => _byId(await _static(ref, 'emblem_fg', '/emblem/foregrounds')));

/// dye colours, used to tint the emblem layers
final colorsProvider = FutureProvider<Map<String, Json>>((ref) async => _byId(await _static(ref, 'colors', '/colors')));

/// the cloth colour of a dye, which is what emblems use
Color? dyeColor(Json? dye) {
  final rgb = (dye?['cloth'] is Map ? (dye!['cloth'] as Map)['rgb'] : null) ?? dye?['base_rgb'];
  if (rgb is! List || rgb.length < 3) return null;
  return Color.fromARGB(255, asInt(rgb[0]), asInt(rgb[1]), asInt(rgb[2]));
}

// -------------------------------------------------------------------------
// story journal and biography

final storiesProvider =
    FutureProvider<Map<String, Json>>((ref) async => _byId(await _static(ref, 'stories', '/stories')));

final storySeasonsProvider = FutureProvider<List<Json>>((ref) async {
  final rows = await _static(ref, 'story_seasons', '/stories/seasons');
  rows.sort((a, b) => asInt(a['order']).compareTo(asInt(b['order'])));
  return rows;
});

final questsProvider = FutureProvider<Map<String, Json>>((ref) async => _byId(await _static(ref, 'quests', '/quests')));

final backstoryAnswersProvider = FutureProvider<Map<String, Json>>(
    (ref) async => _byId(await _static(ref, 'backstory_answers', '/backstory/answers')));

final backstoryQuestionsProvider = FutureProvider<Map<String, Json>>(
    (ref) async => _byId(await _static(ref, 'backstory_questions', '/backstory/questions')));

// -------------------------------------------------------------------------
// patch detection

/// compares the game build with the one seen last time. after a patch the
/// disk cache is cleared once, so static data does not wait a month to
/// pick up the new content
final patchCheckProvider = FutureProvider<bool>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final prefs = ref.watch(prefsProvider);
  final build = await api.gameBuild();
  if (build <= 0) return false;
  final seen = prefs.getInt('game_build');
  await prefs.setInt('game_build', build);
  if (seen == null || seen == build) return false;
  await ref.read(diskCacheProvider)?.clear();
  return true;
});
