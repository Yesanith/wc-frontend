import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'api.dart';
import 'settings.dart';

/// a price watch on one item: tell me when the cheapest listing drops to
/// [sellBelow] or when the best buy order reaches [buyAbove], both in copper
class PriceAlert {
  const PriceAlert({this.sellBelow, this.buyAbove});

  final int? sellBelow;
  final int? buyAbove;

  bool get isEmpty => sellBelow == null && buyAbove == null;

  Map<String, dynamic> toJson() => {
        if (sellBelow != null) 'sell': sellBelow,
        if (buyAbove != null) 'buy': buyAbove,
      };

  static PriceAlert fromJson(Map<String, dynamic> j) => PriceAlert(
        sellBelow: j['sell'] == null ? null : asInt(j['sell']),
        buyAbove: j['buy'] == null ? null : asInt(j['buy']),
      );

  /// whether the current prices meet either condition
  bool triggeredBy({required int sell, required int buy}) =>
      (sellBelow != null && sell > 0 && sell <= sellBelow!) || (buyAbove != null && buy > 0 && buy >= buyAbove!);
}

class PriceAlertsNotifier extends Notifier<Map<int, PriceAlert>> {
  static const _key = 'price_alerts';

  @override
  Map<int, PriceAlert> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map;
      return {
        for (final e in map.entries)
          if (e.value is Map) int.parse('${e.key}'): PriceAlert.fromJson(Map<String, dynamic>.from(e.value as Map)),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> set(int itemId, PriceAlert? alert) async {
    final next = {...state};
    if (alert == null || alert.isEmpty) {
      next.remove(itemId);
    } else {
      next[itemId] = alert;
    }
    state = next;
    await ref.read(prefsProvider).setString(_key, jsonEncode({for (final e in next.entries) '${e.key}': e.value.toJson()}));
  }
}

final priceAlertsProvider = NotifierProvider<PriceAlertsNotifier, Map<int, PriceAlert>>(PriceAlertsNotifier.new);

/// item ids whose alert condition holds at the current prices
final triggeredAlertsProvider = FutureProvider<Set<int>>((ref) async {
  final alerts = ref.watch(priceAlertsProvider);
  if (alerts.isEmpty) return const {};
  final prices = await ref.watch(gw2ApiProvider).prices(alerts.keys);
  final out = <int>{};
  for (final e in alerts.entries) {
    final p = prices[e.key];
    final sell = p?['sells'] is Map ? asInt((p!['sells'] as Map)['unit_price']) : 0;
    final buy = p?['buys'] is Map ? asInt((p!['buys'] as Map)['unit_price']) : 0;
    if (e.value.triggeredBy(sell: sell, buy: buy)) out.add(e.key);
  }
  return out;
});

/// "1.25" gold as copper, null for anything that is not a positive number
int? goldToCopper(String input) {
  final value = double.tryParse(input.trim().replaceAll(',', '.'));
  if (value == null || value <= 0) return null;
  return (value * 10000).round();
}

/// copper as a gold number with up to four decimals, for editing
String copperToGold(int copper) {
  final text = (copper / 10000).toStringAsFixed(4);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
