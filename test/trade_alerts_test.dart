import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wondrous_compass/l10n/strings.dart';
import 'package:wondrous_compass/state/api.dart';
import 'package:wondrous_compass/state/settings.dart';
import 'package:wondrous_compass/state/trade_alerts.dart';
import 'package:wondrous_compass/state/trade_notify.dart';
import 'package:wondrous_compass/util.dart';

Json _row(int id, int item, int price, int quantity) => {
  'id': id,
  'item_id': item,
  'price': price,
  'quantity': quantity,
  'created': '2026-10-03T10:00:00.000Z',
  'purchased': '2026-10-03T11:00:00.000Z',
};

/// the history and the names of the items, as the test says they are
class _Source implements TradeSource {
  _Source({
    this.sold = const [],
    this.bought = const [],
    this.itemNames = const {},
    this.failHistory,
    this.failNames = false,
  });

  List<Json> sold;
  List<Json> bought;
  Map<int, String> itemNames;
  Object? failHistory;
  bool failNames;
  final asked = <TradeSide>[];
  final namesAsked = <List<int>>[];

  @override
  Future<List<Json>> history(TradeSide side) async {
    asked.add(side);
    if (failHistory != null) throw failHistory!;
    return side == TradeSide.sold ? sold : bought;
  }

  @override
  Future<Map<int, String>> names(List<int> itemIds) async {
    namesAsked.add(itemIds);
    if (failNames) throw Exception('items are down');
    return {
      for (final id in itemIds)
        if (itemNames.containsKey(id)) id: itemNames[id]!,
    };
  }
}

const _en = S(AppLang.en);

