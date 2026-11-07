import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/gw2_api.dart';
import 'community.dart';

/// the addresses the subtoken the server keeps may read, and nothing else: whose account it is, and the history of
/// what was sold and bought
const tradeWatchUrls = [
  '/v2/account',
  '/v2/commerce/transactions/history/sells',
  '/v2/commerce/transactions/history/buys',
];

/// how long a subtoken the server keeps lasts. the app makes a new one while it is used, before it runs out
const tradeWatchDays = 30;

/// a new subtoken is made when the one the server has runs out within this
const tradeWatchRenewWithin = Duration(days: 10);

/// one game account whose trading post the server watches for the player
class TradeWatch {
  const TradeWatch({required this.accountId, required this.accountName, required this.on, this.expiresAt});

  final String accountId;
  final String accountName;

  /// false when the game turned the subtoken down: the key was deleted, or it ran out
  final bool on;
  final DateTime? expiresAt;

  /// whether a new subtoken is due: it was turned down, or runs out soon
  bool renewalDue(DateTime now) => !on || expiresAt == null || expiresAt!.isBefore(now.add(tradeWatchRenewWithin));
}

/// the watches as the server lists them; what is not one is left out
List<TradeWatch> parseTradeWatches(Object? raw) => [
      if (raw is List)
        for (final r in raw)
          if (r is Map && r['account_id'] is String)
            TradeWatch(
              accountId: r['account_id'] as String,
              accountName: '${r['account_name'] ?? ''}',
              on: r['status'] == 'on',
              expiresAt: DateTime.tryParse('${r['expires_at'] ?? ''}'),
            ),
    ];

/// the trading posts the server watches for the signed in player
final tradeWatchesProvider = FutureProvider.autoDispose<List<TradeWatch>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const [];
  return parseTradeWatches(await Supabase.instance.client.rpc('my_trade_watches'));
});

/// whether a key with these permissions can be watched: it has to read the trading post
bool canWatchTrades(List<String> permissions) => permissions.contains('tradingpost');

/// a subtoken of the key that reads only [tradeWatchUrls], for [tradeWatchDays] days
Future<({String subtoken, DateTime expiresAt})> createTradeSubtoken(Gw2Api api, {DateTime? now}) async {
  final expires = (now ?? DateTime.now()).toUtc().add(const Duration(days: tradeWatchDays));
  final dynamic raw;
  try {
    raw = await api.get('/createsubtoken', {
      'permissions': 'account,tradingpost',
      'expire': '${expires.toIso8601String().split('.').first}Z',
      'urls': tradeWatchUrls.join(','),
    });
  } catch (e) {
    throw LinkFailure('subtoken_failed', detail: '$e');
  }
  final subtoken = raw is Map ? raw['subtoken'] : null;
  if (subtoken is! String || subtoken.isEmpty) throw const LinkFailure('subtoken_failed', detail: 'empty answer');
  return (subtoken: subtoken, expiresAt: expires);
}

/// gives the server a subtoken of the active key, so that it tells the player what its trading post did. the same for
/// a watch that is there already, which is renewed. the account has to be one the player linked
Future<String> startTradeWatch(Gw2Api api) async {
  final made = await createTradeSubtoken(api);
  try {
    final res = await Supabase.instance.client.functions.invoke('gw2-link', body: {
      'action': 'trade_watch',
      'subtoken': made.subtoken,
      'expires_at': made.expiresAt.toIso8601String(),
    });
    final data = res.data;
    return data is Map ? '${data['account_name'] ?? ''}' : '';
  } on FunctionException catch (e) {
    final details = e.details;
    final code = details is Map && details['error'] is String ? details['error'] as String : 'http_${e.status}';
    throw LinkFailure(code, detail: 'HTTP ${e.status}');
  }
}

/// the server stops watching, every account of the player, and forgets the subtokens
Future<void> stopTradeWatch() async {
  await Supabase.instance.client.rpc('stop_trade_watch');
}
