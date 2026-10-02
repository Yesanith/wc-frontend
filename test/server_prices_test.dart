import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tyria_codex/api/gw2_api.dart';
import 'package:tyria_codex/state/price_history.dart';
import 'package:tyria_codex/state/server_prices.dart';

Map<String, dynamic> row(int id, {String? readAt, int buy = 90, int sell = 110}) => {
      'id': id,
      'buys': {'unit_price': buy, 'quantity': 10},
      'sells': {'unit_price': sell, 'quantity': 20},
      if (readAt != null) 'updated_at': readAt,
    };

void main() {
  final now = DateTime.utc(2026, 10, 2, 12);
  String ago(int minutes) => now.subtract(Duration(minutes: minutes)).toIso8601String();

  group('a price the server read', () {
    test('is the price now when it was read lately', () {
      expect(serverPriceFresh(row(1, readAt: ago(0)), now: now), isTrue);
      expect(serverPriceFresh(row(1, readAt: ago(10)), now: now), isTrue);
      expect(serverPriceFresh(row(1, readAt: ago(24)), now: now), isTrue);
    });

    test('is not, when it was read a while ago or says nothing of when', () {
      expect(serverPriceFresh(row(1, readAt: ago(25)), now: now), isFalse);
      expect(serverPriceFresh(row(1, readAt: ago(600)), now: now), isFalse);
      expect(serverPriceFresh(row(1), now: now), isFalse);
      expect(serverPriceFresh({'id': 1, 'updated_at': 'yesterday'}, now: now), isFalse);
    });

    test('a clock a few minutes ahead is forgiven, one far ahead is not', () {
      expect(serverPriceFresh(row(1, readAt: ago(-3)), now: now), isTrue);
      expect(serverPriceFresh(row(1, readAt: ago(-60)), now: now), isFalse);
    });
  });

  group('what the server answers', () {
    test('prices are the rows that have an id, and nothing else', () {
      expect(parseServerPrices([row(1), 'x', null, {'nothing': true}, row(2)]).map((e) => e['id']), [1, 2]);
      expect(parseServerPrices(null), isEmpty);
      expect(parseServerPrices({'id': 1}), isEmpty);
    });

    test('a history is its points, oldest first, whatever the order they came in', () {
      final points = parseServerHistory([
        {'d': '2026-10-02', 'b': 95, 's': 120},
        {'d': '2026-10-01', 'b': 90, 's': 110},
        {'d': '2026-10-03T00:00:00', 'b': 100, 's': 130},
        {'d': 'x', 'b': 1, 's': 1},
        'not a point',
      ]);
      expect(points.map((p) => p.day), ['2026-10-01', '2026-10-02', '2026-10-03']);
      expect(points[1].buy, 95);
      expect(points[1].sell, 120);
      expect(parseServerHistory(null), isEmpty);
    });
  });

  group('the history of the server and of the device together', () {
    PricePoint p(String day, int sell) => PricePoint(day, sell - 10, sell);

    test('has every day of both, the server\'s where both have it, oldest first', () {
      final merged = mergePriceHistory(
        [p('2026-10-02', 120), p('2026-10-03', 130)],
        [p('2026-09-30', 100), p('2026-10-02', 999)],
      );
      expect(merged.map((e) => e.day), ['2026-09-30', '2026-10-02', '2026-10-03']);
      expect(merged[1].sell, 120, reason: 'the server saw it all day');
      expect(merged.first.sell, 100, reason: 'before the server kept any');
    });

    test('is either one when the other has nothing', () {
      expect(mergePriceHistory(const [], [p('2026-10-01', 100)]).length, 1);
      expect(mergePriceHistory([p('2026-10-01', 100)], const []).length, 1);
      expect(mergePriceHistory(const [], const []), isEmpty);
    });
  });

  group('the prices asked of the api', () {
    /// a pretend game that says what was asked of it, and a pretend server
    ({Gw2Api api, List<List<int>> asked}) make({
      Future<List<Map<String, dynamic>>> Function(List<int> ids)? server,
    }) {
      final asked = <List<int>>[];
      final api = Gw2Api(
        null,
        serverPrices: server,
        client: MockClient((req) async {
          final ids = req.url.queryParameters['ids']!.split(',').map(int.parse).toList();
          asked.add(ids);
          return http.Response(jsonEncode([for (final id in ids) row(id, buy: 1, sell: 2)]), 200);
        }),
      );
      return (api: api, asked: asked);
    }

    test('come from the server when it read them lately, and the game is not asked', () async {
      final t = make(server: (ids) async => [for (final id in ids) row(id, readAt: DateTime.now().toIso8601String())]);
      final prices = await t.api.prices([1, 2, 3]);
      expect(prices.keys.toSet(), {1, 2, 3});
      expect(prices[1]!['buys']['unit_price'], 90, reason: "the server's price");
      expect(t.asked, isEmpty);
    });

    test('are asked of the game for the items the server has not read, or read long ago', () async {
      final t = make(
        server: (ids) async => [
          row(1, readAt: DateTime.now().toIso8601String()),
          row(2, readAt: DateTime.now().subtract(const Duration(hours: 3)).toIso8601String()),
        ],
      );
      final prices = await t.api.prices([1, 2, 3]);
      expect(prices.keys.toSet(), {1, 2, 3});
      expect(t.asked.single..sort(), [2, 3], reason: 'only the ones the server could not give');
      expect(prices[1]!['buys']['unit_price'], 90);
      expect(prices[2]!['buys']['unit_price'], 1, reason: 'the game\'s, the server\'s was old');
    });

    test('all come from the game when the server cannot be reached', () async {
      final t = make(server: (ids) async => throw Exception('no network'));
      final prices = await t.api.prices([1, 2]);
      expect(prices.keys.toSet(), {1, 2});
      expect(t.asked.single..sort(), [1, 2]);
    });

    test('all come from the game when there is no server, and when it knows nothing yet', () async {
      final none = make();
      expect((await none.api.prices([5, 6])).length, 2);
      expect(none.asked.single..sort(), [5, 6]);
      final empty = make(server: (ids) async => const []);
      expect((await empty.api.prices([5, 6])).length, 2);
      expect(empty.asked.single..sort(), [5, 6]);
    });

    test('are asked of the server two hundred at a time, and nothing is asked of either for no items', () async {
      var requests = <int>[];
      final t = make(server: (ids) async {
        requests.add(ids.length);
        return [for (final id in ids) row(id, readAt: DateTime.now().toIso8601String())];
      });
      await t.api.prices(List.generate(450, (i) => i + 1));
      expect(requests, [200, 200, 50]);
      requests = [];
      expect(await t.api.prices(const []), isEmpty);
      expect(await t.api.prices([0, -4]), isEmpty);
      expect(requests, isEmpty);
      expect(t.asked, isEmpty);
    });
  });
}
