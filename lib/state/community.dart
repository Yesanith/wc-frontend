import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/gw2_api.dart';
import '../l10n/strings.dart';
import '../services/push.dart';

/// set by the release build from the repository secrets. a build without them
/// (a local run, a fork) has no community account and hides it entirely
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

bool get communityConfigured => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

/// where the browser sends the player back after signing in with discord.
/// the same address is registered in the android manifest and in the
/// supabase dashboard's redirect urls
const _appRedirect = 'wondrouscompass://login-callback';

/// where the app is served when it runs in a browser, set by the site build.
/// without it, the address the page was opened at
const _webBase = String.fromEnvironment('WEB_BASE_URL');

String get authRedirect => kIsWeb ? webAuthRedirect(_webBase, Uri.base) : _appRedirect;

/// the page discord sends the player back to in a browser: the app's own address,
/// without a query or a fragment. it must be one of the supabase dashboard's redirect urls
String webAuthRedirect(String configured, Uri current) {
  if (configured.isNotEmpty) return configured;
  // made again from its parts: replacing the query with nothing would leave a ? behind
  final clean = Uri(
    scheme: current.scheme,
    host: current.host,
    port: current.hasPort ? current.port : null,
    path: current.path,
  ).toString();
  return clean.replaceFirst(RegExp(r'/index\.html$'), '/');
}

bool _ready = false;

/// whether the community backend could be reached at start
bool get communityReady => _ready;

/// a test says whether it could
@visibleForTesting
void debugSetCommunityReady(bool ready) => _ready = ready;

/// connects to the backend once at start. a failure only switches the
/// community account off, the rest of the app never depends on it
Future<void> initCommunity() async {
  if (!communityConfigured) return;
  try {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
    _ready = true;
  } catch (_) {
    _ready = false;
  }
}

/// the signed in session, null when signed out or not configured
final sessionProvider = StreamProvider<Session?>((ref) async* {
  if (!communityReady) {
    yield null;
    return;
  }
  final auth = Supabase.instance.client.auth;
  yield auth.currentSession;
  yield* auth.onAuthStateChange.map((state) => state.session);
});

class CommunityProfile {
  const CommunityProfile({required this.id, required this.displayName, this.avatarUrl});

  final String id;
  final String displayName;
  final String? avatarUrl;

  static CommunityProfile fromRow(Map<String, dynamic> row) => CommunityProfile(
        id: '${row['id']}',
        displayName: '${row['display_name'] ?? ''}',
        avatarUrl: row['avatar_url'] as String?,
      );
}

/// the signed in player's own profile row
final myProfileProvider = FutureProvider.autoDispose<CommunityProfile?>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return null;
  final row = await Supabase.instance.client
      .from('profiles')
      .select('id, display_name, avatar_url')
      .eq('id', session.user.id)
      .maybeSingle();
  return row == null ? null : CommunityProfile.fromRow(row);
});

/// opens discord in the browser, the app comes back through [authRedirect]
Future<void> signInWithDiscord() async {
  await Supabase.instance.client.auth.signInWithOAuth(
    OAuthProvider.discord,
    redirectTo: authRedirect,
    // a browser signs in in the same tab, the phone's browser sends the player back to the app
    authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
  );
}

/// the device stops getting this player's notifications first, a shared
/// phone should not keep reminding of someone else's events
Future<void> signOut() async {
  await disablePush();
  await Supabase.instance.client.auth.signOut();
}

/// the setting that decides whether this device gets event notifications
const pushPref = 'push_enabled';

