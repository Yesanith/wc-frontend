import 'package:shared_preferences/shared_preferences.dart';

import '../api/gw2_api.dart';
import '../l10n/strings.dart';
import '../state/api.dart';
import '../state/trade_alerts.dart';
import '../util.dart';
import 'boss_alerts.dart';

/// the history and the names of the items, from the api
class ApiTradeSource implements TradeSource {
  const ApiTradeSource(this.api);

  final Gw2Api api;

  @override
  Future<List<Json>> history(TradeSide side) => api.recentTransactions(side.kind);

  @override
  Future<Map<int, String>> names(List<int> itemIds) async {
    final items = await api.items(itemIds);
    return {
      for (final e in items.entries)
        if ('${e.value['name'] ?? ''}'.trim().isNotEmpty) e.key: '${e.value['name']}'.trim(),
    };
  }
}

/// a look at the trading post of every account the player added: what was sold or bought since the last look is shown as a notification, in the language of the app.
/// an account that cannot be looked at (its key may not read the trading post, the api is down) is left, the others are looked at all the same. how many notifications were made.
/// it runs in the app and in the background, which has no providers: everything it needs is given
Future<int> checkTradingPost({
  required List<StoredKey> keys,
  required SharedPreferences prefs,
  required AppLang lang,
  DateTime? now,
}) async {
  final s = S(lang);
  var notified = 0;
  var serial = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  for (final key in keys) {
    final api = Gw2Api(key.key, lang: lang.apiLang);
    try {
      final result = await runTradeCheck(
        source: ApiTradeSource(api),
        prefs: prefs,
        id: tradeAccountId(key.key),
        s: s,
        account: keys.length > 1 ? key.name : null,
        notify: (n) => showTradeNotification(
          // one of its own for each, or the second would take the place of the first
          id: (serial++ % 0x7FFFFFFF),
          title: n.title,
          body: n.body,
          channelName: s.t('tp_channel'),
          channelDescription: s.t('tp_channel_desc'),
        ),
      );
      notified += result.notified;
    } catch (_) {
      // this account is looked at again at the next look
    } finally {
      api.close();
    }
  }
  return notified;
}