void main() {
  group('the history of the trading post', () {
    test('is read into what completed: its number, the item, the price of one and how many', () {
      final fills = parseFills([_row(7, 19721, 12005, 3)], TradeSide.sold);
      expect(fills.single.id, 7);
      expect(fills.single.itemId, 19721);
      expect(fills.single.price, 12005);
      expect(fills.single.quantity, 3);
      expect(fills.single.side, TradeSide.sold);
      expect(fills.single.total, 36015, reason: 'all of them');
    });

    test('is read when the api gives numbers as text', () {
      final fill = parseFills([
        {'id': '9', 'item_id': '5', 'price': '100', 'quantity': '2'},
      ], TradeSide.bought).single;
      expect((fill.id, fill.itemId, fill.price, fill.quantity), (9, 5, 100, 2));
    });

    test('leaves out a row that is none, so that nothing is made up of it', () {
      final fills = parseFills([
        _row(1, 10, 5, 1),
        'junk',
        null,
        {'id': 2, 'item_id': 10, 'price': 5},
        {'id': 3, 'item_id': 10, 'price': 5, 'quantity': 0},
        {'id': 4, 'item_id': 0, 'price': 5, 'quantity': 1},
        {'id': 0, 'item_id': 10, 'price': 5, 'quantity': 1},
        {'id': 5, 'item_id': 10, 'price': -1, 'quantity': 1},
        _row(6, 11, 0, 2),
      ], TradeSide.sold);
      expect(fills.map((f) => f.id), [1, 6], reason: 'a price of nothing is a price');
    });

    test('has two sides, each with the name the api gives it', () {
      expect(TradeSide.sold.kind, 'history/sells');
      expect(TradeSide.bought.kind, 'history/buys');
    });
  });

  group('what was seen', () {
    test('is remembered once each, in the order it came, and the oldest are let go', () {
      expect(remember([1, 2], [3, 2, 4]), [1, 2, 3, 4]);
      expect(remember(const [], [5, 5, 5]), [5]);
      expect(remember([1, 2, 3], [4, 5], keep: 4), [2, 3, 4, 5]);
      expect(remember([1, 2, 3], const [], keep: 2), [2, 3], reason: 'also when nothing is added');
      expect(remember(List.generate(tradeSeenKeep, (i) => i), [100000]).length, tradeSeenKeep);
      expect(remember(List.generate(tradeSeenKeep, (i) => i), [100000]).last, 100000);
    });

    test('is what a look finds that is not in it', () {
      final fills = parseFills([_row(1, 1, 1, 1), _row(2, 1, 1, 1), _row(3, 1, 1, 1)], TradeSide.sold);
      expect(unseenFills(fills, [1, 3]).map((f) => f.id), [2]);
      expect(unseenFills(fills, const []).map((f) => f.id), [1, 2, 3]);
      expect(unseenFills(fills, [1, 2, 3]), isEmpty);
      expect(unseenFills(const [], [1]), isEmpty);
    });

    test('is written down and read again, for each side', () {
      const seen = TradeSeen(sold: [3, 2, 1], bought: [9]);
      final back = TradeSeen.parse(seen.toJson())!;
      expect(back.sold, [3, 2, 1]);
      expect(back.bought, [9]);
      expect(back.of(TradeSide.sold), [3, 2, 1]);
      expect(back.of(TradeSide.bought), [9]);
    });

    test('is none when there is nothing or what there is cannot be read, which is a first look', () {
      expect(TradeSeen.parse(null), isNull);
      expect(TradeSeen.parse(''), isNull);
      expect(TradeSeen.parse('not json'), isNull);
      expect(TradeSeen.parse('[1, 2]'), isNull);
      expect(TradeSeen.parse('"text"'), isNull);
      expect(TradeSeen.parse('{"sold": 5, "bought": "x"}')!.sold, isEmpty, reason: 'what is not a list is nothing');
      expect(TradeSeen.parse('{"sold": [1, "a", 2.5, null, 3]}')!.sold, [1, 3], reason: 'only numbers of transactions');
    });
  });

  group('what happened to an item', () {
    test('is its fills together: how many, and what they came to', () {
      final fills = parseFills([_row(1, 5, 100, 2), _row(2, 5, 150, 1), _row(3, 9, 50, 4)], TradeSide.sold);
      final lines = groupFills(fills);
      expect(lines.map((l) => (l.itemId, l.quantity, l.copper)), [(5, 3, 350), (9, 4, 200)]);
    });

    test('has the items that came to most first, and by their number among those that came to as much', () {
      final fills = parseFills([_row(1, 30, 100, 1), _row(2, 10, 100, 1), _row(3, 20, 500, 1)], TradeSide.sold);
      expect(groupFills(fills).map((l) => l.itemId), [20, 10, 30]);
      expect(groupFills(const []), isEmpty);
    });
  });

  group('a price', () {
    test('is written as the game writes it, the parts that are nothing left out', () {
      expect(coinsText(0), '0c');
      expect(coinsText(7), '7c');
      expect(coinsText(100), '1s');
      expect(coinsText(10000), '1g');
      expect(coinsText(10005), '1g 5c');
      expect(coinsText(12345), '1g 23s 45c');
      expect(coinsText(4200000), '420g');
      expect(coinsText(-5), '0c', reason: 'no price below nothing');
    });
  });

  group('what a notification says', () {
    test('is the quantity, the item and what it came to, with a title for what was sold', () {
      final n = composeTrade(
        _en,
        TradeSide.sold,
        const [TradeLine(itemId: 19685, quantity: 3, copper: 42000)],
        {19685: 'Mithril Ore'},
      );
      expect(n.title, 'Trading post: sold');
      expect(n.body, '3× Mithril Ore · 4g 20s');
      expect(n.side, TradeSide.sold);
    });

    test('has another title for what was bought', () {
      final n = composeTrade(
        _en,
        TradeSide.bought,
        const [TradeLine(itemId: 1, quantity: 250, copper: 100)],
        {1: 'Copper Ore'},
      );
      expect(n.title, 'Trading post: bought');
      expect(n.body, '250× Copper Ore · 1s');
    });

    test('has a line for each item, and says how many more when there are many', () {
      final lines = [for (var i = 1; i <= 9; i++) TradeLine(itemId: i, quantity: 1, copper: 100 * i)];
      final n = composeTrade(_en, TradeSide.sold, lines, {for (var i = 1; i <= 9; i++) i: 'Item $i'});
      final shown = n.body.split('\n');
      expect(shown.length, tradeLinesShown + 1);
      expect(shown.first, '1× Item 1 · 1s');
      expect(shown.last, '+3 more');
      expect(n.body.contains('Item 7'), isFalse);
      // exactly the number that fits has no "more"
      final fit = composeTrade(_en, TradeSide.sold, lines.take(tradeLinesShown).toList(), {
        for (var i = 1; i <= 9; i++) i: 'Item $i',
      });
      expect(fit.body.contains('more'), isFalse);
    });

    test('names an item by its number when its name is not known', () {
      final n = composeTrade(
        _en,
        TradeSide.sold,
        const [
          TradeLine(itemId: 77, quantity: 1, copper: 5),
          TradeLine(itemId: 78, quantity: 2, copper: 4),
          TradeLine(itemId: 79, quantity: 3, copper: 3),
        ],
        {78: '', 79: '   '},
      );
      expect(n.body.split('\n'), ['1× #77 · 5c', '2× #78 · 4c', '3× #79 · 3c']);
    });

    test('names the account when there are several', () {
      const lines = [TradeLine(itemId: 1, quantity: 1, copper: 1)];
      expect(
        composeTrade(_en, TradeSide.sold, lines, {1: 'X'}, account: 'Leo.1234').title,
        'Trading post: sold · Leo.1234',
      );
      expect(composeTrade(_en, TradeSide.sold, lines, {1: 'X'}, account: '').title, 'Trading post: sold');
      expect(composeTrade(_en, TradeSide.sold, lines, {1: 'X'}, account: '  ').title, 'Trading post: sold');
      expect(composeTrade(_en, TradeSide.sold, lines, {1: 'X'}).title, 'Trading post: sold');
    });

    test('is in the language of the app, and every language has every word', () {
      const lines = [TradeLine(itemId: 1, quantity: 2, copper: 12345), TradeLine(itemId: 2, quantity: 1, copper: 1)];
      final many = [for (var i = 1; i <= 8; i++) TradeLine(itemId: i, quantity: 1, copper: 10 * i)];
      for (final lang in AppLang.values) {
        final s = S(lang);
        final n = composeTrade(s, TradeSide.sold, lines, {1: 'Alpha', 2: 'Beta'});
        expect(n.title.isNotEmpty && !n.title.startsWith('tp_'), isTrue, reason: '${lang.code}: title');
        expect(n.body.contains('Alpha'), isTrue, reason: lang.code);
        expect(n.body.contains('1g 23s 45c'), isTrue, reason: lang.code);
        expect(n.body.contains('{'), isFalse, reason: '${lang.code}: nothing left to be filled in');
        final bought = composeTrade(s, TradeSide.bought, lines, {});
        expect(bought.title == n.title, isFalse, reason: '${lang.code}: sold and bought are two things');
        final more = composeTrade(s, TradeSide.sold, many, {}).body.split('\n').last;
        expect(more.contains('2'), isTrue, reason: '${lang.code}: how many more');
        expect(more.startsWith('tp_'), isFalse, reason: lang.code);
        for (final key in [
          'tp_notify_title',
          'tp_notify_hint',
          'tp_notify_needs_key',
          'tp_channel',
          'tp_channel_desc',
        ]) {
          expect(s.t(key), isNot(key), reason: '${lang.code}: $key');
        }
      }
      expect(composeTrade(const S(AppLang.tr), TradeSide.sold, lines, {1: 'A'}).title, 'Ticaret merkezi: satıldı');
    });
  });

  group('a look at the trading post', () {
    late SharedPreferences prefs;
    final told = <TradeNotification>[];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      told.clear();
    });

    Future<TradeCheckResult> look(
      _Source source, {
      String id = 'a',
      String? account,
      Future<void> Function(TradeNotification)? notify,
    }) => runTradeCheck(
      source: source,
      prefs: prefs,
      id: id,
      s: _en,
      account: account,
      notify: notify ?? (n) async => told.add(n),
    );

    test('tells nothing the first time: what is in the history happened before the player asked', () async {
      final source = _Source(sold: [_row(1, 5, 100, 1)], bought: [_row(2, 6, 100, 1)]);
      final result = await look(source);
      expect(result.first, isTrue);
      expect(told, isEmpty);
      expect(result.notified, 0);
      expect(TradeSeen.parse(prefs.getString('tp_seen_a'))!.sold, [1], reason: 'but it is noted');
      expect(source.namesAsked, isEmpty, reason: 'and nothing is asked of the api for it');
    });

    test('tells nothing when nothing completed since', () async {
      final source = _Source(sold: [_row(1, 5, 100, 1)]);
      await look(source);
      final result = await look(source);
      expect(result.first, isFalse);
      expect((result.sold, result.bought, result.notified), (0, 0, 0));
      expect(told, isEmpty);
      expect(source.namesAsked, isEmpty);
    });

    test('tells what was sold since, by name, and once', () async {
      final source = _Source(sold: [_row(1, 19685, 14000, 3)], itemNames: {19685: 'Mithril Ore', 5: 'Copper Ore'});
      await look(source);
      source.sold = [_row(2, 19685, 14000, 2), _row(1, 19685, 14000, 3)];
      final result = await look(source);
      expect((result.sold, result.bought, result.notified), (1, 0, 1));
      expect(told.single.title, 'Trading post: sold');
      expect(told.single.body, '2× Mithril Ore · 2g 80s');
      expect(source.namesAsked.single, [19685], reason: 'only the items that are told of are asked for');
      // looked at again with the same history, it is not told again
      await look(source);
      expect(told.length, 1);
    });

    test('tells what was bought as well, apart from what was sold', () async {
      final source = _Source(sold: [_row(1, 5, 100, 1)], bought: [_row(2, 6, 100, 1)], itemNames: {5: 'A', 6: 'B'});
      await look(source);
      source.sold = [_row(10, 5, 300, 1), ...source.sold];
      source.bought = [_row(11, 6, 50, 4), ...source.bought];
      final result = await look(source);
      expect((result.sold, result.bought, result.notified), (1, 1, 2));
      expect(told.map((n) => n.side), [TradeSide.sold, TradeSide.bought]);
      expect(told[1].body, '4× B · 2s');
      expect(source.namesAsked.single.toSet(), {5, 6}, reason: 'the names of both are asked for at once');
    });

    test('tells many sales of one item as one line, and many items as many lines', () async {
      final source = _Source(itemNames: {1: 'One', 2: 'Two'});
      await look(source);
      source.sold = [_row(5, 1, 100, 1), _row(4, 1, 100, 1), _row(3, 2, 500, 1)];
      await look(source);
      expect(told.single.body.split('\n'), ['1× Two · 5s', '2× One · 2s']);
    });

    test('names an item by its number when the names cannot be had, and tells all the same', () async {
      final source = _Source(failNames: true);
      await look(source);
      source.sold = [_row(1, 55, 100, 1)];
      final result = await look(source);
      expect(result.notified, 1);
      expect(told.single.body, '1× #55 · 1s');
    });

    test('names an account when the player has several', () async {
      final source = _Source();
      await look(source, account: 'Leo.1234');
      source.sold = [_row(1, 5, 100, 1)];
      await look(source, account: 'Leo.1234');
      expect(told.single.title, 'Trading post: sold · Leo.1234');
    });

    test(
      'is remembered before it is told: a notification that cannot be shown is not tried again at every look',
      () async {
        final source = _Source();
        await look(source);
        source.sold = [_row(1, 5, 100, 1)];
        final result = await look(source, notify: (_) async => throw Exception('the phone said no'));
        expect(result.notified, 0, reason: 'none was shown');
        expect(result.sold, 1);
        final again = await look(source);
        expect(again.sold, 0, reason: 'and it is not found new a second time');
        expect(told, isEmpty);
      },
    );

    test('tells the other side when one side cannot be shown', () async {
      final source = _Source();
      await look(source);
      source.sold = [_row(1, 5, 100, 1)];
      source.bought = [_row(2, 6, 100, 1)];
      var calls = 0;
      final result = await look(
        source,
        notify: (n) async {
          calls++;
          if (n.side == TradeSide.sold) throw Exception('no');
          told.add(n);
        },
      );
      expect(calls, 2);
      expect(result.notified, 1);
      expect(told.single.side, TradeSide.bought);
    });

    test('keeps what each account has seen apart', () async {
      final a = _Source(sold: [_row(1, 5, 100, 1)]);
      final b = _Source(sold: [_row(1, 5, 100, 1)]);
      await look(a, id: 'a');
      await look(b, id: 'b');
      a.sold = [_row(2, 5, 100, 1), ...a.sold];
      await look(a, id: 'a');
      expect(told.length, 1, reason: 'a had a sale');
      await look(b, id: 'b');
      expect(told.length, 1, reason: 'b had none, the same number of the same item in a does not make one');
      expect(prefs.getString('tp_seen_a'), isNot(prefs.getString('tp_seen_b')));
    });

    test('is a first look again when what was remembered is lost or cannot be read', () async {
      final source = _Source(sold: [_row(1, 5, 100, 1)]);
      await prefs.setString('tp_seen_a', 'garbage');
      final result = await look(source);
      expect(result.first, isTrue);
      expect(told, isEmpty);
    });

    test('says that it cannot look when the key may not read the trading post, and remembers nothing', () async {
      for (final status in [401, 403]) {
        final source = _Source(failHistory: Gw2ApiException('invalid key', status));
        final result = await look(source);
        expect(result.blocked, isTrue, reason: '$status');
        expect(prefs.getString('tp_seen_a'), isNull, reason: 'it is still a first look when the key is allowed');
        expect(told, isEmpty);
      }
    });

    test('lets a failure that is the network\'s or the api\'s go up, to be looked at again at the next look', () async {
      for (final error in [Gw2ApiException('busy', 503), Gw2ApiException('limit', 429), Exception('offline')]) {
        final source = _Source(failHistory: error);
        await expectLater(look(source), throwsA(anything), reason: '$error');
        expect(prefs.getString('tp_seen_a'), isNull);
      }
    });

    test('remembers no more than it keeps, and what it let go of is not told of again as long as the api no longer gives it', () async {
      final source = _Source();
      await look(source);
      var id = 1;
      for (var round = 0; round < 5; round++) {
        source.sold = [for (var i = 0; i < 200; i++) _row(id++, 5, 10, 1)];
        await look(source);
      }
      final seen = TradeSeen.parse(prefs.getString('tp_seen_a'))!;
      expect(seen.sold.length, tradeSeenKeep);
      expect(seen.sold.last, id - 1, reason: 'the newest are the ones kept');
      told.clear();
      await look(source);
      expect(told, isEmpty, reason: 'the same history is not new');
    });

    test('asks for the history of both sides, once each', () async {
      final source = _Source();
      await look(source);
      expect(source.asked, [TradeSide.sold, TradeSide.bought]);
    });
  });

  group('what an account is called in what is remembered of it', () {
    test('is a number made from its key, the same every time, and not the key', () {
      const key = 'A1B2C3D4-E5F6-1234-5678-ABCDEF012345ABCDEF012345-ABCD-1234-ABCD-1234567890AB';
      final id = tradeAccountId(key);
      expect(id, tradeAccountId(key));
      expect(id.length, 8);
      expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(id), isTrue);
      expect(key.toLowerCase().contains(id), isFalse);
      expect(tradeAccountId('$key-other'), isNot(id));
      expect(tradeAccountId(''), isNotEmpty);
    });
  });

  group('turning the notifications on', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer container({List<StoredKey> keys = const [StoredKey('Leo.1234', 'key')], _Effects? effects}) {
      final c = ProviderContainer(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          keysProvider.overrideWith(() => _Keys(keys)),
          tradeNotifyEffectsProvider.overrideWithValue(effects ?? _Effects()),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('is off until the player asks, and is what they asked the next time too', () async {
      expect(container().read(tradeNotifyProvider), isFalse);
      await prefs.setBool(tradeNotifyPref, true);
      expect(container().read(tradeNotifyProvider), isTrue);
    });

    test('asks for the permission, remembers the choice, asks for the look while the app is closed and makes the first look', () async {
      final effects = _Effects();
      final c = container(effects: effects);
      await c.read(keysProvider.future);
      final outcome = await c.read(tradeNotifyProvider.notifier).set(true);
      expect(outcome, TradeNotifyOutcome.on);
      expect(c.read(tradeNotifyProvider), isTrue);
      expect(prefs.getBool(tradeNotifyPref), isTrue);
      expect(effects.calls, ['allow', 'background:true', 'firstLook']);
    });

    test('needs a key, and asks nothing of the phone without one', () async {
      final effects = _Effects();
      final c = container(keys: const [], effects: effects);
      await c.read(keysProvider.future);
      expect(await c.read(tradeNotifyProvider.notifier).set(true), TradeNotifyOutcome.needsKey);
      expect(c.read(tradeNotifyProvider), isFalse);
      expect(prefs.getBool(tradeNotifyPref), isNull);
      expect(effects.calls, isEmpty);
    });

    test('is not on when the player does not allow notifications', () async {
      final effects = _Effects(allowed: false);
      final c = container(effects: effects);
      await c.read(keysProvider.future);
      expect(await c.read(tradeNotifyProvider.notifier).set(true), TradeNotifyOutcome.denied);
      expect(c.read(tradeNotifyProvider), isFalse);
      expect(prefs.getBool(tradeNotifyPref), isNull);
      expect(effects.calls, ['allow'], reason: 'no look while the app is closed is asked for');
    });

    test('is on all the same when the first look fails, the next look makes it', () async {
      final effects = _Effects(firstLookFails: true);
      final c = container(effects: effects);
      await c.read(keysProvider.future);
      expect(await c.read(tradeNotifyProvider.notifier).set(true), TradeNotifyOutcome.on);
      expect(c.read(tradeNotifyProvider), isTrue);
    });

    test(
      'lets go of the look while the app is closed when it is turned off, and does not ask for anything else',
      () async {
        final effects = _Effects();
        final c = container(effects: effects);
        await c.read(keysProvider.future);
        await c.read(tradeNotifyProvider.notifier).set(true);
        effects.calls.clear();
        expect(await c.read(tradeNotifyProvider.notifier).set(false), TradeNotifyOutcome.off);
        expect(c.read(tradeNotifyProvider), isFalse);
        expect(prefs.getBool(tradeNotifyPref), isFalse);
        expect(effects.calls, ['background:false']);
      },
    );

    test('can be turned off without a key, which is how it is got out of', () async {
      final effects = _Effects();
      final c = container(keys: const [], effects: effects);
      await c.read(keysProvider.future);
      expect(await c.read(tradeNotifyProvider.notifier).set(false), TradeNotifyOutcome.off);
      expect(effects.calls, ['background:false']);
    });
  });
}

/// the keys a player has, without the secure storage
class _Keys extends KeysNotifier {
  _Keys(this.list);

  final List<StoredKey> list;

  @override
  Future<List<StoredKey>> build() async => list;
}

/// what turning it on does to the phone, said and not done
class _Effects implements TradeNotifyEffects {
  _Effects({this.allowed = true, this.firstLookFails = false});

  final bool allowed;
  final bool firstLookFails;
  final calls = <String>[];

  @override
  Future<bool> allowNotifications() async {
    calls.add('allow');
    return allowed;
  }

  @override
  Future<void> background(bool on) async => calls.add('background:$on');

  @override
  Future<void> firstLook() async {
    calls.add('firstLook');
    if (firstLookFails) throw Exception('offline');
  }
}