/// removes the account and everything tied to it on the server, then the
/// local session. the stores require this to be possible inside the app
Future<void> deleteAccount() async {
  final client = Supabase.instance.client;
  await client.rpc('delete_account');
  // the account is gone, so the server may refuse the sign out. the local
  // session is cleared either way
  try {
    await client.auth.signOut();
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// gw2 accounts and guilds

/// a subtoken for [key], limited to what linking needs and valid ten minutes.
/// the real key is used only here, against the gw2 api, and never leaves the
/// device. guilds is added when the key has it, it tells who leads a guild
Future<String> createLinkSubtoken(Gw2Api api, List<String> keyPermissions) async {
  final permissions = ['account', if (keyPermissions.contains('guilds')) 'guilds'];
  final dynamic raw;
  try {
    raw = await api.get('/createsubtoken', {
      'permissions': permissions.join(','),
      'expire': subtokenExpiry(DateTime.now()),
    });
  } catch (e) {
    // the gw2 api refused before anything reached the backend
    throw LinkFailure('subtoken_failed', detail: '$e');
  }
  final subtoken = raw is Map ? raw['subtoken'] : null;
  if (subtoken is! String || subtoken.isEmpty) throw const LinkFailure('subtoken_failed', detail: 'empty answer');
  return subtoken;
}

/// ten minutes from [now] in utc, whole seconds, as the api expects
String subtokenExpiry(DateTime now) {
  final at = now.toUtc().add(const Duration(minutes: 10));
  return '${at.toIso8601String().split('.').first}Z';
}

/// why linking failed, one of the codes the gw2-link function answers with
class LinkFailure implements Exception {
  const LinkFailure(this.code, {this.detail});
  final String code;

  /// what went wrong underneath, shown next to the message so a failure can
  /// be told apart from the others
  final String? detail;

  @override
  String toString() => detail == null ? code : '$code: $detail';
}

/// how one guild the account leads went when the backend read it from the
/// game: synced, too_soon, unavailable or failed, and when something was
/// missing what, like guild:403
class GuildSyncResult {
  const GuildSyncResult(this.result, this.detail);

  final String result;
  final String? detail;
}

/// what linking came to: the account, and how the guilds it leads were synced
class LinkOutcome {
  const LinkOutcome(this.name, this.synced);

  final String name;
  final List<GuildSyncResult> synced;
}

/// the guild results in the backend's answer, none for anything else
List<GuildSyncResult> parseSynced(Object? data) {
  final synced = data is Map ? data['synced'] : null;
  if (synced is! List) return const [];
  return [
    for (final r in synced)
      if (r is Map && r['result'] is String)
        GuildSyncResult('${r['result']}', r['detail'] is String ? '${r['detail']}' : null),
  ];
}

/// links the account of the active api key, or refreshes it when it is
/// linked already. returns the linked account's name
Future<String> linkGw2Account(Gw2Api api, List<String> keyPermissions) async =>
    (await linkGw2AccountOutcome(api, keyPermissions)).name;

/// the same, with how the guilds the account leads were synced
Future<LinkOutcome> linkGw2AccountOutcome(Gw2Api api, List<String> keyPermissions) async {
  final subtoken = await createLinkSubtoken(api, keyPermissions);
  final Object? linked;
  try {
    // linking alone, quick: the guilds the account leads are read in a call of their own
    final res =
        await Supabase.instance.client.functions.invoke('gw2-link', body: {'subtoken': subtoken, 'sync': false});
    linked = res.data;
  } on FunctionException catch (e) {
    final details = e.details;
    final code = details is Map && details['error'] is String ? details['error'] as String : 'http_${e.status}';
    throw LinkFailure(code, detail: 'HTTP ${e.status}');
  }
  final name = linked is Map ? '${linked['account_name'] ?? ''}' : '';
  return LinkOutcome(name, leadsAGuild(linked) ? await _syncLedGuilds(subtoken) : const <GuildSyncResult>[]);
}

/// whether the backend's answer to linking lists a guild the account leads
bool leadsAGuild(Object? linked) {
  final guilds = linked is Map ? linked['guilds'] : null;
  return guilds is List && guilds.any((g) => g is Map && g['leader'] == true);
}

/// asks the backend to read the guilds the account leads, with the same
/// short lived subtoken. this never fails linking, and never waits for ever:
/// it says how it went, or why it did not
Future<List<GuildSyncResult>> _syncLedGuilds(String subtoken) async {
  try {
    final res = await Supabase.instance.client.functions
        .invoke('gw2-link', body: {'subtoken': subtoken, 'action': 'guilds'}).timeout(const Duration(seconds: 45));
    return parseSynced(res.data);
  } on TimeoutException {
    return const [GuildSyncResult('failed', 'call:timeout')];
  } on FunctionException catch (e) {
    final details = e.details;
    final why = details is Map && details['error'] is String ? details['error'] as String : '${e.status}';
    return [GuildSyncResult('failed', 'call:$why')];
  } catch (e) {
    return [GuildSyncResult('failed', 'call:${'$e'.split('\n').first}')];
  }
}

class LinkedAccount {
  const LinkedAccount(this.id, this.name, this.verifiedAt);
  final String id;
  final String name;
  final DateTime? verifiedAt;
}

class MyGuild {
  const MyGuild(this.id, this.name, this.tag, this.role, {this.gw2Rank});
  final String id;
  final String name;
  final String tag;

  /// member, officer or leader
  final String role;

  /// the rank the game gives them in the guild, when the leader's app has brought it
  final String? gw2Rank;
}

/// what to call somebody's place in a guild: the rank the game gives them, as
/// the guild named it. only when it is not known yet the app's own word for it
String rankLabel(S s, String role, String? gw2Rank) =>
    gw2Rank != null && gw2Rank.isNotEmpty ? gw2Rank : s.t('guild_role_$role');

/// the gw2 accounts linked to the signed in player
final linkedAccountsProvider = FutureProvider.autoDispose<List<LinkedAccount>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const [];
  final rows =
      await Supabase.instance.client.from('gw2_accounts').select('id, account_name, verified_at').order('account_name');
  return [
    for (final r in rows)
      LinkedAccount('${r['id']}', '${r['account_name'] ?? ''}', DateTime.tryParse('${r['verified_at'] ?? ''}')),
  ];
});

/// what the game tells about a guild that only its leader may read. the
/// leader's app hands it to the backend, the members read it from there
class GuildDetails {
  const GuildDetails({
    this.level,
    this.motd = '',
    this.memberCount,
    this.memberCapacity,
    this.syncedAt,
    this.hidden = const <String>{},
    this.reviewedAt,
  });

