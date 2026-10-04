part of '../admin.dart';

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
      final which =
          first == null ? '' : ': ${first['guild']} ${first['kind']}, ${feedProblemText('${first['error']}')}';
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

/// in 25 min, in 3 h, in 2 d for what is to come, 3 min ago for what is over
String whenText(DateTime at, DateTime now) {
  final d = at.difference(now);
  if (!d.isNegative && d.inMinutes >= 1) {
    if (d.inMinutes < 60) return 'in ${d.inMinutes} min';
    if (d.inHours < 24) return 'in ${d.inHours} h';
    return 'in ${d.inDays} d';
  }
  return ago(at, now);
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
        (
          platform: '${v['platform']}',
          version: '${v['version']}',
          week: asInt(v['opens_7d']),
          month: asInt(v['opens_30d'])
        ),
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
      lines.add(HealthLine(
          'News feed',
          newsAttempts == 0
              ? 'No request in the last 7 days'
              : '$newsFailed of $newsAttempts requests failed in the last 7 days',
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
    if (broken.isNotEmpty) {
      lines.add(HealthLine('Functions', '${broken.length} failed without saying why', HealthLevel.warn));
    }

    for (final name in const ['snapshots', 'functions', 'metric_keys', 'series', 'guilds', 'servers', 'app_versions']) {
      final why = problem(name);
      if (why != null) lines.add(HealthLine('Could not read $name', why, HealthLevel.warn));
    }
    return lines;
  }
}

/// the public events as an administrator sees them: the numbers, the events that were reported and wait for a look,
/// the hidden ones, the latest ones
class AdminOpenEvents {
  const AdminOpenEvents(this.raw);

  final Map<String, dynamic> raw;

  Map<String, dynamic> get summary =>
      raw['summary'] is Map ? Map<String, dynamic>.from(raw['summary'] as Map) : const <String, dynamic>{};

  int count(String key) => asInt(summary[key]);

  List<Map<String, dynamic>> get reports => _maps(raw['reports']);
  List<Map<String, dynamic>> get hidden => _maps(raw['hidden']);
  List<Map<String, dynamic>> get recent => _maps(raw['recent']);

  /// the events that were reported and nobody has looked at
  int get waiting => count('reports_waiting');

  DateTime? get generatedAt => DateTime.tryParse('${raw['generated_at'] ?? ''}')?.toLocal();

  List<HealthLine> health() => [
        waiting == 0
            ? const HealthLine('Reports', 'Nothing waits for a look', HealthLevel.good)
            : HealthLine(
                'Reports',
                waiting == 1
                    ? '1 event was reported and waits for a look'
                    : '$waiting events were reported and wait for a look',
                waiting >= 5 ? HealthLevel.bad : HealthLevel.warn),
        HealthLine('Hidden', '${count('hidden')} hidden, ${count('banned')} organizers kept from making more',
            HealthLevel.good),
      ];
}

/// how the official Discord server is doing, as the database tells an administrator
class AdminOfficial {
  const AdminOfficial(this.raw);

  final Map<String, dynamic> raw;

  Map<String, dynamic> _part(String key) =>
      raw[key] is Map ? Map<String, dynamic>.from(raw[key] as Map) : const <String, dynamic>{};

  bool get configured => raw['configured'] == true;

  /// an administrator asked for the setup and the sync has not made it yet
  bool get setupRequested => raw['setup_requested'] == true;

  int count(String key) => asInt(raw[key]);

  String? get lastError => raw['last_error'] == null ? null : '${raw['last_error']}';

  /// who is kept from making public events: user_id, name, banned_at
  List<Map<String, dynamic>> get bans => _maps(raw['bans']);

  DateTime? get generatedAt => DateTime.tryParse('${raw['generated_at'] ?? ''}')?.toLocal();

  /// a role for each region, a channel for each of the eight kinds in each region, and the category of the events going on
  bool get complete {
    final channels = _part('channels');
    final roles = _part('roles');
    return channels['eu'] == true &&
        channels['na'] == true &&
        roles['eu'] == true &&
        roles['na'] == true &&
        asInt(roles['kinds']) >= 8 &&
        raw['active_category'] == true;
  }

  List<HealthLine> health() => [
        if (!configured)
          const HealthLine('Server', 'Not set up. Run /official setup in the server', HealthLevel.warn)
        else if (setupRequested)
          const HealthLine('Server', 'Being set up, the roles and channels are made in a minute', HealthLevel.warn)
        else if (!complete)
          const HealthLine('Server', 'Set up, but not completely. Run /official setup again', HealthLevel.warn)
        else
          const HealthLine('Server', 'Set up', HealthLevel.good),
        lastError == null
            ? const HealthLine('Last problem', 'None recorded', HealthLevel.good)
            : HealthLine('Last problem', lastError!, HealthLevel.bad),
        count('posts_failing') > 0
            ? HealthLine(
                'Posts', '${count('posts_waiting')} waiting, ${count('posts_failing')} failing', HealthLevel.warn)
            : HealthLine('Posts', '${count('posts_waiting')} waiting, ${count('posted_events')} events posted',
                HealthLevel.good),
        HealthLine('Events going on', '${count('active_events')} with channels open', HealthLevel.good),
        HealthLine(
          'Roles',
          '${count('roles_waiting')} of ${count('players_tracked')} players wait to be looked at',
          count('roles_waiting') > 50 ? HealthLevel.warn : HealthLevel.good,
        ),
      ];
}
