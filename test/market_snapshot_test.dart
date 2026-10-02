import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/market.dart';

void main() {
  final now = DateTime.utc(2026, 10, 2, 12);
  String ago(int minutes) => now.subtract(Duration(minutes: minutes)).toIso8601String();

  group('the list the server made', () {
    test('is the prices now when it was read lately, and not when it was a while ago', () {
      expect(snapshotFresh(now, now: now), isTrue);
      expect(snapshotFresh(now.subtract(const Duration(minutes: 12)), now: now), isTrue);
      expect(snapshotFresh(now.subtract(const Duration(minutes: 29)), now: now), isTrue);
      expect(snapshotFresh(now.subtract(const Duration(minutes: 30)), now: now), isFalse);
      expect(snapshotFresh(now.subtract(const Duration(days: 2)), now: now), isFalse);
    });

    test('a clock a few minutes ahead is forgiven, one far ahead is not', () {
      expect(snapshotFresh(now.add(const Duration(minutes: 3)), now: now), isTrue);
      expect(snapshotFresh(now.add(const Duration(hours: 5)), now: now), isFalse);
    });

    test('is its rows as prices, a row being the id, the buy price, the sell price and the quantities', () {
      final snapshot = parseServerSnapshot({
        'updated_at': ago(3),
        'count': 2,
        'rows': [
          [19721, 90, 110, 5000, 3000],
          [19976, 0, 0, 0, 0],
        ],
      })!;
      expect(snapshot.at, DateTime.parse(ago(3)));
      expect(snapshot.prices.length, 2);
      final p = snapshot.prices[19721]!;
      expect([p.buy, p.sell, p.demand, p.supply], [90, 110, 5000, 3000]);
      expect(snapshot.prices[19976]!.flip, 0, reason: 'nobody trades it');
    });

    test('is nothing when it is not one: the server has not read yet, or answered something else', () {
      expect(parseServerSnapshot(null), isNull);
      expect(parseServerSnapshot('text'), isNull);
      expect(parseServerSnapshot([]), isNull);
      expect(
          parseServerSnapshot({
            'updated_at': null,
            'rows': [
              [1, 1, 1, 1, 1]
            ]
          }),
          isNull,
          reason: 'nothing read yet');
      expect(parseServerSnapshot({'updated_at': ago(1), 'rows': []}), isNull);
      expect(parseServerSnapshot({'updated_at': ago(1), 'rows': 'x'}), isNull);
      expect(
          parseServerSnapshot({
            'updated_at': 'yesterday',
            'rows': [
              [1, 1, 1, 1, 1]
            ]
          }),
          isNull);
    });

    test('has the same rows as the copy kept on the device, so one is read as the other', () {
      final prices = {7: const TpPrice(10, 30, 4, 6), 8: const TpPrice(0, 5, 0, 9)};
      final rows = encodeMarketPrices(prices);
      final again = parseServerSnapshot({'updated_at': ago(0), 'rows': rows})!.prices;
      expect(again.keys, prices.keys);
      expect(again[7]!.sell, 30);
      expect(again[8]!.supply, 9);
    });
  });
}
