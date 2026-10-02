import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'settings.dart';

/// one day of an item's trading post prices, both in copper per unit.
/// 0 means nobody was buying or selling at the time
class PricePoint {
  const PricePoint(this.day, this.buy, this.sell);

  /// yyyy-mm-dd in local time, one point per day
  final String day;
  final int buy;
  final int sell;

  Map<String, dynamic> toJson() => {'d': day, 'b': buy, 's': sell};

  static PricePoint fromJson(Map<String, dynamic> j) => PricePoint('${j['d']}', asInt(j['b']), asInt(j['s']));
}

/// the server's history and the device's own as one: the server's where it has a day, the device's for the days only it saw. the days
/// the server has not kept yet (before the item was first asked for) come from the device
List<PricePoint> mergePriceHistory(List<PricePoint> server, List<PricePoint> device) {
  final byDay = {for (final p in device) p.day: p, for (final p in server) p.day: p};
  return byDay.values.toList()..sort((a, b) => a.day.compareTo(b.day));
}

String _dayOf(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// the trading post keeps no price history, so the app writes its own: one
/// point per item and day whenever it sees the price. only on this device
class PriceHistoryNotifier extends Notifier<Map<int, List<PricePoint>>> {
  static const _key = 'price_history';

  /// half a year per item
  static const keepDays = 180;

  /// items nobody watches or opened for this long are dropped, so the
  /// history does not grow with every item ever looked at
  static const forgetAfterDays = 30;

  @override
  Map<int, List<PricePoint>> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map;
      return {
        for (final e in map.entries)
          if (int.tryParse('${e.key}') != null)
            int.parse('${e.key}'): [
              for (final p in (e.value as List? ?? const []))
                if (p is Map) PricePoint.fromJson(Map<String, dynamic>.from(p)),
            ],
      };
    } catch (_) {
      return const {};
    }
  }

  /// stores today's prices of the given items. [prices] is the
  /// /commerce/prices answer keyed by item id
  Future<void> record(Map<int, Json> prices, {DateTime? now}) async {
    if (prices.isEmpty) return;
    final at = now ?? DateTime.now();
    final day = _dayOf(at);
    final next = {...state};
    var changed = false;
    for (final e in prices.entries) {
      final p = e.value;
      final buy = p['buys'] is Map ? asInt((p['buys'] as Map)['unit_price']) : 0;
      final sell = p['sells'] is Map ? asInt((p['sells'] as Map)['unit_price']) : 0;
      if (buy <= 0 && sell <= 0) continue;
      final point = PricePoint(day, buy, sell);
      final list = [...(next[e.key] ?? const <PricePoint>[])];
      if (list.isNotEmpty && list.last.day == day) {
        final last = list.last;
        if (last.buy == buy && last.sell == sell) continue;
        list[list.length - 1] = point;
      } else {
        list.add(point);
      }
      if (list.length > keepDays) list.removeRange(0, list.length - keepDays);
      next[e.key] = list;
      changed = true;
    }
    if (!changed) return;
    state = prune(next, ref.read(watchlistProvider).toSet(), at);
    await _save();
  }

  Future<void> replaceAll(Map<int, List<PricePoint>> history) async {
    state = history;
    await _save();
  }

  Future<void> _save() => ref.read(prefsProvider).setString(
        _key,
        jsonEncode({for (final e in state.entries) '${e.key}': e.value.map((p) => p.toJson()).toList()}),
      );
}

/// drops the history of items that are not watched and were not seen for
/// [PriceHistoryNotifier.forgetAfterDays]
Map<int, List<PricePoint>> prune(Map<int, List<PricePoint>> history, Set<int> watched, DateTime now) {
  final cutoff = _dayOf(now.subtract(const Duration(days: PriceHistoryNotifier.forgetAfterDays)));
  return {
    for (final e in history.entries)
      if (e.value.isNotEmpty && (watched.contains(e.key) || e.value.last.day.compareTo(cutoff) >= 0)) e.key: e.value,
  };
}

final priceHistoryProvider =
    NotifierProvider<PriceHistoryNotifier, Map<int, List<PricePoint>>>(PriceHistoryNotifier.new);

/// the points of the last [days] days, all of them when [days] is null
List<PricePoint> lastDays(List<PricePoint> points, int? days, {DateTime? now}) {
  if (days == null) return points;
  final cutoff = _dayOf((now ?? DateTime.now()).subtract(Duration(days: days)));
  return [
    for (final p in points)
      if (p.day.compareTo(cutoff) > 0) p,
  ];
}

/// percent change of a price between the first and last point, null when
/// either end has no price
double? percentChange(List<PricePoint> points, int Function(PricePoint) pick) {
  if (points.length < 2) return null;
  final first = pick(points.first);
  final last = pick(points.last);
  if (first <= 0 || last <= 0) return null;
  return (last - first) / first * 100;
}
