part of '../gw2_api.dart';

/// static game data: items, recipes and the other endpoints that are read by id
extension Gw2ReferenceApi on Gw2Api {
  /// plain id list of a static endpoint, ids can be ints or strings
  Future<List<String>> idList(String path) async {
    final raw = await get(path) as List;
    return raw.map((e) => '$e').toList();
  }

  /// account unlock list. entries are ids or objects with an id field
  Future<List<String>> unlockedIds(String path) async {
    final raw = await get(path) as List;
    return raw.map((e) => e is Map ? '${e['id']}' : '$e').toList();
  }

  /// details for a static endpoint, in batches of 200. a batch that fails
  /// because one id is unknown gets split instead of dropped, otherwise a
  /// single bad id would cost 200 names
  Future<List<Json>> details(String path, List<String> ids) async {
    final out = <Json>[];
    for (final chunk in _chunks(ids)) {
      out.addAll(await _detailChunk(path, chunk));
    }
    return out;
  }

  Future<List<Json>> _detailChunk(String path, List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      return _list(await get(path, {'ids': ids.join(',')}));
    } on Gw2ApiException catch (e) {
      if (e.status != 404 && e.status != 400) rethrow;
      if (ids.length == 1) return const [];
      final middle = ids.length ~/ 2;
      return [
        ...await _detailChunk(path, ids.sublist(0, middle)),
        ...await _detailChunk(path, ids.sublist(middle)),
      ];
    }
  }

  Future<Map<int, Json>> items(Iterable<int> ids) => _batch('/items', ids, _itemCache);

  Future<Map<int, Json>> currencies(Iterable<int> ids) => _batch('/currencies', ids, _currencyCache);

  Future<Map<int, Json>> specializations(Iterable<int> ids) => _batch('/specializations', ids, _specCache);

  Future<Map<int, Json>> achievements(Iterable<int> ids) => _batch('/achievements', ids, _achievementCache);

  Future<Map<int, Json>> masteries(Iterable<int> ids) => _batch('/masteries', ids, _masteryCache);

  Future<Map<int, Json>> traits(Iterable<int> ids) => _batch('/traits', ids, _traitCache);

  Future<Map<int, Json>> skills(Iterable<int> ids) => _batch('/skills', ids, _skillCache);

  Future<Map<int, Json>> pets(Iterable<int> ids) => _batch('/pets', ids, _petCache);

  Future<Map<int, Json>> recipes(Iterable<int> ids) => _batch('/recipes', ids, _recipeCache);

  /// recipe ids that produce this item, empty when it cannot be crafted
  Future<List<int>> recipesForOutput(int itemId) async {
    try {
      final raw = await get('/recipes/search', {'output': '$itemId'}) as List;
      return raw.map(asInt).toList();
    } on Gw2ApiException catch (e) {
      if (e.status == 404) return const [];
      rethrow;
    }
  }

  /// recipe ids that use this item as an ingredient
  Future<List<int>> recipesForInput(int itemId) async {
    try {
      final raw = await get('/recipes/search', {'input': '$itemId'}) as List;
      return raw.map(asInt).toList();
    } on Gw2ApiException catch (e) {
      if (e.status == 404) return const [];
      rethrow;
    }
  }

  /// weapons, palettes and skill lists of a profession
  Future<Json> profession(String name) async => _object(await get('/professions/$name'));

  Future<List<Json>> raidWings() async {
    final ids = await idList('/raids');
    if (ids.isEmpty) return const [];
    return details('/raids', ids);
  }

  Future<List<Json>> dungeons() async {
    final ids = await idList('/dungeons');
    if (ids.isEmpty) return const [];
    return details('/dungeons', ids);
  }

  /// every map of the game, static data
  Future<List<Json>> maps() async => _list(await get('/maps', {'ids': 'all'}));

  /// every entry of a static endpoint that accepts ids=all
  Future<List<Json>> allOf(String path) async => _list(await get(path, {'ids': 'all'}));

  /// the current game build, changes with every patch
  Future<int> gameBuild() async {
    final raw = await get('/build');
    return raw is Map ? asInt(raw['id']) : 0;
  }

  /// revenant legends, ids look like "Legend1"
  Future<List<Json>> legends(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return _list(await get('/legends', {'ids': ids.join(',')}));
  }

  Future<List<String>> dailyAll(String path) async => idList('/$path');
}
