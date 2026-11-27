import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';
import 'api.dart';
import 'community.dart';

/// what is counted: the raid bosses of each week, and the dungeon paths, world bosses, map metas and recommended
/// fractals of each day
const clearKinds = ['raid', 'fractal', 'dungeon', 'worldboss', 'meta'];

/// the addresses the subtoken the server keeps may read, and nothing else: whose account it is, and what was done since
/// the last reset
const clearWatchUrls = [
  '/v2/account',
  '/v2/account/raids',
  '/v2/account/dungeons',
  '/v2/account/worldbosses',
  '/v2/account/mapchests',
  '/v2/account/achievements',
];

const clearWatchDays = 30;
const clearWatchRenewWithin = Duration(days: 10);

/// one game account the server counts or counted for the player
class ClearCounts {
  const ClearCounts({
    required this.accountId,
    required this.accountName,
    required this.status,
    required this.total,
    required this.week,
    this.since,
    this.expiresAt,
    this.lastChecked,
  });

  final String accountId;
  final String accountName;

  /// on, refused (the game turned the subtoken down) or off (no longer counted, what was counted is kept)
  final String status;
  final Map<String, int> total;
  final Map<String, int> week;
  final DateTime? since;
  final DateTime? expiresAt;
  final DateTime? lastChecked;

  bool get on => status == 'on';

  /// whether a new subtoken is due: it was turned down, or runs out soon. one turned off is left off
  bool renewalDue(DateTime now) =>
      status == 'refused' || (on && (expiresAt == null || expiresAt!.isBefore(now.add(clearWatchRenewWithin))));
}

Map<String, int> _counts(Object? raw) => {for (final k in clearKinds) k: raw is Map ? asInt(raw[k]) : 0};

List<ClearCounts> parseClearCounts(Object? raw) => [
      if (raw is List)
        for (final r in raw)
          if (r is Map && r['account_id'] is String)
            ClearCounts(
              accountId: r['account_id'] as String,
              accountName: '${r['account_name'] ?? ''}',
              status: '${r['status'] ?? 'off'}',
              total: _counts(r['total']),
              week: _counts(r['week']),
              since: DateTime.tryParse('${r['since'] ?? ''}')?.toLocal(),
              expiresAt: DateTime.tryParse('${r['expires_at'] ?? ''}'),
              lastChecked: DateTime.tryParse('${r['last_checked_at'] ?? ''}')?.toLocal(),
            ),
    ];

/// the counts of the signed in player, every account; empty for one not signed in
final clearCountsProvider = FutureProvider.autoDispose<List<ClearCounts>>((ref) async {
  if (!communityReady) return const [];
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const [];
  return parseClearCounts(await Supabase.instance.client.rpc('my_clear_counts'));
});

/// the counts of the account the active key is of, if it is counted or was
ClearCounts? clearsOf(List<ClearCounts> all, String? accountName) {
  final name = accountName?.toLowerCase();
  for (final c in all) {
    if (c.accountName.toLowerCase() == name) return c;
  }
  return null;
}

/// the legendaries of the account's armory: how many kinds, and how many in all
({int kinds, int total}) legendaryCount(List<Json> armory) {
  var total = 0;
  for (final r in armory) {
    total += r['count'] == null ? 1 : asInt(r['count']);
  }
  return (kinds: armory.length, total: total);
}

final legendaryCountProvider = FutureProvider.autoDispose<({int kinds, int total})>((ref) async {
  return legendaryCount(await accountApi(ref).legendaryArmory());
});

/// whether a key with these permissions can be counted: it has to read the progression
bool canCountClears(List<String> permissions) => permissions.contains('progression');

/// gives the server a subtoken of the active key that reads only [clearWatchUrls], for [clearWatchDays] days. the same
/// for a count that is there already, which is renewed. the account has to be one the player linked
Future<String> startClearWatch(Gw2Api api, {DateTime? now}) async {
  final expires = (now ?? DateTime.now()).toUtc().add(const Duration(days: clearWatchDays));
  final dynamic raw;
  try {
    raw = await api.get('/createsubtoken', {
      'permissions': 'account,progression',
      'expire': '${expires.toIso8601String().split('.').first}Z',
      'urls': clearWatchUrls.join(','),
    });
  } catch (e) {
    throw LinkFailure('subtoken_failed', detail: '$e');
  }
  final subtoken = raw is Map ? raw['subtoken'] : null;
  if (subtoken is! String || subtoken.isEmpty) throw const LinkFailure('subtoken_failed', detail: 'empty answer');
  try {
    final res = await Supabase.instance.client.functions.invoke('gw2-link', body: {
      'action': 'clear_watch',
      'subtoken': subtoken,
      'expires_at': expires.toIso8601String(),
    });
    final data = res.data;
    return data is Map ? '${data['account_name'] ?? ''}' : '';
  } on FunctionException catch (e) {
    final details = e.details;
    final code = details is Map && details['error'] is String ? details['error'] as String : 'http_${e.status}';
    throw LinkFailure(code, detail: 'HTTP ${e.status}');
  }
}

/// the server stops counting the account, and with [forget] forgets what it counted
Future<void> stopClearWatch(String accountId, {bool forget = false}) async {
  await Supabase.instance.client.rpc('stop_clear_watch', params: {'p_account': accountId, 'p_forget': forget});
}
