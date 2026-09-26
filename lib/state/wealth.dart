import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'settings.dart';

/// one day of the wallet: gold in copper, karma and gems
class WealthPoint {
  const WealthPoint(this.day, this.coins, this.karma, this.gems);

  /// yyyy-mm-dd in local time, one point per day
  final String day;
  final int coins;
  final int karma;
  final int gems;

  Map<String, dynamic> toJson() => {'d': day, 'c': coins, 'k': karma, 'g': gems};

  static WealthPoint fromJson(Map<String, dynamic> j) =>
      WealthPoint('${j['d']}', asInt(j['c']), asInt(j['k']), asInt(j['g']));
}

/// wallet currency ids the history keeps
const _coins = 1, _karma = 2, _gems = 4;

String _dayOf(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// a year of daily wallet snapshots per account, kept on the device only
class WealthNotifier extends Notifier<Map<String, List<WealthPoint>>> {
  static const _key = 'wealth_history';
  static const _keepDays = 365;

  @override
  Map<String, List<WealthPoint>> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map;
      return {
        for (final e in map.entries)
          '${e.key}': [
            for (final p in (e.value as List? ?? const []))
              if (p is Map) WealthPoint.fromJson(Map<String, dynamic>.from(p)),
          ],
      };
    } catch (_) {
      return const {};
    }
  }

  /// stores today's values, replacing an earlier snapshot of the same day
  Future<void> record(String account, List<WalletEntry> wallet, {DateTime? now}) async {
    if (account.isEmpty || wallet.isEmpty) return;
    int value(int id) {
      for (final e in wallet) {
        if (e.id == id) return e.value;
      }
      return 0;
    }

    final point = WealthPoint(_dayOf(now ?? DateTime.now()), value(_coins), value(_karma), value(_gems));
    final list = [...(state[account] ?? const <WealthPoint>[])];
    if (list.isNotEmpty && list.last.day == point.day) {
      final last = list.last;
      if (last.coins == point.coins && last.karma == point.karma && last.gems == point.gems) return;
      list[list.length - 1] = point;
    } else {
      list.add(point);
    }
    if (list.length > _keepDays) list.removeRange(0, list.length - _keepDays);
    state = {...state, account: list};
    await ref.read(prefsProvider).setString(
          _key,
          jsonEncode({for (final e in state.entries) e.key: e.value.map((p) => p.toJson()).toList()}),
        );
  }
}

final wealthProvider = NotifierProvider<WealthNotifier, Map<String, List<WealthPoint>>>(WealthNotifier.new);

/// the change of a value over the last [days] days, or since the first
/// snapshot when the history is younger than that. null with a single point
int? changeOver(List<WealthPoint> points, int days, int Function(WealthPoint) pick) {
  if (points.length < 2) return null;
  final last = points.last;
  final target = DateTime.parse(last.day).subtract(Duration(days: days));
  WealthPoint? base;
  for (final p in points) {
    if (!DateTime.parse(p.day).isAfter(target)) base = p;
  }
  base ??= points.first == last ? null : points.first;
  return base == null ? null : pick(last) - pick(base);
}
