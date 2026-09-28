import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

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
