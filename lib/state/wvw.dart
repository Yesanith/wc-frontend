import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'account.dart';
import 'api.dart';

/// the team the account is assigned to. world vs world moved from worlds to
/// teams, older accounts may still only report a world
final wvwTeamProvider = FutureProvider<int>((ref) async {
  try {
    final wvw = await ref.watch(accountWvwProvider.future);
    final team = asInt(wvw['team'] ?? wvw['team_id']);
    if (team > 0) return team;
  } catch (_) {
    // fall back to the account object below
  }
  final account = await ref.watch(accountProvider.future);
  final nested = account['wvw'];
  final team = nested is Map ? asInt(nested['team_id'] ?? nested['team']) : 0;
  return team > 0 ? team : asInt(account['world']);
});

/// the live matchup of the account's team. never cached, it changes by the minute
final wvwMatchProvider = FutureProvider<Json?>((ref) async {
  final team = await ref.watch(wvwTeamProvider.future);
  if (team <= 0) return null;
  return ref.watch(gw2ApiProvider).wvwMatch(team);
});

/// old world ids are 1xxx in north america and 2xxx in europe, team ids
/// put the region in the second digit instead: 11xxx and 12xxx
String wvwRegion(int id) {
  final digits = '$id';
  final region = id >= 10000 && digits.length > 1 ? digits[1] : digits[0];
  return region == '2' ? 'eu' : 'na';
}

class WvwTimers {
  const WvwTimers(this.lockout, this.teamAssignment);
  final DateTime? lockout;
  final DateTime? teamAssignment;
}

final wvwTimersProvider = FutureProvider<WvwTimers>((ref) async {
  final api = ref.watch(gw2ApiProvider);
  final region = wvwRegion(await ref.watch(wvwTeamProvider.future));
  Future<DateTime?> read(String kind) async {
    try {
      final raw = await api.wvwTimer(kind);
      return DateTime.tryParse('${raw[region] ?? ''}')?.toLocal();
    } catch (_) {
      return null;
    }
  }

  final results = await Future.wait([read('lockout'), read('teamAssignment')]);
  return WvwTimers(results[0], results[1]);
});

/// which colour of the match the given team plays as
String? wvwColorOf(Json match, int team) {
  for (final key in ['all_worlds', 'worlds']) {
    final table = match[key];
    if (table is! Map) continue;
    for (final color in ['red', 'blue', 'green']) {
      final value = table[color];
      if (value is List && value.map(asInt).contains(team)) return color;
      if (value != null && asInt(value) == team) return color;
    }
  }
  return null;
}
