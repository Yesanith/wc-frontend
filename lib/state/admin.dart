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

enum HealthLevel { good, warn, bad }

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
