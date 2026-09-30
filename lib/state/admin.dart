import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      lines.add(HealthLine('Database size', '${formatBytes(size)} of ${formatBytes(freeDatabaseBytes)} on the free plan',
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

    for (final name in const ['server', 'tables', 'running', 'slow', 'auth', 'activity', 'latest', 'feeds', 'queues', 'cron_history']) {
      final why = problem(name);
      if (why != null) lines.add(HealthLine('Could not read $name', why, HealthLevel.warn));
    }
    return lines;
  }
}
