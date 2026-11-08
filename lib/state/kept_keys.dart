import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart';
import 'community.dart';
import 'settings.dart';

// API keys a player signed in with Discord keeps in their account, so the app on another device, signed in with the
// same Discord account, has them without a trip to ArenaNet. The server keeps them sealed and gives them back only to
// their owner. It is the player's choice, on by default and asked about when a key is added.

/// whether this device keeps the player's keys in their account. on until the player turns it off
class KeepKeysNotifier extends Notifier<bool> {
  static const _key = 'keep_keys_in_account';

  @override
  bool build() => ref.read(prefsProvider).getBool(_key) ?? true;

  Future<void> set(bool on) async {
    state = on;
    await ref.read(prefsProvider).setBool(_key, on);
  }
}

final keepKeysProvider = NotifierProvider<KeepKeysNotifier, bool>(KeepKeysNotifier.new);

/// a key the account keeps, with the name of the game account it is of
class KeptKey {
  const KeptKey(this.accountName, this.key);

  final String accountName;
  final String key;
}

/// a game account whose key the account keeps. the key itself is never listed
class KeptAccount {
  const KeptAccount(this.accountId, this.accountName);

  final String accountId;
  final String accountName;
}

/// the gw2-link function, its refusals as a [LinkFailure]
Future<Object?> _call(Map<String, Object?> body) async {
  try {
    return (await Supabase.instance.client.functions.invoke('gw2-link', body: body)).data;
  } on FunctionException catch (e) {
    final details = e.details;
    final code = details is Map && details['error'] is String ? details['error'] as String : 'http_${e.status}';
    throw LinkFailure(code, detail: 'HTTP ${e.status}');
  }
}

/// the keys from the server's answer, none for anything else
List<KeptKey> parseKeptKeys(Object? data) {
  final keys = data is Map ? data['keys'] : null;
  if (keys is! List) return const [];
  return [
    for (final k in keys)
      if (k is Map && k['key'] is String && (k['key'] as String).isNotEmpty)
        KeptKey('${k['account_name'] ?? ''}', k['key'] as String),
  ];
}

/// the keys the account keeps, opened for the player by the server
Future<List<KeptKey>> keptKeys() async => parseKeptKeys(await _call({'action': 'keys'}));

/// keeps [key] in the account. the server checks it with the game: its account must be one the player linked
Future<void> saveKeyToAccount(String key) async => _call({'action': 'save_key', 'key': key});

/// links the account of [key] when it is not yet, then keeps the key in the account. returns null when it is kept,
/// otherwise the text key that says why not. it never throws: the key is on the device whatever happens here
Future<String?> keepKeyInAccount(String key) async {
  try {
    await saveKeyToAccount(key);
    return null;
  } on LinkFailure catch (e) {
    if (e.code != 'not_linked') return keptKeyFailure(e.code);
  } catch (_) {
    return 'community_failed';
  }
  // an account that is not linked is linked first, with a short lived subtoken, then the key is kept
  final api = Gw2Api(key);
  try {
    final info = await api.tokenInfo();
    final permissions = ((info['permissions'] as List?) ?? const []).map((e) => '$e').toList();
    await linkGw2AccountOutcome(api, permissions);
    await saveKeyToAccount(key);
    return null;
  } on LinkFailure catch (e) {
    return keptKeyFailure(e.code);
  } catch (_) {
    return 'community_failed';
  } finally {
    api.close();
  }
}

/// the text key for why a key could not be kept
String keptKeyFailure(String code) => switch (code) {
      'keys_off' => 'keep_keys_off',
      _ => linkFailureKey(code),
    };

/// the game accounts whose key the account keeps
final keptAccountsProvider = FutureProvider.autoDispose<List<KeptAccount>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const [];
  final rows = await Supabase.instance.client.rpc('my_saved_api_keys');
  return [
    if (rows is List)
      for (final r in rows)
        if (r is Map) KeptAccount('${r['account_id']}', '${r['account_name'] ?? ''}'),
  ];
});

/// takes a kept key back, or all of them
Future<void> forgetKeptKeys({String? accountId}) async {
  await Supabase.instance.client.rpc('forget_api_key', params: {'p_account': accountId});
}

/// takes back the key of the account called [accountName], when the account keeps one. a key removed from the device
/// is not to come back on the next sign in. a failure is ignored: the key is gone from the device either way
Future<void> forgetKeptKeyOf(String accountName) async {
  try {
    final rows = await Supabase.instance.client.rpc('my_saved_api_keys');
    if (rows is! List) return;
    for (final r in rows) {
      if (r is Map && '${r['account_name']}' == accountName) await forgetKeptKeys(accountId: '${r['account_id']}');
    }
  } catch (_) {}
}

/// on a device with no key, the keys the account keeps are brought once the player signs in. how many were brought;
/// none when the player chose not to keep them, or the server could not say
final restoredKeysProvider = FutureProvider<int>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null || !ref.read(keepKeysProvider)) return 0;
  try {
    final kept = await keptKeys();
    for (final k in kept) {
      await ref.read(keysProvider.notifier).add(k.key, k.accountName);
    }
    return kept.length;
  } catch (_) {
    return 0;
  }
});
