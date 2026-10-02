import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/alerts.dart';
import 'package:tyria_codex/state/server_price_alerts.dart';

class FakeAlerts implements PriceAlertBackend {
  FakeAlerts({this.remote = const [], this.failFetch = false, this.failSend = false});

  final List<ServerAlert> remote;
  final bool failFetch;
  final bool failSend;
  final sent = <(int, String, PriceAlert?)>[];

  @override
  Future<List<ServerAlert>> fetch() async {
    if (failFetch) throw Exception('no network');
    return remote;
  }

  @override
  Future<void> send(int itemId, String name, PriceAlert? alert) async {
    if (failSend) throw Exception('no network');
    sent.add((itemId, name, alert));
  }
}

void main() {
  const sell = PriceAlert(sellBelow: 12000);
  const buy = PriceAlert(buyAbove: 9000);
  const both = PriceAlert(sellBelow: 12000, buyAbove: 9000);

  group('what the server is told of', () {
    test('is an alert it has not, and one it has with other prices', () {
      final remote = [
        const ServerAlert(itemId: 1, name: 'a', sellBelow: 12000),
        const ServerAlert(itemId: 2, name: 'b', sellBelow: 5000),
        const ServerAlert(itemId: 3, name: 'c', buyAbove: 9000),
      ];
      final local = {1: sell, 2: sell, 3: both, 4: buy};
      expect(alertsToSend(local, remote), [2, 3, 4], reason: 'not 1, which it has as it is');
    });

    test('is never an alert it has as it is, which would make it ready to be sent again', () {
      final remote = [const ServerAlert(itemId: 1, name: 'a', sellBelow: 12000, buyAbove: 9000)];
      expect(alertsToSend({1: both}, remote), isEmpty);
    });

    test('is not what it has and the device has not, it may be another device\'s', () {
      final remote = [const ServerAlert(itemId: 9, name: 'other', sellBelow: 1)];
      expect(alertsToSend({}, remote), isEmpty);
      expect(alertsToSend({1: sell}, remote), [1]);
    });

    test('is not an alert with no price in it', () {
      expect(alertsToSend({1: const PriceAlert()}, const []), isEmpty);
    });

    test('is everything when the server has nothing', () {
      expect(alertsToSend({3: sell, 1: buy, 2: both}, const []), [3, 1, 2]);
    });
  });

  group('an alert of the server', () {
    test('is read from what the server says, with none of the prices when it has none', () {
      final a = ServerAlert.parse({'item_id': 19721, 'name': 'Greatsword', 'sell_below': 12000, 'buy_above': null, 'armed': true})!;
      expect([a.itemId, a.name, a.sellBelow, a.buyAbove], [19721, 'Greatsword', 12000, null]);
      expect(ServerAlert.parse({'item_id': 5})!.name, '');
      expect(ServerAlert.parse({'name': 'no item'}), isNull);
      expect(ServerAlert.parse('text'), isNull);
      expect(ServerAlert.parse(null), isNull);
    });
  });

  group('the mirror', () {
    test('tells the server of an alert that was set, with its name and its prices', () async {
      final backend = FakeAlerts();
      await PriceAlertMirror(backend).mirror(5, 'Greatsword', both);
      expect(backend.sent.single, (5, 'Greatsword', both));
    });

    test('tells the server of an alert that was taken away, with none', () async {
      final backend = FakeAlerts();
      await PriceAlertMirror(backend).mirror(5, 'Greatsword', const PriceAlert());
      expect(backend.sent.single.$3!.isEmpty, isTrue);
    });

    test('does not mind when the server cannot be reached, the alert on the device is the same', () async {
      await PriceAlertMirror(FakeAlerts(failSend: true)).mirror(5, 'x', sell);
    });

    test('tells the server of the alerts of the device that it does not have as they are, with their names', () async {
      final backend = FakeAlerts(remote: [const ServerAlert(itemId: 1, name: 'a', sellBelow: 12000)]);
      await PriceAlertMirror(backend).syncAll({1: sell, 2: buy, 3: both}, (id) => 'item $id');
      expect(backend.sent.map((s) => (s.$1, s.$2)), [(2, 'item 2'), (3, 'item 3')]);
    });

    test('tells the server of nothing when it has them all', () async {
      final backend = FakeAlerts(remote: [const ServerAlert(itemId: 1, name: 'a', sellBelow: 12000)]);
      await PriceAlertMirror(backend).syncAll({1: sell}, (id) => 'x');
      expect(backend.sent, isEmpty);
    });

    test('does not mind when it cannot ask what the server has, or tell it', () async {
      await PriceAlertMirror(FakeAlerts(failFetch: true)).syncAll({1: sell}, (id) => 'x');
      await PriceAlertMirror(FakeAlerts(failSend: true)).syncAll({1: sell}, (id) => 'x');
    });
  });
}
