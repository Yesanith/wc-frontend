part of '../guild_events.dart';

class RosterMember {
  const RosterMember(this.userId, this.accountName, this.role, {this.gw2Rank, this.manual = false});

  factory RosterMember.fromRow(Map<String, dynamic> r) {
    final rank = '${r['gw2_rank'] ?? ''}';
    return RosterMember(
      '${r['user_id']}',
      '${r['account_name'] ?? '?'}',
      '${r['role'] ?? 'member'}',
      gw2Rank: rank.isEmpty ? null : rank,
      manual: r['manual'] == true,
    );
  }

  final String userId;
  final String accountName;

  /// member, officer or leader
  final String role;

  /// the rank the game gives them in the guild, known once the leader's app has
  /// brought the guild's member list
  final String? gw2Rank;

  /// the leader appointed the role by hand, so it stays whatever the game's rank is.
  /// otherwise it follows the game: a rank that may invite, promote, kick or edit ranks makes an officer
  final bool manual;
}

/// a guild's wondrous compass members, leader first, then officers
final guildRosterProvider = FutureProvider.autoDispose.family<List<RosterMember>, String>((ref, guildId) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const [];
  final rows = await Supabase.instance.client.rpc('guild_roster', params: {'p_guild': guildId}) as List<dynamic>;
  const rank = {'leader': 0, 'officer': 1, 'member': 2};
  return [
    for (final r in rows.whereType<Map<String, dynamic>>()) RosterMember.fromRow(r),
  ]..sort((a, b) {
      final byRole = (rank[a.role] ?? 3).compareTo(rank[b.role] ?? 3);
      return byRole != 0 ? byRole : a.accountName.toLowerCase().compareTo(b.accountName.toLowerCase());
    });
});

/// the leader hands a role appointed by hand back to the game, it follows the rank again
Future<void> resetGuildRole(String guildId, String userId) => _call(() async {
      await Supabase.instance.client.rpc('reset_guild_role', params: {'p_guild': guildId, 'p_user': userId});
    });

/// the leader makes a member an officer, or an officer a member again
Future<void> setGuildRole(String guildId, String userId, String role) => _call(() async {
      await Supabase.instance.client.rpc('set_guild_role', params: {
        'p_guild': guildId,
        'p_user': userId,
        'p_role': role,
      });
    });

// ---------------------------------------------------------------------------
// the account an event is created with

/// one of the player's GW2 accounts in one guild, with its role there. roles
/// are per account and guild: one account may lead a guild that another only
/// belongs to
class GuildAccount {
  const GuildAccount(this.guildId, this.accountId, this.accountName, this.role, {this.gw2Rank});

  final String guildId;
  final String accountId;
  final String accountName;

  /// member, officer or leader
  final String role;

  /// the rank the game gives this account in the guild, when it is known
  final String? gw2Rank;

  bool get mayCreate => role == 'leader' || role == 'officer';
}

/// every guild membership of every GW2 account the player has linked
final myGuildAccountsProvider = FutureProvider.autoDispose<List<GuildAccount>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const [];
  final rows = await Supabase.instance.client
      .from('guild_members')
      .select('role, gw2_rank, guild_id, gw2_account_id, gw2_accounts(account_name)')
      .eq('user_id', session.user.id);
  return [
    for (final r in rows)
      if (r['gw2_accounts'] case final Map account)
        GuildAccount('${r['guild_id']}', '${r['gw2_account_id']}', '${account['account_name'] ?? '?'}',
            '${r['role'] ?? 'member'}',
            gw2Rank: nonEmpty(r['gw2_rank'])),
  ];
});

/// all of the player's accounts in [guildId], the one with the highest role
/// first, then by name
List<GuildAccount> accountsIn(List<GuildAccount> all, String guildId) {
  const rank = {'leader': 0, 'officer': 1};
  return [
    for (final a in all)
      if (a.guildId == guildId) a,
  ]..sort((a, b) {
      final byRole = (rank[a.role] ?? 2).compareTo(rank[b.role] ?? 2);
      return byRole != 0 ? byRole : a.accountName.toLowerCase().compareTo(b.accountName.toLowerCase());
    });
}
