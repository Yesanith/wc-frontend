import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util.dart';
import 'admin.dart';

/// everything the backend keeps, from one function of the database that answers an administrator only: what each sync function answered, the
/// trading post, the official server in detail, the public events in numbers, and every table
final adminSystemProvider = FutureProvider.autoDispose<AdminSystem>((ref) async {
  final answer = await Supabase.instance.client.rpc('admin_system');
  return AdminSystem(Map<String, dynamic>.from(answer as Map));
});

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : const [];

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

DateTime? _time(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

List<({String day, int count})> _byDay(dynamic v, String key) =>
    [for (final r in _maps(v)) (day: '${r['day']}', count: asInt(r[key]))];

List<({String label, int count})> _byLabel(dynamic v, String labelKey) =>
    [for (final r in _maps(v)) (label: '${r[labelKey]}', count: asInt(r['n']))];

/// a table of the database: how many rows it has, how big it is with its indexes, and when something was last put in it
class SystemTable {
  const SystemTable(this.name, this.rows, this.bytes, this.newest);

  final String name;
  final int rows;
  final int bytes;
  final DateTime? newest;
}

class AdminSystem {
  const AdminSystem(this.raw);

  final Map<String, dynamic> raw;

  DateTime? get generatedAt => _time(raw['generated_at']);

  // ---------------------------------------------------------------- the sync functions

  /// what each function answered in the last hour: fn, calls, ok, unauthorized, failed, timed_out, no_answer, last_status, last_answer
  List<Map<String, dynamic>> get sync => _maps(raw['sync']);

  /// the functions the database wakes, and what they answered. one that is refused by every call is the thing to see first: the secret of
  /// the function and of the database do not match, and nothing is synced
  List<HealthLine> syncLines(DateTime now) {
    final lines = <HealthLine>[];
    for (final f in sync) {
      final fn = '${f['fn']}';
      final calls = asInt(f['calls']);
      final ok = asInt(f['ok']);
      final refused = asInt(f['unauthorized']);
      final failed = asInt(f['failed']);
      final timedOut = asInt(f['timed_out']);
      final none = asInt(f['no_answer']);
      final lastAt = _time(f['last_call_at']);
      final called = lastAt == null ? '' : ', called ${ago(lastAt, now)}';
      if (refused > 0 && ok == 0) {
        lines.add(HealthLine(
          fn,
          'Refused $refused of $calls calls (401): the secret of the function and of the database do not match. Run the Deploy workflow',
          HealthLevel.bad,
        ));
      } else if (refused > 0) {
        lines.add(HealthLine(fn, '$refused of $calls calls refused (401), $ok ok$called', HealthLevel.warn));
      } else if (failed > 0 || timedOut > 0) {
        final parts = [if (failed > 0) '$failed failed', if (timedOut > 0) '$timedOut timed out', '$ok ok'];
        lines.add(HealthLine(fn, '${parts.join(', ')} of $calls$called', HealthLevel.warn));
      } else if (ok == 0) {
        lines.add(HealthLine(fn, 'No answer yet to $calls ${calls == 1 ? 'call' : 'calls'}$called', HealthLevel.warn));
      } else {
        final status = f['last_status'] == null ? '' : ', last answer ${f['last_status']}';
        lines.add(HealthLine(fn, '$ok of $calls ok$status$called${none > 0 ? ', $none waiting' : ''}', HealthLevel.good));
      }
    }
    // the trading post is read every ten minutes whatever else happens, so a quiet hour is a function that is not woken
    if (!sync.any((f) => f['fn'] == 'tp-sync')) {
      lines.add(const HealthLine('tp-sync', 'Not called in the last hour. It is woken every ten minutes', HealthLevel.warn));
    }
    return lines;
  }

  int get syncCallsKept => asInt(raw['sync_calls_total']);

  // ---------------------------------------------------------------- the trading post

  Map<String, dynamic> get trading => _map(raw['trading_post']);

  DateTime? get listReadAt => _time(trading['snapshot_at']);

  List<({String day, int count})> get historyByDay => _byDay(trading['history_by_day'], 'points');

  /// the item ids asked for last, with when
  List<({int itemId, DateTime? at})> get recentlyAsked =>
      [for (final r in _maps(trading['recently_asked'])) (itemId: asInt(r['item_id']), at: _time(r['asked_at']))];

  /// the list of the trading post is read every ten minutes: a list that is not that old is the price now
  List<HealthLine> tradingLines(DateTime now) {
    final t = trading;
    final at = listReadAt;
    final items = asInt(t['snapshot_items']);
    final HealthLine list;
    if (at == null) {
      list = const HealthLine('List of prices', 'Not read yet', HealthLevel.warn);
    } else {
      final age = now.difference(at);
      final level = age.inMinutes < 25 ? HealthLevel.good : (age.inMinutes < 60 ? HealthLevel.warn : HealthLevel.bad);
      list = HealthLine('List of prices', '$items items, read ${ago(at, now)}, ${formatBytes(asInt(t['snapshot_bytes']))}', level);
    }
    final oldest = t['history_oldest'];
    final newest = t['history_newest'];
    return [
      list,
      HealthLine('Latest prices', '${fmtInt(asInt(t['latest_items']))} items kept', HealthLevel.good),
      HealthLine(
        'Kept with a history',
        '${fmtInt(asInt(t['tracked']))} items, ${asInt(t['tracked_unread'])} not read yet, ${asInt(t['asked_24h'])} asked for in the last day',
        HealthLevel.good,
      ),
      HealthLine(
        'History',
        oldest == null ? 'No points yet' : '${fmtInt(asInt(t['history_points']))} points, from $oldest to $newest',
        HealthLevel.good,
      ),
    ];
  }

  // ---------------------------------------------------------------- the official server

  Map<String, dynamic> get official => _map(raw['official']);

  bool get officialConfigured => official['configured'] == true;

  List<Map<String, dynamic>> get outbox => _maps(official['outbox']);

  /// the events that are going on: title, region, text, voice, granted, voice_tried_at, claimed_at
  List<Map<String, dynamic>> get active => _maps(official['active']);

  List<String> kinds(String region) => [for (final k in (official['kinds_$region'] as List? ?? const [])) '$k'];

  /// the eight kinds of event the server has a channel for in each region
  static const kindsWanted = 8;

  List<HealthLine> officialLines(DateTime now) {
    final o = official;
    if (!officialConfigured) {
      return const [HealthLine('Server', 'Not set up. Run /official setup in the server', HealthLevel.warn)];
    }
    final categories = _map(o['categories']);
    final roles = _map(o['roles']);
    final sync = _map(o['role_sync']);
    final drafts = _map(o['drafts']);
    final error = o['last_error'];
    final errorAt = _time(o['last_error_at']);
    final failing = outbox.where((p) => asInt(p['attempts']) > 0).length;
    final noVoice = active.where((a) => a['voice'] != true).length;
    final lock = _time(o['locked_until']);
    return [
      HealthLine(
        'Server',
        'Server …${o['guild_tail']}, roles …${roles['eu']} and …${roles['na']}, invite ${o['invite_set'] == true ? 'set' : 'missing'}',
        o['invite_set'] == true ? HealthLevel.good : HealthLevel.warn,
      ),
      HealthLine(
        'Categories',
        'Europe ${categories['eu'] == true ? 'yes' : 'no'}, North America ${categories['na'] == true ? 'yes' : 'no'}, events going on ${categories['active'] == true ? 'yes' : 'no'}',
        categories['eu'] == true && categories['na'] == true && categories['active'] == true ? HealthLevel.good : HealthLevel.warn,
      ),
      HealthLine(
        'Channels of the kinds',
        'Europe ${kinds('eu').length} of $kindsWanted, North America ${kinds('na').length} of $kindsWanted',
        kinds('eu').length >= kindsWanted && kinds('na').length >= kindsWanted ? HealthLevel.good : HealthLevel.warn,
      ),
      error == null
          ? const HealthLine('Last problem', 'None recorded', HealthLevel.good)
          : HealthLine('Last problem', '$error${errorAt == null ? '' : ' (${ago(errorAt, now)})'}', HealthLevel.bad),
      HealthLine(
        'Posts waiting',
        '${outbox.length} waiting${failing > 0 ? ', $failing failing' : ''}, ${asInt(o['messages'])} messages kept',
        failing > 0 ? HealthLevel.warn : HealthLevel.good,
      ),
      HealthLine(
        'Events going on',
        '${active.length} with channels, $noVoice without a voice channel',
        noVoice > 0 ? HealthLevel.warn : HealthLevel.good,
      ),
      HealthLine(
        'Roles',
        '${asInt(sync['tracked'])} players tracked, ${asInt(sync['due'])} due, ${asInt(sync['dirty'])} changed, ${asInt(sync['never'])} never looked at, ${asInt(sync['cleanup'])} to take out',
        asInt(sync['due']) > 50 ? HealthLevel.warn : HealthLevel.good,
      ),
      HealthLine(
        'Forms of /event public',
        '${asInt(drafts['open'])} open, ${asInt(drafts['expired'])} expired, ${asInt(o['timezones'])} time zones remembered',
        HealthLevel.good,
      ),
      if (lock != null && lock.isAfter(now))
        HealthLine('Sync', 'The setup is being made, until ${lock.hour.toString().padLeft(2, '0')}:${lock.minute.toString().padLeft(2, '0')}', HealthLevel.good),
    ];
  }

  // ---------------------------------------------------------------- the public events

  Map<String, dynamic> get publicEvents => _map(raw['public_events']);

  List<({String label, int count})> get byStatus => _byLabel(publicEvents['by_status'], 'status');

  List<({String label, int count})> get upcomingByRegion => _byLabel(publicEvents['upcoming_by_region'], 'region');

  List<({String label, int count})> get byActivity => _byLabel(publicEvents['by_activity_30d'], 'activity');

  List<({String label, int count})> get byRole => _byLabel(publicEvents['by_role'], 'role');

  List<({String label, int count})> get byProfession => _byLabel(publicEvents['by_profession'], 'profession');

  List<({String day, int count})> get createdByDay => _byDay(publicEvents['created_by_day'], 'n');

  List<({String day, int count})> get signupsByDay => _byDay(publicEvents['signups_by_day'], 'n');

  List<HealthLine> publicLines() {
    final p = publicEvents;
    final total = asInt(p['total']);
    final withRoles = asInt(p['with_roles']);
    final waiting = asInt(p['reports_waiting']);
    return [
      HealthLine('Events', '$total made, $withRoles with roles', HealthLevel.good),
      HealthLine('Signed up', '${asInt(p['going'])} going, ${asInt(p['maybe'])} maybe', HealthLevel.good),
      HealthLine('Organizers', '${asInt(p['organizers'])} players, ${asInt(p['banned'])} kept from making events', HealthLevel.good),
      waiting > 0
          ? HealthLine('Reports', '$waiting events wait for a look', HealthLevel.warn)
          : const HealthLine('Reports', 'None wait', HealthLevel.good),
    ];
  }

  // ---------------------------------------------------------------- every table

  List<SystemTable> get tables => [
        for (final t in _maps(raw['tables'])) SystemTable('${t['name']}', asInt(t['rows']), asInt(t['bytes']), _time(t['newest'])),
      ];

  int get totalRows => tables.fold(0, (sum, t) => sum + t.rows);

  int get totalBytes => tables.fold(0, (sum, t) => sum + t.bytes);
}

// -------------------------------------------------------------------- the scheduled jobs

/// how often a schedule runs, for the shapes this backend uses: 'N seconds', '*/N * * * *', 'M * * * *' and 'M H * * *'. null for others
Duration? cronPeriod(String schedule) {
  final s = schedule.trim();
  final seconds = RegExp(r'^(\d+) seconds?$').firstMatch(s);
  if (seconds != null) {
    final n = int.parse(seconds.group(1)!);
    return n > 0 ? Duration(seconds: n) : null;
  }
  final parts = s.split(RegExp(r'\s+'));
  if (parts.length != 5 || parts.sublist(2).any((p) => p != '*')) return null;
  final step = RegExp(r'^\*/(\d+)$').firstMatch(parts[0]);
  if (step != null && parts[1] == '*') {
    final n = int.parse(step.group(1)!);
    return n > 0 && n < 60 ? Duration(minutes: n) : null;
  }
  final minute = int.tryParse(parts[0]);
  if (minute == null || minute > 59) return null;
  if (parts[1] == '*') return const Duration(hours: 1);
  final hour = int.tryParse(parts[1]);
  return hour == null || hour > 23 ? null : const Duration(days: 1);
}

/// when a schedule runs next after [now] (UTC, as the database runs them), for the shapes that run at a time of the clock. null for one that
/// runs every so many seconds, which is always about to, and for the shapes this does not know
DateTime? nextCronRun(String schedule, DateTime now) {
  final u = now.toUtc();
  final parts = schedule.trim().split(RegExp(r'\s+'));
  if (parts.length != 5 || parts.sublist(2).any((p) => p != '*')) return null;
  final hourStart = DateTime.utc(u.year, u.month, u.day, u.hour);
  final step = RegExp(r'^\*/(\d+)$').firstMatch(parts[0]);
  if (step != null && parts[1] == '*') {
    final n = int.parse(step.group(1)!);
    if (n <= 0 || n >= 60) return null;
    // the minutes of the hour it runs at begin with 0 and go up in steps, so the next after the last of them is the first of the next hour
    final next = [for (var m = 0; m < 60; m += n) m].firstWhere((m) => m > u.minute, orElse: () => 60);
    return hourStart.add(Duration(minutes: next));
  }
  final minute = int.tryParse(parts[0]);
  if (minute == null || minute > 59) return null;
  if (parts[1] == '*') {
    final at = hourStart.add(Duration(minutes: minute));
    return at.isAfter(u) ? at : at.add(const Duration(hours: 1));
  }
  final hour = int.tryParse(parts[1]);
  if (hour == null || hour > 23) return null;
  final at = DateTime.utc(u.year, u.month, u.day, hour, minute);
  return at.isAfter(u) ? at : at.add(const Duration(days: 1));
}

/// every 20 s, every 10 min, hourly at :05, daily at 03:50 UTC. the schedule as written for one that is none of these
String cronEvery(String schedule) {
  final s = schedule.trim();
  final period = cronPeriod(s);
  if (period == null) return s;
  if (period.inDays >= 1) {
    final parts = s.split(RegExp(r'\s+'));
    return 'daily at ${parts[1].padLeft(2, '0')}:${parts[0].padLeft(2, '0')} UTC';
  }
  if (period.inHours >= 1) return 'hourly at :${s.split(RegExp(r'\s+'))[0].padLeft(2, '0')}';
  if (period.inMinutes >= 1) return 'every ${period.inMinutes} min';
  return 'every ${period.inSeconds} s';
}

/// in 6 min, in 3 h 10 min, in 2 d
String untilLabel(Duration d) {
  if (d.inSeconds < 60) return 'in under a minute';
  if (d.inMinutes < 60) return 'in ${d.inMinutes} min';
  if (d.inHours < 24) return 'in ${d.inHours} h ${d.inMinutes % 60} min';
  return 'in ${d.inDays} d';
}

/// whether a job has not run for much longer than its schedule says it should: more than twice, and two minutes more
bool cronOverdue(String schedule, DateTime lastRun, DateTime now) {
  final period = cronPeriod(schedule);
  if (period == null) return false;
  return now.difference(lastRun) > period * 2 + const Duration(minutes: 2);
}

/// the scheduled jobs of the database, each with its schedule, when it ran last, and when it runs next
List<HealthLine> cronLines(List<Map<String, dynamic>> jobs, DateTime now) {
  final lines = <HealthLine>[];
  for (final job in jobs) {
    final name = '${job['name']}';
    final schedule = '${job['schedule'] ?? ''}';
    final every = cronEvery(schedule);
    final status = job['last_status'];
    final at = DateTime.tryParse('${job['last_run'] ?? ''}')?.toLocal();
    final next = nextCronRun(schedule, now);
    final nextText = next == null ? '' : ', next ${untilLabel(next.difference(now))}';
    if (job['active'] == false) {
      lines.add(HealthLine(name, '$every, switched off', HealthLevel.warn));
    } else if (status == null || at == null) {
      lines.add(HealthLine(name, '$every, has not run yet$nextText', HealthLevel.warn));
    } else if (status == 'failed') {
      final message = '${job['last_message'] ?? ''}'.trim();
      lines.add(HealthLine(name, '$every, failed ${ago(at, now)}${message.isEmpty ? '' : ': $message'}', HealthLevel.bad));
    } else if (cronOverdue(schedule, at, now)) {
      lines.add(HealthLine(name, '$every, overdue: ran ${ago(at, now)}$nextText', HealthLevel.bad));
    } else {
      lines.add(HealthLine(name, '$every, ran ${ago(at, now)}$nextText', HealthLevel.good));
    }
  }
  return lines;
}