  final int? level;
  final String motd;
  final int? memberCount;
  final int? memberCapacity;

  /// when the leader's app last brought it, null while it never has
  final DateTime? syncedAt;

  /// whether the leader has shared anything yet
  bool get known => syncedAt != null;

  /// when the leader went through what the members see. until then the treasury, the
  /// stash and the log, which name who took what, stay hidden from them
  final DateTime? reviewedAt;

  bool get reviewed => reviewedAt != null;

  /// the parts of the guild the leader hides from the members, everything else
  /// the leader's app brings is shared
  final Set<String> hidden;

  /// whether the members see [part]: members, ranks, teams, treasury, stash,
  /// log, upgrades or storage
  bool shares(String part) => !hidden.contains(part);

  factory GuildDetails.fromRow(Map<String, dynamic> r) => GuildDetails(
        level: _asInt(r['level']),
        motd: '${r['motd'] ?? ''}',
        memberCount: _asInt(r['member_count']),
        memberCapacity: _asInt(r['member_capacity']),
        syncedAt: DateTime.tryParse('${r['details_synced_at'] ?? ''}'),
        hidden: _textSet(r['hidden_parts']),
        reviewedAt: DateTime.tryParse('${r['sharing_reviewed_at'] ?? ''}'),
      );
}

int? _asInt(Object? v) => v is num ? v.toInt() : null;

Set<String> _textSet(Object? v) => v is List ? {for (final x in v) '$x'} : const <String>{};

/// the list a guild's leader shared of a part the game opens only to the
/// leader, null when the answer is anything but ok: not shared, switched off,
/// never brought, or the player is no member
List<dynamic>? parseSharedPart(Object? answer) {
  if (answer is! Map || answer['status'] != 'ok') return null;
  final data = answer['data'];
  return data is List ? data : null;
}

/// what the guild's leader shared of [part], null when nothing
Future<List<dynamic>?> sharedGuildPart(String gw2GuildId, String part) async {
  try {
    final answer =
        await Supabase.instance.client.rpc('guild_shared_part', params: {'p_gw2_guild': gw2GuildId, 'p_part': part});
    return parseSharedPart(answer);
  } catch (_) {
    return null;
  }
}

/// the leader has been through what the members see, so the treasury, the stash and
/// the log follow the choices from now on
Future<void> confirmGuildSharing(String guildId) async {
  await Supabase.instance.client.rpc('confirm_guild_sharing', params: {'p_guild': guildId});
}

/// the leader shows or hides one part of the guild to the members
Future<void> setGuildPartShared(String guildId, String part, bool shared) async {
  await Supabase.instance.client
      .rpc('set_guild_part_shared', params: {'p_guild': guildId, 'p_part': part, 'p_shared': shared});
}

/// the community guild that belongs to a game guild, null until the player has
/// linked an account that is in it
final tyriaGuildIdProvider = FutureProvider.autoDispose.family<String?, String>((ref, gw2GuildId) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return null;
  final row = await Supabase.instance.client.from('guilds').select('id').eq('gw2_guild_id', gw2GuildId).maybeSingle();
  return row == null ? null : '${row['id']}';
});

/// the details of one of the player's guilds
final guildDetailsProvider = FutureProvider.autoDispose.family<GuildDetails?, String>((ref, guildId) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return null;
  final row = await Supabase.instance.client
      .from('guilds')
      .select('level, motd, member_count, member_capacity, details_synced_at, hidden_parts, sharing_reviewed_at')
      .eq('id', guildId)
      .maybeSingle();
  return row == null ? null : GuildDetails.fromRow(row);
});

/// the guilds the signed in player belongs to, with their role in each
final myGuildsProvider = FutureProvider.autoDispose<List<MyGuild>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const [];
  final rows = await Supabase.instance.client
      .from('guild_members')
      .select('role, gw2_rank, guilds(id, name, tag)')
      .eq('user_id', session.user.id);
  final out = <MyGuild>[];
  for (final r in rows) {
    final g = r['guilds'];
    if (g is! Map) continue;
    final rank = '${r['gw2_rank'] ?? ''}';
    out.add(MyGuild('${g['id']}', '${g['name'] ?? ''}', '${g['tag'] ?? ''}', '${r['role'] ?? 'member'}',
        gw2Rank: rank.isEmpty ? null : rank));
  }
  // a player with several accounts in one guild sees it once, highest role
  const rank = {'leader': 0, 'officer': 1, 'member': 2};
  out.sort((a, b) => (rank[a.role] ?? 3).compareTo(rank[b.role] ?? 3));
  final seen = <String>{};
  return [
    for (final g in out)
      if (seen.add(g.id)) g,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

/// removes a linked gw2 account and its guild memberships
Future<void> unlinkGw2Account(String id) async {
  await Supabase.instance.client.from('gw2_accounts').delete().eq('id', id);
}
