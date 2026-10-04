part of '../gw2_api.dart';

/// pvp seasons, leaderboards and the account's own record
extension Gw2PvpApi on Gw2Api {
  /// every league season, newest and oldest alike
  Future<List<Json>> pvpSeasons() async => details('/pvp/seasons', await idList('/pvp/seasons'));

  /// the boards a season keeps, such as ladder, legendary or guild. empty
  /// for a season that has none
  Future<List<String>> pvpBoards(String seasonId) async {
    try {
      return await idList('/pvp/seasons/$seasonId/leaderboards');
    } on Gw2ApiException catch (e) {
      if (e.status == 404) return const [];
      rethrow;
    }
  }

  /// one board of a season for one region (na or eu)
  Future<List<Json>> pvpLeaderboard(String seasonId, String board, String region) async {
    try {
      return _list(await get('/pvp/seasons/$seasonId/leaderboards/$board/$region'));
    } on Gw2ApiException catch (e) {
      if (e.status == 404) return const [];
      rethrow;
    }
  }

  Future<Json> pvpStats() async => _object(await cachedGet('/pvp/stats'));

  /// the nine rank tiers, Rabbit through Dragon. static
  Future<List<Json>> pvpRanks() async => details('/pvp/ranks', await idList('/pvp/ranks'));

  /// pvp amulets with their attribute spreads. static
  Future<List<Json>> pvpAmulets() async => details('/pvp/amulets', await idList('/pvp/amulets'));

  /// the last matches the api remembers, newest last. the list endpoint gives
  /// ids and the details come from the same path. needs the pvp permission
  Future<List<Json>> pvpGames() async {
    final ids = await idList('/pvp/games');
    if (ids.isEmpty) return const [];
    return details('/pvp/games', ids);
  }

  /// league standing per season. needs the pvp permission
  Future<List<Json>> pvpStandings() async => _list(await cachedGet('/pvp/standings'));

  /// one season, which names the divisions a standing points at
  Future<Json?> pvpSeason(String id) async {
    if (id.isEmpty) return null;
    final rows = await details('/pvp/seasons', [id]);
    return rows.isEmpty ? null : rows.first;
  }
}
