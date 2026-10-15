import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../util.dart';
import 'api.dart';
import 'settings.dart';

/// the rate of 100 gems at one moment, both sides in copper
class GemPoint {
  const GemPoint(this.at, this.buy, this.sell);

  final DateTime at;

  /// what 100 gems cost in gold
  final int buy;

  /// what 100 gems bring when sold for gold
  final int sell;
}

/// written every six hours by the gem history workflow on its own branch
const gemHistoryUrl = 'https://raw.githubusercontent.com/Yesanith/tyria-companion/gem-history/gems.json';

/// what the chart spans
const gemHistoryDays = 30;

/// {"points": [[unix seconds, buy, sell], ...]}
List<GemPoint> parseGemHistory(String body) {
  final raw = jsonDecode(body);
  if (raw is! Map || raw['points'] is! List) return const [];
  return [
    for (final p in raw['points'] as List)
      if (p is List && p.length >= 3)
        GemPoint(DateTime.fromMillisecondsSinceEpoch(asInt(p[0]) * 1000, isUtc: true), asInt(p[1]), asInt(p[2])),
  ];
}

/// the cost of 100 gems from the gems 100 gold buy
int buyFor100Gems(int gemsFor100Gold) => gemsFor100Gold <= 0 ? 0 : (100000000 / gemsFor100Gold).round();

/// shared and local readings together, one per hour, within [days]
List<GemPoint> mergeGemPoints(List<GemPoint> a, List<GemPoint> b, {required DateTime now, int days = gemHistoryDays}) {
  final from = now.subtract(Duration(days: days));
  final byHour = <int, GemPoint>{};
  for (final p in [...a, ...b]) {
    if (p.at.isBefore(from) || p.buy <= 0 || p.sell <= 0) continue;
    byHour[p.at.millisecondsSinceEpoch ~/ 3600000] = p;
  }
  return byHour.values.toList()..sort((x, y) => x.at.compareTo(y.at));
}

/// the rates this device has seen, a backup for when the shared history is
/// out of reach and a head start while it is still young
class LocalGemsNotifier extends Notifier<List<GemPoint>> {
  static const _key = 'gem_rates_local';

  @override
  List<GemPoint> build() {
    final raw = ref.read(prefsProvider).getString(_key);
    return raw == null ? const [] : parseGemHistory(raw);
  }

  Future<void> record(int buy, int sell, {DateTime? now}) async {
    if (buy <= 0 || sell <= 0) return;
    final at = (now ?? DateTime.now()).toUtc();
    final next = mergeGemPoints(state, [GemPoint(at, buy, sell)], now: at, days: gemHistoryDays + 10);
    state = next;
    await ref.read(prefsProvider).setString(
          _key,
          jsonEncode({
            'points': [
              for (final p in next) [p.at.millisecondsSinceEpoch ~/ 1000, p.buy, p.sell]
            ],
          }),
        );
  }
}

final localGemsProvider = NotifierProvider<LocalGemsNotifier, List<GemPoint>>(LocalGemsNotifier.new);

final _client = http.Client();

/// the shared recording, fetched once and kept on disk for when the network
/// is away. apart from the device's readings, so a new reading does not
/// download the whole history again
final sharedGemHistoryProvider = FutureProvider<List<GemPoint>>((ref) async {
  final cache = ref.watch(diskCacheProvider);
  try {
    final res = await _client.get(Uri.parse(gemHistoryUrl)).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      final body = utf8.decode(res.bodyBytes);
      await cache?.write('gem_history', {'body': body});
      return parseGemHistory(body);
    }
  } catch (_) {
    // the disk copy below
  }
  final cached = await cache?.read('gem_history', maxAge: const Duration(days: 30));
  return cached?['body'] is String ? parseGemHistory(cached!['body'] as String) : const [];
});

/// thirty days of the gem exchange, from the shared recording and the
/// device's own readings
final gemHistoryProvider = Provider<AsyncValue<List<GemPoint>>>((ref) {
  final local = ref.watch(localGemsProvider);
  return ref
      .watch(sharedGemHistoryProvider)
      .whenData((shared) => mergeGemPoints(shared, local, now: DateTime.now().toUtc()));
});
