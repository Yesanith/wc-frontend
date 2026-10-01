import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/update_check.dart' show compareVersions;
import '../util.dart';
import 'community.dart';

/// whether the signed in player runs the backend, which decides whether the dashboard is offered. the
/// database answers for the player themselves, it says nothing of anybody else
final isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!communityConfigured) return false;
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return false;
  try {
    return await Supabase.instance.client.rpc('is_admin') == true;
  } catch (_) {
    return false;
  }
});

/// the numbers of the backend, from one function of the database that answers an administrator only
final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>((ref) async {
  final answer = await Supabase.instance.client.rpc('admin_dashboard');
  return AdminDashboard(Map<String, dynamic>.from(answer as Map));
});

/// what the database server says of itself, from a function that answers an administrator only
final adminServerProvider = FutureProvider.autoDispose<AdminServer>((ref) async {
  final answer = await Supabase.instance.client.rpc('admin_server');
  return AdminServer(Map<String, dynamic>.from(answer as Map));
});

/// the history of the backend: the daily numbers, the status of the functions, the counters, every guild and server
final adminHistoryProvider = FutureProvider.autoDispose<AdminHistory>((ref) async {
  final answer = await Supabase.instance.client.rpc('admin_history');
  return AdminHistory(Map<String, dynamic>.from(answer as Map));
});

/// the limits of the free plan this backend runs on, so the usage can be told as a share of them. the plan
/// is chosen on the Supabase dashboard, which shows the rest (traffic, storage, function calls)
const freeDatabaseBytes = 500 * 1024 * 1024;
const freeMonthlyUsers = 50000;

enum HealthLevel { good, warn, bad }

/// how full something is: a good way to go while it is under 70 percent, a warning to 90, an alarm from there
HealthLevel levelOfUse(double fraction) =>
    fraction >= 0.9 ? HealthLevel.bad : (fraction >= 0.7 ? HealthLevel.warn : HealthLevel.good);

/// 3 d 4 h, 5 h 20 min, 12 min
String uptime(DateTime since, DateTime now) {
  final d = now.difference(since);
  if (d.inDays > 0) return '${d.inDays} d ${d.inHours % 24} h';
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  return '${d.inMinutes} min';
}

/// one thing to keep an eye on, and whether it is all right
class HealthLine {
  const HealthLine(this.label, this.detail, this.level);

  final String label;
  final String detail;
  final HealthLevel level;
}

/// 3 minutes ago, 5 h ago, 2 d ago
String ago(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '$bytes B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}

List<({String day, int count})> _days(dynamic v) =>
    [for (final r in _maps(v)) (day: '${r['day']}', count: asInt(r['count']))];

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e)
      ]
    : const [];

/// what the database says of the backend: the counts, the queues, the scheduled jobs
class AdminDashboard {
  const AdminDashboard(this.raw);

  final Map<String, dynamic> raw;

  Map<String, dynamic> section(String name) {
    final v = raw[name];
    return v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
  }

  int count(String name, String key) => asInt(section(name)[key]);

  List<Map<String, dynamic>> rows(String name, String key) => _maps(section(name)[key]);

  List<Map<String, dynamic>> get cron => _maps(raw['cron']);

  DateTime? get generatedAt => DateTime.tryParse('${raw['generated_at'] ?? ''}')?.toLocal();

  /// the new players of each of the last thirty days, oldest first
  List<({String day, int count})> get signups =>
      [for (final r in _maps(raw['signups_by_day'])) (day: '${r['day']}', count: asInt(r['count']))];

  HealthLine _queue(String label, int waiting, int oldestMinutes) {
    if (waiting == 0) return HealthLine(label, 'Empty', HealthLevel.good);
    final detail = '$waiting waiting, the oldest for $oldestMinutes min';
    if (oldestMinutes <= 10) return HealthLine(label, detail, HealthLevel.good);
    return HealthLine(label, detail, oldestMinutes <= 60 ? HealthLevel.warn : HealthLevel.bad);
  }

