import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';
import 'account.dart';
import 'api.dart';
import 'community.dart';
import 'period_refresh.dart';
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
  const PeriodicCategory(this.name, this.icon, this.rows, {this.id = 0});
  final int id;
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

/// the categories the administrator keeps off the daily and weekly pages (the festivals that are over), by the game's id. none when
/// the community backend cannot be reached. asked again every ten minutes while a page is open
Future<Set<int>> _readHiddenCategories() async {
  try {
    final v = await Supabase.instance.client.rpc('app_hidden_categories');
    return {
      if (v is List)
        for (final e in v)
          if (e is num) e.toInt()
    };
  } catch (_) {
    return const {};
  }
}

/// asked again every ten minutes, and told to the pages only when it changed: each new answer, the same as the last, had
/// the daily and weekly achievements downloaded again
class HiddenCategories extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() async {
    if (!communityReady) return const {};
    final timer = Timer.periodic(const Duration(minutes: 10), (_) async {
      final next = await _readHiddenCategories();
      final now = state.valueOrNull;
      if (now == null || now.length != next.length || !now.containsAll(next)) state = AsyncData(next);
    });
    ref.onDispose(timer.cancel);
    return _readHiddenCategories();
  }
}

final hiddenCategoriesProvider = AsyncNotifierProvider<HiddenCategories, Set<int>>(HiddenCategories.new);

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
  // a page left open across the reset reads the new picks
  ref.watch(periodRefreshProvider);
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

  AchievementRow row(int id) => achievementRowFor(id, details[id], progress[id]);

  final daily = <PeriodicCategory>[];
  final weekly = <PeriodicCategory>[];
  for (final entry in idsByCategory.entries) {
    final name = '${entry.key['name'] ?? ''}';
    final icon = entry.key['icon'] as String?;
    final d = [
      for (final id in entry.value)
        if (!_isWeekly(details[id])) row(id)
    ];
    final w = [
      for (final id in entry.value)
        if (_isWeekly(details[id])) row(id)
    ];
    if (d.isNotEmpty) daily.add(PeriodicCategory(name, icon, d, id: asInt(entry.key['id'])));
    if (w.isNotEmpty) weekly.add(PeriodicCategory(name, icon, w, id: asInt(entry.key['id'])));
  }
  final hidden = await ref.watch(hiddenCategoriesProvider.future);
  daily.removeWhere((c) => hidden.contains(c.id));
  weekly.removeWhere((c) => hidden.contains(c.id));
  daily.sort((a, b) => a.name.compareTo(b.name));
  weekly.sort((a, b) => a.name.compareTo(b.name));
  return PeriodicAchievements(daily, weekly);
});
