import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/api/gw2_api.dart';
import 'package:wondrous_compass/state/market.dart';

void main() {
  group('retry delay', () {
    test('follows Retry-After when the api sends it', () {
      expect(retryDelay('3', 0), const Duration(seconds: 3));
      expect(retryDelay(' 5 ', 2), const Duration(seconds: 5));
    });

    test('backs off 1, 2, 4 seconds otherwise and never waits over ten', () {
      expect(retryDelay(null, 0), const Duration(seconds: 1));
      expect(retryDelay(null, 1), const Duration(seconds: 2));
      expect(retryDelay('soon', 2), const Duration(seconds: 4));
      expect(retryDelay('120', 0), const Duration(seconds: 10));
    });
  });

  test('the shared gate is small enough for the rate limit', () {
    expect(Gw2Api.maxParallel, inInclusiveRange(2, 8));
  });

  test('market prices survive the disk copy', () {
    const prices = {19684: TpPrice(120, 150, 3000, 900), 12: TpPrice(0, 7, 0, 5)};
    final back = decodeMarketPrices(encodeMarketPrices(prices));
    expect(back.keys, unorderedEquals([19684, 12]));
    expect(back[19684]!.sell, 150);
    expect(back[19684]!.supply, 900);
    expect(back[12]!.buy, 0);
    expect(
        decodeMarketPrices([
          'junk',
          [1, 2]
        ]),
        isEmpty);
  });
}
