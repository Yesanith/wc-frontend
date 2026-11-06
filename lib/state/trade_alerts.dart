import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/gw2_api.dart';
import '../l10n/strings.dart';
import '../util.dart';

/// on when the player asked to be told what the trading post did for them: an item they listed was sold, or a buy order was filled
const tradeNotifyPref = 'tp_notify';

/// which side of the trading post: what the player sold, or what they bought
enum TradeSide {
  sold('history/sells'),
  bought('history/buys');

  const TradeSide(this.kind);

  /// what the api calls it, after /commerce/transactions/
  final String kind;
}

/// one transaction of the history that completed: a number that is its own, the item, the price of one and how many
class TradeFill {
  const TradeFill({
    required this.id,
    required this.itemId,
    required this.price,
    required this.quantity,
    required this.side,
  });

  final int id;
  final int itemId;
  final int price;
  final int quantity;
  final TradeSide side;

  /// what all of them came to, in copper
  int get total => price * quantity;
}

/// the transactions of the history, as the api gives them. a row that is not one (no number, no item, nothing bought or sold) is left out
List<TradeFill> parseFills(Iterable<Object?> rows, TradeSide side) {
  final out = <TradeFill>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final id = asInt(row['id']);
    final itemId = asInt(row['item_id']);
    final quantity = asInt(row['quantity']);
    final price = asInt(row['price']);
    if (id <= 0 || itemId <= 0 || quantity <= 0 || price < 0) continue;
    out.add(TradeFill(id: id, itemId: itemId, price: price, quantity: quantity, side: side));
  }
  return out;
}

/// how many numbers of transactions are remembered for each side. the history the api gives is the last two hundred, and a look is every quarter of an hour
const tradeSeenKeep = 600;

/// the transactions the last look knew of, for each side, oldest first. what a look finds that is not in them is what happened since
class TradeSeen {
  const TradeSeen({this.sold = const [], this.bought = const []});

  final List<int> sold;
  final List<int> bought;

  List<int> of(TradeSide side) => side == TradeSide.sold ? sold : bought;

  String toJson() => jsonEncode({'sold': sold, 'bought': bought});

  /// null when there is nothing, or what there is cannot be read: it is then the first look, which tells nobody of what happened before it
  static TradeSeen? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      List<int> ids(Object? v) => [
        for (final n in (v is List ? v : const []))
          if (n is int) n,
      ];
      return TradeSeen(sold: ids(map['sold']), bought: ids(map['bought']));
    } catch (_) {
      return null;
    }
  }
}

/// [add] put after what [before] has, each once, the oldest let go when there are more than [keep]
List<int> remember(List<int> before, Iterable<int> add, {int keep = tradeSeenKeep}) {
  final seen = before.toSet();
  final out = [...before];
  for (final id in add) {
    if (seen.add(id)) out.add(id);
  }
  return out.length > keep ? out.sublist(out.length - keep) : out;
}

/// what is in [fills] that is not in [seen]
List<TradeFill> unseenFills(List<TradeFill> fills, List<int> seen) {
  final known = seen.toSet();
  return [
    for (final fill in fills)
      if (!known.contains(fill.id)) fill,
  ];
}

/// all that happened to one item: how many, and what they came to
class TradeLine {
  const TradeLine({required this.itemId, required this.quantity, required this.copper});

  final int itemId;
  final int quantity;
  final int copper;
}

/// the fills of an item together, the ones that came to most first (and by the number of the item among those that came to as much)
List<TradeLine> groupFills(List<TradeFill> fills) {
  final byItem = <int, (int, int)>{};
  for (final fill in fills) {
    final (quantity, copper) = byItem[fill.itemId] ?? (0, 0);
    byItem[fill.itemId] = (quantity + fill.quantity, copper + fill.total);
  }
  final lines = [for (final e in byItem.entries) TradeLine(itemId: e.key, quantity: e.value.$1, copper: e.value.$2)]
    ..sort((a, b) => b.copper != a.copper ? b.copper.compareTo(a.copper) : a.itemId.compareTo(b.itemId));
  return lines;
}

/// copper as the game writes a price: 1g 20s 5c, the parts that are nothing left out, 0c for nothing
String coinsText(int copper) {
  final total = copper < 0 ? 0 : copper;
  final parts = [
    if (total ~/ 10000 > 0) '${total ~/ 10000}g',
    if ((total % 10000) ~/ 100 > 0) '${(total % 10000) ~/ 100}s',
    if (total % 100 > 0) '${total % 100}c',
  ];
  return parts.isEmpty ? '0c' : parts.join(' ');
}