  /// what is worth a look: queues that are not emptying, roles that are not followed, jobs that failed
  List<HealthLine> health(DateTime now) {
    final lines = <HealthLine>[
      _queue('Discord posts', count('discord', 'outbox_waiting'), count('discord', 'outbox_oldest_minutes')),
      _queue('Notifications', count('push', 'outbox_waiting'), count('push', 'outbox_oldest_minutes')),
    ];
    final servers = count('discord', 'servers');
    final stale = count('discord', 'roles_not_synced_1h');
    if (servers == 0) {
      lines.add(const HealthLine('Discord roles', 'No server is connected', HealthLevel.good));
    } else if (stale == 0) {
      lines.add(HealthLine('Discord roles', 'All $servers servers were looked at within the hour', HealthLevel.good));
    } else {
      lines.add(HealthLine('Discord roles', '$stale of $servers not looked at for over an hour', HealthLevel.warn));
    }
    for (final job in cron) {
      final name = '${job['name']}';
      final status = job['last_status'];
      final at = DateTime.tryParse('${job['last_run'] ?? ''}');
      if (job['active'] == false) {
        lines.add(HealthLine(name, 'Switched off', HealthLevel.warn));
      } else if (status == null || at == null) {
        lines.add(HealthLine(name, 'Has not run yet', HealthLevel.warn));
      } else if (status == 'failed') {
        final message = '${job['last_message'] ?? ''}'.trim();
        lines.add(HealthLine(name, 'Failed ${ago(at, now)}${message.isEmpty ? '' : ': $message'}', HealthLevel.bad));
      } else {
        lines.add(HealthLine(name, 'Ran ${ago(at, now)}', HealthLevel.good));
      }
    }
    return lines;
  }
}

/// what the database server says of itself: the connections, every table, what is slow, who signs in, what
/// happened each day. a part it could not read says why in place of its numbers
class AdminServer {
  const AdminServer(this.raw);

  final Map<String, dynamic> raw;

  Map<String, dynamic> section(String name) {
    final v = raw[name];
    return v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
  }

  int count(String name, String key) => asInt(section(name)[key]);

  /// why a part could not be read, null when it could
  String? problem(String name) {
    final v = raw[name];
    return v is Map && v['error'] != null ? '${v['error']}' : null;
  }

  List<Map<String, dynamic>> list(String name) => _maps(raw[name]);

  DateTime? at(String name, String key) => DateTime.tryParse('${section(name)[key] ?? ''}')?.toLocal();

  DateTime? get generatedAt => DateTime.tryParse('${raw['generated_at'] ?? ''}')?.toLocal();

  /// what happened each of the last thirty days: events, signups, reminders, reports, sign_ins
  List<({String day, int count})> series(String name) => _days(section('activity')[name]);

  double? get cacheHitPercent {
    final v = section('server')['cache_hit_percent'];
    return v is num ? v.toDouble() : null;
  }

  Map<String, dynamic> map(String name, String key) {
    final v = section(name)[key];
    return v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};
  }

  /// what is worth a look: a server that is full or slow, queries that hang, feeds that fail, parts that cannot be read
  List<HealthLine> health(DateTime now) {
    final lines = <HealthLine>[];

    final max = count('server', 'max_connections');
    final total = asInt(map('server', 'connections')['total']);
    if (max > 0) {
      lines.add(HealthLine('Connections', '$total of $max in use', levelOfUse(total / max)));
    }
    final waiting = asInt(map('server', 'connections')['idle_in_transaction']);
    if (waiting > 0) {
      lines.add(HealthLine('Open transactions', '$waiting idle in a transaction', HealthLevel.warn));
    }

    final hit = cacheHitPercent;
    if (hit != null) {
      lines.add(HealthLine('Cache', '${hit.toStringAsFixed(1)} percent of reads from memory',
          hit >= 99 ? HealthLevel.good : (hit >= 95 ? HealthLevel.warn : HealthLevel.bad)));
    }
    final deadlocks = count('server', 'deadlocks');
    lines.add(deadlocks == 0
        ? const HealthLine('Deadlocks', 'None since the statistics were reset', HealthLevel.good)
        : HealthLine('Deadlocks', '$deadlocks since the statistics were reset', HealthLevel.warn));

    final running = list('running');
    final longest = running.fold<int>(0, (a, r) => asInt(r['seconds']) > a ? asInt(r['seconds']) : a);
    lines.add(running.isEmpty
        ? const HealthLine('Queries', 'None has run for more than 5 s', HealthLevel.good)
        : HealthLine('Queries', '${running.length} running for more than 5 s, the longest $longest s',
            longest >= 60 ? HealthLevel.bad : HealthLevel.warn));

    final size = count('server', 'size_bytes');
    if (size > 0) {
      lines.add(HealthLine(
          'Database size',
          '${formatBytes(size)} of ${formatBytes(freeDatabaseBytes)} on the free plan',
          levelOfUse(size / freeDatabaseBytes)));
    }
    final monthly = count('auth', 'signed_in_30d');
    if (section('auth').containsKey('signed_in_30d')) {
      lines.add(HealthLine('Monthly users', '$monthly of ${fmtInt(freeMonthlyUsers)} on the free plan',
          levelOfUse(monthly / freeMonthlyUsers)));
    }

    // tables whose dead rows outnumber the living ones are waiting for a cleanup that is behind
    for (final t in list('tables')) {
      final dead = asInt(t['dead']);
      if (dead > 1000 && dead > asInt(t['rows'])) {
        lines.add(HealthLine('${t['name']}', '${fmtInt(dead)} dead rows, more than the rows it has', HealthLevel.warn));
      }
    }

    final failing = count('feeds', 'with_error');
    if (failing > 0) {
      final first = _maps(section('feeds')['errors']).firstOrNull;
      final which = first == null ? '' : ': ${first['guild']} ${first['kind']}, ${first['error']}';
      lines.add(HealthLine('News feeds', '$failing failing$which', HealthLevel.warn));
    }

    for (final name in const [
      'server',
      'tables',
      'running',
      'slow',
      'auth',
      'activity',
      'latest',
      'feeds',
      'queues',
      'cron_history'
    ]) {
      final why = problem(name);
      if (why != null) lines.add(HealthLine('Could not read $name', why, HealthLevel.warn));
    }
    return lines;
  }
}

