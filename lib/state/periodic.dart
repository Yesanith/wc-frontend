import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';
import 'account.dart';
import 'api.dart';
import 'progression.dart';
import 'settings.dart';

/// the next daily reset, midnight utc
DateTime nextDailyReset([DateTime? now]) {
  final n = (now ?? DateTime.now()).toUtc();
  return DateTime.utc(n.year, n.month, n.day + 1);
}

/// the next weekly reset, monday 07:30 utc
DateTime nextWeeklyReset([DateTime? now]) {
  final n = (now ?? DateTime.now()).toUtc();
  var reset = DateTime.utc(n.year, n.month, n.day, 7, 30);
  while (reset.weekday != DateTime.monday || !reset.isAfter(n)) {
    reset = reset.add(const Duration(days: 1));
  }
  return reset;
}

/// "5h 12m" style time left until [at]
String timeUntil(DateTime at, {DateTime? now}) {
  final left = at.difference((now ?? DateTime.now()).toUtc());
  if (left.isNegative) return '0m';
  final days = left.inDays;
  final hours = left.inHours % 24;
  final minutes = left.inMinutes % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

/// a rotating achievement category with today's entries
class PeriodicCategory {
  const PeriodicCategory(this.name, this.icon, this.rows);
  final String name;
  final String? icon;
  final List<AchievementRow> rows;

  int get done => rows.where((r) => r.done).length;
}

/// whether an entry of a daily category applies to this account. entries can
/// ask for an expansion, or for not owning one
bool entryApplies(Json entry, Set<String> access) {
  final req = entry['required_access'];
  if (req is! Map) return true;
  final product = '${req['product'] ?? ''}';
  final owns = access.contains(product);
  return req['condition'] == 'NoAccess' ? !owns : owns;
}

String _utcDay(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// rotating achievements split by their own flag: the weekly ones go to the
/// weekly page even when they share a category with daily ones
class PeriodicAchievements {
  const PeriodicAchievements(this.daily, this.weekly);
  final List<PeriodicCategory> daily;
  final List<PeriodicCategory> weekly;
}

bool _isWeekly(Json? detail) => ((detail?['flags'] as List?) ?? const []).contains('Weekly');

/// today's rotating achievements, such as the daily fractals. the category
/// list is fetched fresh after every daily reset, the monthly catalogue cache
/// would show yesterday's picks
final periodicAchievementsProvider = FutureProvider<PeriodicAchievements>((ref) async {
  final api = accountApi(ref);
  final cache = ref.watch(diskCacheProvider);
  final lang = ref.watch(langProvider);
  final today = _utcDay(DateTime.now().toUtc());
  final name = 'ach_daily_${lang.apiLang}';

  var categories = <Json>[];
  final cached = await cache?.read(name, maxAge: const Duration(hours: 25));
  if (cached != null && cached['day'] == today && cached['rows'] is List) {
    categories = (cached['rows'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  } else {
    // only rotating categories carry a "tomorrow" list
    categories = (await api.allOf('/achievements/categories')).where((c) => c.containsKey('tomorrow')).toList();
    await cache?.write(name, {'day': today, 'rows': categories});
  }
  if (categories.isEmpty) return const PeriodicAchievements([], []);

  final account = await ref.watch(accountProvider.future);
  final access = {for (final a in (account['access'] as List?) ?? const []) '$a'};
  final idsByCategory = <Json, List<int>>{};
  for (final c in categories) {
    idsByCategory[c] = [
      for (final e in (c['achievements'] as List?) ?? const [])
        if (e is! Map || entryApplies(Map<String, dynamic>.from(e), access)) asInt(e is Map ? e['id'] : e),
    ];
  }
  final allIds = {for (final ids in idsByCategory.values) ...ids};
  final details = await api.achievements(allIds);
  var progress = const <int, Json>{};
  try {
    progress = {for (final r in await api.accountAchievements()) asInt(r['id']): r};
  } catch (_) {
    // without the progression permission the list still shows, unticked
  }

  int topTier(Json? detail) {
    var top = 0;
    for (final t in (detail?['tiers'] as List?) ?? const []) {
      if (t is Map && asInt(t['count']) > top) top = asInt(t['count']);
    }
    return top;
  }

  AchievementRow row(int id) => AchievementRow(
        id,
        details[id],
        asInt(progress[id]?['current']),
        progress[id]?['max'] != null ? asInt(progress[id]?['max']) : topTier(details[id]),
        progress[id]?['done'] == true,
      );

  final daily = <PeriodicCategory>[];
  final weekly = <PeriodicCategory>[];
  for (final entry in idsByCategory.entries) {
    final name = '${entry.key['name'] ?? ''}';
    final icon = entry.key['icon'] as String?;
    final d = [for (final id in entry.value) if (!_isWeekly(details[id])) row(id)];
    final w = [for (final id in entry.value) if (_isWeekly(details[id])) row(id)];
    if (d.isNotEmpty) daily.add(PeriodicCategory(name, icon, d));
    if (w.isNotEmpty) weekly.add(PeriodicCategory(name, icon, w));
  }
  daily.sort((a, b) => a.name.compareTo(b.name));
  weekly.sort((a, b) => a.name.compareTo(b.name));
  return PeriodicAchievements(daily, weekly);
});
