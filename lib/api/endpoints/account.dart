part of '../gw2_api.dart';

/// the account's own data: what the key can read. most of it is kept on disk and refreshed in the background
extension Gw2AccountApi on Gw2Api {
  Future<Json> tokenInfo() async => Map<String, dynamic>.from(await get('/tokeninfo') as Map);

  Future<Json> account() async => Map<String, dynamic>.from(await cachedGet('/account') as Map);

  Future<List<Json>> characters() async => _list(await cachedGet('/characters', query: {'ids': 'all'}));

  Future<List<Json>> wallet() async => _list(await cachedGet('/account/wallet'));

  Future<List<Json>> materials() async => _list(await cachedGet('/account/materials'));

  Future<List<Json?>> bank() async {
    final raw = await cachedGet('/account/bank') as List;
    return raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : null).toList();
  }

  Future<List<Json?>> sharedInventory() async {
    final raw = await get('/account/inventory') as List;
    return raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : null).toList();
  }

  /// daily, weekly or special objectives of the wizard's vault
  Future<Json> vault(String track) async => Map<String, dynamic>.from(await cachedGet(
        '/account/wizardsvault/$track',
        // the api itself refreshes about every five minutes, shorter is pointless
        ttl: const Duration(minutes: 5),
        notBefore: switch (track) {
          'daily' => lastDailyReset(),
          'weekly' => lastWeeklyReset(),
          _ => null,
        },
      ) as Map);

  /// raid encounters cleared this week and the wing layout
  Future<List<String>> accountRaids() async =>
      (await cachedGet('/account/raids', ttl: const Duration(minutes: 5), notBefore: lastWeeklyReset()) as List)
          .map((e) => '$e')
          .toList();

  /// dungeon paths cleared today
  Future<List<String>> accountDungeons() async =>
      (await cachedGet('/account/dungeons', ttl: const Duration(minutes: 5), notBefore: lastDailyReset()) as List)
          .map((e) => '$e')
          .toList();

  /// recipe ids the account has learned. needs the unlocks permission
  Future<List<int>> learnedRecipes() async => [for (final v in (await cachedGet('/account/recipes') as List)) asInt(v)];

  /// luck, fractal augmentations and similar counters, as {id: value}
  Future<Map<String, int>> accountCounters(String path) async {
    final raw = await cachedGet(path);
    return {
      for (final row in (raw as List? ?? const []))
        if (row is Map) '${row['id']}': asInt(row['value']),
    };
  }

  /// the team and guild the account plays world vs world with
  Future<Json> accountWvw() async => Map<String, dynamic>.from(await cachedGet('/account/wvw') as Map);

  /// one part of a character, such as heropoints, sab, quests or training
  Future<dynamic> characterPart(String name, String part) =>
      cachedGet('/characters/${Uri.encodeComponent(name)}/$part');

  Future<Json> vaultSeason() async => Map<String, dynamic>.from(await get('/wizardsvault') as Map);

  /// the astral reward shop with what this account already bought
  Future<List<Json>> vaultListings() async => _list(await cachedGet('/account/wizardsvault/listings'));

  /// daily crafts and map chests already collected today, both need the
  /// progression permission
  Future<List<String>> dailyDone(String path) async =>
      (await cachedGet('/account/$path', ttl: const Duration(minutes: 5), notBefore: lastDailyReset()) as List)
          .map((e) => '$e')
          .toList();

  Future<List<Json>> accountAchievements() async => _list(await cachedGet('/account/achievements'));

  Future<List<Json>> accountMasteries() async => _list(await cachedGet('/account/masteries'));

  Future<Json> masteryPoints() async => Map<String, dynamic>.from(await cachedGet('/account/mastery/points') as Map);

  Future<List<Json>> legendaryArmory() async => _list(await cachedGet('/account/legendaryarmory'));

  /// stored build templates. the list endpoint gives ids, details come from
  /// the same path with an ids parameter
  Future<List<Json>> buildStorage() async {
    final ids = (await cachedGet('/account/buildstorage') as List).map((e) => '$e').toList();
    if (ids.isEmpty) return const [];
    final out = <Json>[];
    for (final chunk in _chunks(ids)) {
      out.addAll(_list(await get('/account/buildstorage', {'ids': chunk.join(',')})));
    }
    return out;
  }
}
