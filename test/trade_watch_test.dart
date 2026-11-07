import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/trade_watch.dart';

void main() {
  test('the watches are read as the server lists them, and what is not one is left out', () {
    final watches = parseTradeWatches([
      {'account_id': 'a1', 'account_name': 'Ola.1234', 'status': 'on', 'expires_at': '2026-12-01T00:00:00Z'},
      {'account_id': 'a2', 'account_name': 'Per.5678', 'status': 'refused', 'expires_at': null},
      {'nothing': true},
      'no',
    ]);
    expect(watches.map((w) => w.accountName), ['Ola.1234', 'Per.5678']);
    expect(watches.first.on, isTrue);
    expect(watches.last.on, isFalse);
    expect(parseTradeWatches(null), isEmpty);
  });

  test('a new subtoken is made when it was turned down or runs out within ten days', () {
    final now = DateTime.utc(2026, 11, 7);
    TradeWatch watch({bool on = true, DateTime? expires}) =>
        TradeWatch(accountId: 'a', accountName: 'A.1', on: on, expiresAt: expires);
    expect(watch(expires: now.add(const Duration(days: 25))).renewalDue(now), isFalse);
    expect(watch(expires: now.add(const Duration(days: 5))).renewalDue(now), isTrue);
    expect(watch(on: false, expires: now.add(const Duration(days: 25))).renewalDue(now), isTrue);
    expect(watch().renewalDue(now), isTrue);
  });

  test('only a key that reads the trading post can be watched, and the server is given only the history', () {
    expect(canWatchTrades(['account', 'tradingpost']), isTrue);
    expect(canWatchTrades(['account', 'wallet']), isFalse);
    expect(tradeWatchUrls, [
      '/v2/account',
      '/v2/commerce/transactions/history/sells',
      '/v2/commerce/transactions/history/buys',
    ]);
  });
}