/// how many days until the database reaches [limit] if it keeps growing as it has since the first day given. null
/// when there is too little to go on (under a week) or it is not growing
int? projectDaysToLimit(List<({DateTime day, int bytes})> points, int limit) {
  if (points.length < 2) return null;
  final first = points.first;
  final last = points.last;
  final span = last.day.difference(first.day).inDays;
  if (span < 7) return null;
  final perDay = (last.bytes - first.bytes) / span;
  if (perDay <= 0) return null;
  final left = limit - last.bytes;
  if (left <= 0) return 0;
  return (left / perDay).ceil();
}

/// the last [n] of a list
List<T> tail<T>(List<T> list, int n) => list.length <= n ? list : list.sublist(list.length - n);

/// how the backend has done: the numbers of each day, what each function did, what was counted, every guild and
/// every Discord server
class AdminHistory {
  const AdminHistory(this.raw);

  final Map<String, dynamic> raw;

  List<Map<String, dynamic>> list(String name) => _maps(raw[name]);

  /// why a part could not be read, null when it could
  String? problem(String name) {
    final v = raw[name];
    return v is Map && v['error'] != null ? '${v['error']}' : null;
  }

  DateTime? get generatedAt => DateTime.tryParse('${raw['generated_at'] ?? ''}')?.toLocal();

  /// the counters of each of the last thirty days: commands, buttons, bot_errors, links_ok, links_failed, runs_failed
  List<({String day, int count})> series(String name) {
    final v = raw['series'];
    return v is Map ? _days(v[name]) : const [];
  }

  /// a number of the daily snapshots, by day, oldest first
  List<({String day, int count})> snapshotSeries(String field) =>
      [for (final s in list('snapshots')) (day: '${s['day']}', count: asInt(s[field]))];

  /// the size of the database in megabytes, by day
  List<({String day, int count})> get databaseMegabytes =>
      [for (final s in list('snapshots')) (day: '${s['day']}', count: (asInt(s['db_bytes']) / 1048576).round())];

  int? get daysToDatabaseLimit => projectDaysToLimit([
        for (final s in list('snapshots'))
          if (DateTime.tryParse('${s['day']}') != null)
            (day: DateTime.parse('${s['day']}'), bytes: asInt(s['db_bytes'])),
      ], freeDatabaseBytes);

