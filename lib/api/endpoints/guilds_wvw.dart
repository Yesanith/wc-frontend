part of '../gw2_api.dart';

/// guilds, and world vs world, whose live data is never cached
extension Gw2GuildWvwApi on Gw2Api {
  /// guild endpoints. most need the guilds permission and some also
  /// require the account to lead the guild
  Future<Json> guild(String id) async => _object(await cachedGet('/guild/$id', ttl: const Duration(hours: 6)));

  Future<List<Json>> guildStash(String id) async => _list(await cachedGet('/guild/$id/stash'));

  Future<List<Json>> guildTreasury(String id) async => _list(await cachedGet('/guild/$id/treasury'));

  Future<List<Json>> guildLog(String id) async => _list(await cachedGet('/guild/$id/log'));

  Future<List<Json>> guildPart(String id, String part) async => _list(await cachedGet('/guild/$id/$part'));

  /// upgrade ids the guild has built
  Future<List<int>> guildUpgradeIds(String id) async => [
    for (final v in (await cachedGet('/guild/$id/upgrades') as List)) asInt(v),
  ];

  Future<Json?> wvwMatch(int team) async {
    try {
      return _object(await get('/wvw/matches', {'world': '$team'}));
    } on Gw2ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// one lighter view of a match: overview (worlds and times), scores
  /// (skirmishes) or stats (kills and deaths). null when the match is gone
  Future<Json?> wvwMatchPart(String part, String matchId) async {
    try {
      return _object(await get('/wvw/matches/$part', {'id': matchId}));
    } on Gw2ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// the best guilds of one team in a match, by kdr or by kills. the game
  /// answers an empty list, or 404, while it has nothing to rank
  Future<List<Json>> wvwTopGuilds(String matchId, int team, String kind) async {
    try {
      return _list(await get('/wvw/matches/stats/$matchId/teams/$team/top/$kind'));
    } on Gw2ApiException catch (e) {
      if (e.status == 404) return const [];
      rethrow;
    }
  }

  /// what one guild did in a match. null when the game has no data for it
  Future<Json?> wvwGuildStats(String matchId, String guildId) async {
    try {
      final raw = await get('/wvw/matches/stats/$matchId/guilds/$guildId');
      return raw is Map && raw['text'] == null ? _object(raw) : null;
    } on Gw2ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// guild id -> wvw team for one region (na or eu)
  Future<Map<String, int>> wvwGuildTeams(String region) async {
    final raw = await cachedGet('/wvw/guilds/$region', ttl: const Duration(hours: 6));
    if (raw is! Map) return const {};
    return {for (final e in raw.entries) '${e.key}'.toUpperCase(): asInt(e.value)};
  }

  /// next lockout or team assignment per region, kind is lockout or teamAssignment
  Future<Json> wvwTimer(String kind) async => _object(await get('/wvw/timers/$kind'));
}
