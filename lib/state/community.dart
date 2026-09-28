import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import '../api/gw2_api.dart';

/// set by the release build from the repository secrets. a build without them
/// (a local run, a fork) has no community account and hides it entirely
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

bool get communityConfigured => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

/// where the browser sends the player back after signing in with discord.
/// the same address is registered in the android manifest and in the
/// supabase dashboard's redirect urls
const authRedirect = 'tyriacodex://login-callback';

bool _ready = false;

/// whether the community backend could be reached at start
bool get communityReady => _ready;

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
    authScreenLaunchMode: LaunchMode.externalApplication,
  );
}

Future<void> signOut() => Supabase.instance.client.auth.signOut();

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
  final raw = await api.get('/createsubtoken', {
    'permissions': permissions.join(','),
    'expire': subtokenExpiry(DateTime.now()),
  });
  final subtoken = raw is Map ? raw['subtoken'] : null;
  if (subtoken is! String || subtoken.isEmpty) throw const LinkFailure('gw2_unavailable');
  return subtoken;
}

/// ten minutes from [now] in utc, whole seconds, as the api expects
String subtokenExpiry(DateTime now) {
  final at = now.toUtc().add(const Duration(minutes: 10));
  return '${at.toIso8601String().split('.').first}Z';
}

/// why linking failed, one of the codes the gw2-link function answers with
class LinkFailure implements Exception {
  const LinkFailure(this.code);
  final String code;
}

/// links the account of the active api key, or refreshes it when it is
/// linked already. returns the linked account's name
Future<String> linkGw2Account(Gw2Api api, List<String> keyPermissions) async {
  final subtoken = await createLinkSubtoken(api, keyPermissions);
  try {
    final res = await Supabase.instance.client.functions.invoke('gw2-link', body: {'subtoken': subtoken});
    final data = res.data;
    return data is Map ? '${data['account_name'] ?? ''}' : '';
  } on FunctionException catch (e) {
    final details = e.details;
    throw LinkFailure(details is Map && details['error'] is String ? details['error'] as String : 'link_failed');
  }
}

class LinkedAccount {
  const LinkedAccount(this.id, this.name, this.verifiedAt);
  final String id;
  final String name;
  final DateTime? verifiedAt;
}

class MyGuild {
  const MyGuild(this.id, this.name, this.tag, this.role);
  final String id;
  final String name;
  final String tag;

  /// member, officer or leader
  final String role;
}

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

/// the guilds the signed in player belongs to, with their role in each
final myGuildsProvider = FutureProvider.autoDispose<List<MyGuild>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const [];
  final rows = await Supabase.instance.client
      .from('guild_members')
      .select('role, guilds(id, name, tag)')
      .eq('user_id', session.user.id);
  final out = <MyGuild>[];
  for (final r in rows) {
    final g = r['guilds'];
    if (g is! Map) continue;
    out.add(MyGuild('${g['id']}', '${g['name'] ?? ''}', '${g['tag'] ?? ''}', '${r['role'] ?? 'member'}'));
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

/// whether a link is old enough to refresh quietly: a day, well within the
/// thirty days after which the backend stops counting the membership
bool linkIsStale(DateTime? verifiedAt, DateTime now) =>
    verifiedAt == null || now.difference(verifiedAt) > const Duration(days: 1);