  /// the most counted of a function whose key begins with [prefix], with the prefix taken off
  List<({String key, int total})> top(String name, String prefix, {int limit = 8}) {
    final rows = [
      for (final k in list('metric_keys'))
        if (k['name'] == name && '${k['key']}'.startsWith(prefix))
          (key: '${k['key']}'.substring(prefix.length), total: asInt(k['total'])),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return rows.take(limit).toList();
  }

  /// how often each version of the app was opened this week and this month, the newest first
  List<({String platform, String version, int week, int month})> get appVersions {
    final rows = [
      for (final v in list('app_versions'))
        (platform: '${v['platform']}', version: '${v['version']}', week: asInt(v['opens_7d']), month: asInt(v['opens_30d'])),
    ]..sort((a, b) {
        final byVersion = compareVersions(b.version, a.version);
        return byVersion != 0 ? byVersion : b.week.compareTo(a.week);
      });
    return rows;
  }

  /// the share of this week's opens that were of the newest version there is a number for, 0 to 1. null when
  /// there were none
  double? get newestVersionShare {
    final rows = appVersions.where((v) => v.version != 'other').toList();
    final total = appVersions.fold<int>(0, (a, v) => a + v.week);
    if (rows.isEmpty || total == 0) return null;
    final newest = rows.first.version;
    return rows.where((v) => v.version == newest).fold<int>(0, (a, v) => a + v.week) / total;
  }

  int _sum(List<({String day, int count})> days) => days.fold<int>(0, (a, d) => a + d.count);

  /// each function that has run, whether its last run worked and how long it took
  List<HealthLine> functionLines(DateTime now) {
    final lines = <HealthLine>[];
    for (final f in list('functions')) {
      final name = '${f['name']}';
      final ranAt = DateTime.tryParse('${f['last_run_at'] ?? ''}');
      final okAt = DateTime.tryParse('${f['last_ok_at'] ?? ''}');
      final errorAt = DateTime.tryParse('${f['last_error_at'] ?? ''}');
      final runs = asInt(f['runs']);
      final failures = asInt(f['failures']);
      final ms = asInt(f['last_duration_ms']);
      final summary =
          '$runs runs, $failures failed${ms > 0 ? ', last one took ${(ms / 1000).toStringAsFixed(1)} s' : ''}';
      if (errorAt != null && (okAt == null || errorAt.isAfter(okAt))) {
        final why = '${f['last_error'] ?? ''}'.trim();
        lines.add(HealthLine(
            name, 'The last run failed ${ago(errorAt, now)}${why.isEmpty ? '' : ': $why'}. $summary', HealthLevel.bad));
      } else if (ms >= 20000) {
        lines.add(HealthLine(
            name, 'Slow: the last run took ${(ms / 1000).toStringAsFixed(1)} s. $summary', HealthLevel.warn));
      } else {
        lines.add(
            HealthLine(name, '${ranAt == null ? 'No run yet' : 'Ran ${ago(ranAt, now)}'}. $summary', HealthLevel.good));
      }
    }
    return lines;
  }

  /// what else is worth a look: a server that went wrong, linking that fails, the bot's calls that broke
  List<HealthLine> health(DateTime now) {
    final lines = <HealthLine>[];

    final recent = [
      for (final s in list('servers'))
        if (s['last_error'] != null &&
            (DateTime.tryParse('${s['last_error_at'] ?? ''}')?.isAfter(now.subtract(const Duration(days: 1))) ?? false))
          s,
    ];
    if (recent.isEmpty) {
      lines.add(const HealthLine('Discord servers', 'None had an error in the last day', HealthLevel.good));
    } else {
      for (final s in recent) {
        lines.add(HealthLine('${s['guild']}', '${s['last_error']} ${ago(DateTime.parse('${s['last_error_at']}'), now)}',
            HealthLevel.warn));
      }
    }

    final linksOk = _sum(tail(series('links_ok'), 7));
    final linksFailed = _sum(tail(series('links_failed'), 7));
    final attempts = linksOk + linksFailed;
    if (attempts >= 10) {
      final share = linksFailed / attempts;
      lines.add(HealthLine('Linking game accounts', '$linksFailed of $attempts failed in the last 7 days',
          share > 0.5 ? HealthLevel.bad : (share > 0.25 ? HealthLevel.warn : HealthLevel.good)));
    } else {
      lines.add(HealthLine(
          'Linking game accounts',
          attempts == 0 ? 'None in the last 7 days' : '$linksFailed of $attempts failed in the last 7 days',
          HealthLevel.good));
    }

    final newsOk = _sum(tail(series('news_ok'), 7));
    final newsFailed = _sum(tail(series('news_failed'), 7));
    final newsAttempts = newsOk + newsFailed;
    if (newsAttempts >= 10) {
      final share = newsFailed / newsAttempts;
      lines.add(HealthLine('News feed', '$newsFailed of $newsAttempts requests failed in the last 7 days',
          share > 0.5 ? HealthLevel.bad : (share > 0.25 ? HealthLevel.warn : HealthLevel.good)));
    } else {
      lines.add(HealthLine('News feed', newsAttempts == 0 ? 'No request in the last 7 days' : '$newsFailed of $newsAttempts requests failed in the last 7 days',
          HealthLevel.good));
    }

    final today = series('bot_errors').isEmpty ? 0 : series('bot_errors').last.count;
    lines.add(today == 0
        ? const HealthLine('Bot calls', 'No database error today', HealthLevel.good)
        : HealthLine('Bot calls', '$today database errors today that were not a refusal', HealthLevel.warn));

    final broken = [
      for (final f in list('functions'))
        if (asInt(f['failures']) > 0 && f['last_error'] == null) f
    ];
    if (broken.isNotEmpty)
      lines.add(HealthLine('Functions', '${broken.length} failed without saying why', HealthLevel.warn));

    for (final name in const ['snapshots', 'functions', 'metric_keys', 'series', 'guilds', 'servers', 'app_versions']) {
      final why = problem(name);
      if (why != null) lines.add(HealthLine('Could not read $name', why, HealthLevel.warn));
    }
    return lines;
  }
}