/// how many items a notification names before it says how many more there were
const tradeLinesShown = 6;

/// what a notification says: its title, and the items it is about, one to a line
class TradeNotification {
  const TradeNotification({required this.side, required this.title, required this.body});

  final TradeSide side;
  final String title;
  final String body;
}

/// the notification of what happened on one side: what sold, or what was bought. [account] is the name of the account when the player has more than one
TradeNotification composeTrade(S s, TradeSide side, List<TradeLine> lines, Map<int, String> names, {String? account}) {
  final shown = lines.take(tradeLinesShown);
  final rest = lines.length - tradeLinesShown;
  final body = [
    for (final line in shown)
      s.t('tp_line', {
        'n': line.quantity,
        'item': (names[line.itemId] ?? '').trim().isEmpty ? '#${line.itemId}' : names[line.itemId]!.trim(),
        'coins': coinsText(line.copper),
      }),
    if (rest > 0) s.t('tp_more', {'n': rest}),
  ].join('\n');
  final base = s.t(side == TradeSide.sold ? 'tp_sold' : 'tp_bought');
  final who = (account ?? '').trim();
  return TradeNotification(side: side, title: who.isEmpty ? base : '$base · $who', body: body);
}

/// where a look gets the history and the names of the items from: the api, or a pretend one in a test
abstract interface class TradeSource {
  /// the newest transactions of one side
  Future<List<Json>> history(TradeSide side);

  /// what the items are called, those that are known
  Future<Map<int, String>> names(List<int> itemIds);
}

/// what a look found
class TradeCheckResult {
  const TradeCheckResult({this.first = false, this.sold = 0, this.bought = 0, this.notified = 0, this.blocked = false});

  /// the first look at this account, which only notes what is there
  final bool first;

  /// how many transactions of each side were new
  final int sold;
  final int bought;

  /// how many notifications were made of them
  final int notified;

  /// the key may not read the trading post: nothing can be told
  final bool blocked;
}

/// a look at the history of one account: what completed since the last look is told, a notification for what was sold and one for what was bought, and is remembered, so that it is told once.
/// the first look tells nothing: what is in the history then happened before the player asked to be told. [id] is what the account's remembered transactions are kept under
Future<TradeCheckResult> runTradeCheck({
  required TradeSource source,
  required SharedPreferences prefs,
  required String id,
  required S s,
  required Future<void> Function(TradeNotification notification) notify,
  String? account,
}) async {
  final storageKey = 'tp_seen_$id';
  final seen = TradeSeen.parse(prefs.getString(storageKey));
  final List<TradeFill> sold;
  final List<TradeFill> bought;
  try {
    sold = parseFills(await source.history(TradeSide.sold), TradeSide.sold);
    bought = parseFills(await source.history(TradeSide.bought), TradeSide.bought);
  } on Gw2ApiException catch (e) {
    // a key without the permission, or one that was taken away: there is nothing to look at
    if (e.kind == ApiErrorKind.unauthorized) return const TradeCheckResult(blocked: true);
    rethrow;
  }

  if (seen == null) {
    await prefs.setString(
      storageKey,
      TradeSeen(
        sold: remember(const [], sold.map((f) => f.id)),
        bought: remember(const [], bought.map((f) => f.id)),
      ).toJson(),
    );
    return const TradeCheckResult(first: true);
  }

  final newSold = unseenFills(sold, seen.sold);
  final newBought = unseenFills(bought, seen.bought);
  // remembered before it is told: a notification that cannot be shown is not tried again every quarter of an hour
  await prefs.setString(
    storageKey,
    TradeSeen(
      sold: remember(seen.sold, newSold.map((f) => f.id)),
      bought: remember(seen.bought, newBought.map((f) => f.id)),
    ).toJson(),
  );
  if (newSold.isEmpty && newBought.isEmpty) return const TradeCheckResult();

  var names = const <int, String>{};
  try {
    names = await source.names(
      {
        for (final f in [...newSold, ...newBought]) f.itemId,
      }.toList(),
    );
  } catch (_) {
    // the items are then told by their number
  }
  var notified = 0;
  for (final (side, fills) in [(TradeSide.sold, newSold), (TradeSide.bought, newBought)]) {
    if (fills.isEmpty) continue;
    try {
      await notify(composeTrade(s, side, groupFills(fills), names, account: account));
      notified++;
    } catch (_) {
      // the other side is told all the same
    }
  }
  return TradeCheckResult(sold: newSold.length, bought: newBought.length, notified: notified);
}

/// what an account is called in what is remembered of it: not its key, which is nobody's to keep a piece of, but a number made from it
String tradeAccountId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
