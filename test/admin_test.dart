import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/services/update_check.dart' show compareVersions;
import 'package:tyria_codex/state/admin.dart';

AdminDashboard dash({
  int discordWaiting = 0,
  int discordOldest = 0,
  int pushWaiting = 0,
  int pushOldest = 0,
  int servers = 2,
  int stale = 0,
  List<Map<String, dynamic>> cron = const [],
}) =>
    AdminDashboard({
      'generated_at': '2026-10-01T12:00:00+00:00',
      'users': {'total': 120, 'new_7d': 9, 'active_24h': 31},
      'signups_by_day': [
        for (var i = 0; i < 30; i++) {'day': '2026-09-${(i + 1).toString().padLeft(2, '0')}', 'count': i % 4},
      ],
      'discord': {
        'outbox_waiting': discordWaiting,
        'outbox_oldest_minutes': discordOldest,
        'servers': servers,
        'roles_not_synced_1h': stale,
        'servers_list': [
          {'name': 'Mistwalkers', 'tag': 'MIST', 'follow_ranks': true},
        ],
      },
      'push': {'outbox_waiting': pushWaiting, 'outbox_oldest_minutes': pushOldest},
      'cron': cron,
    });

void main() {
  serverTests();
  historyTests();
  versionTests();
  final now = DateTime.utc(2026, 10, 1, 12);

  group('what the database says', () {
    test('is read as counts, lists and days', () {
      final d = dash();
      expect(d.count('users', 'total'), 120);
      expect(d.count('users', 'active_24h'), 31);
      expect(d.count('nowhere', 'nothing'), 0, reason: 'a missing number is nought, not an error');
      expect(d.rows('discord', 'servers_list').single['tag'], 'MIST');
      expect(d.signups.length, 30);
      expect(d.signups.first.day, '2026-09-01');
      expect(d.signups.fold<int>(0, (a, b) => a + b.count), 43, reason: 'i % 4 over thirty days');
      expect(d.generatedAt, isNotNull);
    });

    test('survives an answer with parts missing or of another kind', () {
      const d = AdminDashboard({'users': 'nothing', 'cron': 5, 'signups_by_day': null});
      expect(d.count('users', 'total'), 0);
      expect(d.cron, isEmpty);
      expect(d.signups, isEmpty);
      expect(d.rows('discord', 'servers_list'), isEmpty);
      expect(d.generatedAt, isNull);
    });
  });

  group('health', () {
    HealthLine line(AdminDashboard d, String label) => d.health(now).firstWhere((l) => l.label == label);

    test('a queue that is empty is fine', () {
      expect(line(dash(), 'Discord posts').level, HealthLevel.good);
      expect(line(dash(), 'Discord posts').detail, 'Empty');
    });

    test('a queue that is emptying is fine, one that is not gets a warning and then an alarm', () {
      expect(line(dash(discordWaiting: 3, discordOldest: 4), 'Discord posts').level, HealthLevel.good);
      expect(line(dash(discordWaiting: 3, discordOldest: 30), 'Discord posts').level, HealthLevel.warn);
      final bad = line(dash(discordWaiting: 3, discordOldest: 120), 'Discord posts');
      expect(bad.level, HealthLevel.bad);
      expect(bad.detail, '3 waiting, the oldest for 120 min');
      expect(line(dash(pushWaiting: 1, pushOldest: 90), 'Notifications').level, HealthLevel.bad);
    });

    test('roles that are not looked at are a warning, but not when there is no server', () {
      expect(line(dash(stale: 0), 'Discord roles').level, HealthLevel.good);
      expect(line(dash(stale: 1), 'Discord roles').level, HealthLevel.warn);
      expect(line(dash(stale: 1), 'Discord roles').detail, '1 of 2 not looked at for over an hour');
      expect(line(dash(servers: 0, stale: 0), 'Discord roles').detail, 'No server is connected');
    });

    test('a scheduled job is fine when it ran, an alarm when it failed, a warning when it never ran or is off', () {
      final d = dash(cron: [
        {'name': 'nightly', 'active': true, 'last_status': 'succeeded', 'last_run': '2026-10-01T09:00:00+00:00'},
        {
          'name': 'broken',
          'active': true,
          'last_status': 'failed',
          'last_run': '2026-10-01T11:30:00+00:00',
          'last_message': 'boom'
        },
        {'name': 'new', 'active': true, 'last_status': null, 'last_run': null},
        {'name': 'paused', 'active': false, 'last_status': 'succeeded', 'last_run': '2026-09-01T09:00:00+00:00'},
      ]);
      expect(line(d, 'nightly').level, HealthLevel.good);
      expect(line(d, 'nightly').detail, 'Ran 3 h ago');
      expect(line(d, 'broken').level, HealthLevel.bad);
      expect(line(d, 'broken').detail, 'Failed 30 min ago: boom');
      expect(line(d, 'new').level, HealthLevel.warn);
      expect(line(d, 'paused').level, HealthLevel.warn);
      expect(line(d, 'paused').detail, 'Switched off');
    });
  });

  group('how it is written', () {
    test('how long ago', () {
      expect(ago(now.subtract(const Duration(seconds: 20)), now), 'just now');
      expect(ago(now.subtract(const Duration(minutes: 5)), now), '5 min ago');
      expect(ago(now.subtract(const Duration(hours: 7)), now), '7 h ago');
      expect(ago(now.subtract(const Duration(days: 3, hours: 2)), now), '3 d ago');
    });

    test('bytes', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2.0 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes((2.5 * 1024 * 1024 * 1024).round()), '2.5 GB');
    });
  });
}

AdminServer server({
  int connections = 20,
  int max = 60,
  int idleInTransaction = 0,
  double? cache = 99.6,
  int deadlocks = 0,
  int size = 50 * 1024 * 1024,
  int monthly = 100,
  List<Map<String, dynamic>> running = const [],
  List<Map<String, dynamic>> tables = const [],
  int failingFeeds = 0,
  Map<String, dynamic>? broken,
}) =>
    AdminServer({
      'generated_at': '2026-10-01T12:00:00+00:00',
      'server': {
        'max_connections': max,
        'size_bytes': size,
        'cache_hit_percent': cache,
        'deadlocks': deadlocks,
        'connections': {'total': connections, 'idle_in_transaction': idleInTransaction},
      },
      'tables': tables,
      'running': running,
      'auth': {'signed_in_30d': monthly},
      'feeds': {
        'with_error': failingFeeds,
        'errors': failingFeeds == 0
            ? []
            : [
                {'guild': 'Mistwalkers', 'kind': 'news', 'error': 'timeout'},
              ],
      },
      'activity': {
        'events': [
          {'day': '2026-09-30', 'count': 2},
          {'day': '2026-10-01', 'count': 5},
        ],
      },
      ...?broken,
    });

void serverTests() {
  final now = DateTime.utc(2026, 10, 1, 12);
  HealthLine line(AdminServer s, String label) => s.health(now).firstWhere((l) => l.label == label);

  group('how full something is', () {
    test('is fine under 70 percent, a warning to 90, an alarm from there', () {
      expect(levelOfUse(0.1), HealthLevel.good);
      expect(levelOfUse(0.699), HealthLevel.good);
      expect(levelOfUse(0.7), HealthLevel.warn);
      expect(levelOfUse(0.89), HealthLevel.warn);
      expect(levelOfUse(0.9), HealthLevel.bad);
      expect(levelOfUse(1.3), HealthLevel.bad);
    });

    test('uptime', () {
      expect(uptime(now.subtract(const Duration(minutes: 12)), now), '12 min');
      expect(uptime(now.subtract(const Duration(hours: 5, minutes: 20)), now), '5 h 20 min');
      expect(uptime(now.subtract(const Duration(days: 3, hours: 4)), now), '3 d 4 h');
    });
  });

  group('the server report', () {
    test('is read as numbers, days and lists', () {
      final s = server();
      expect(s.count('server', 'max_connections'), 60);
      expect(s.cacheHitPercent, 99.6);
      expect(s.series('events').map((d) => d.count), [2, 5]);
      expect(s.series('nothing'), isEmpty);
      expect(s.list('tables'), isEmpty);
      expect(s.generatedAt, isNotNull);
      expect(AdminServer(const {'server': 5}).count('server', 'size_bytes'), 0,
          reason: 'a part of another kind is nothing');
    });

    test('says why a part could not be read', () {
      final s = server(broken: {
        'slow': {'error': 'relation does not exist'},
      });
      expect(s.problem('slow'), 'relation does not exist');
      expect(s.problem('tables'), isNull);
      expect(line(s, 'Could not read slow').detail, 'relation does not exist');
      expect(line(s, 'Could not read slow').level, HealthLevel.warn);
    });
  });

  group('server health', () {
    test('a server with room, a warm cache and nothing running is fine', () {
      final lines = server().health(now);
      expect(lines.where((l) => l.level != HealthLevel.good), isEmpty,
          reason: lines.map((l) => '${l.label}: ${l.detail}').join('; '));
    });

    test('connections are told against the most there may be', () {
      expect(line(server(connections: 20, max: 60), 'Connections').level, HealthLevel.good);
      expect(line(server(connections: 48, max: 60), 'Connections').level, HealthLevel.warn);
      expect(line(server(connections: 58, max: 60), 'Connections').level, HealthLevel.bad);
      expect(line(server(connections: 48, max: 60), 'Connections').detail, '48 of 60 in use');
    });

    test('a cold cache, deadlocks, open transactions and queries that hang are told', () {
      expect(line(server(cache: 97), 'Cache').level, HealthLevel.warn);
      expect(line(server(cache: 80), 'Cache').level, HealthLevel.bad);
      expect(line(server(deadlocks: 2), 'Deadlocks').level, HealthLevel.warn);
      expect(line(server(idleInTransaction: 3), 'Open transactions').level, HealthLevel.warn);
      final slow = server(running: [
        {'seconds': 8},
        {'seconds': 75},
      ]);
      expect(line(slow, 'Queries').level, HealthLevel.bad);
      expect(line(slow, 'Queries').detail, '2 running for more than 5 s, the longest 75 s');
      expect(
          line(
                  server(running: [
                    {'seconds': 8},
                  ]),
                  'Queries')
              .level,
          HealthLevel.warn);
    });

    test('the size and the monthly users are told against the limits of the free plan', () {
      expect(line(server(size: 100 * 1024 * 1024), 'Database size').level, HealthLevel.good);
      expect(line(server(size: 400 * 1024 * 1024), 'Database size').level, HealthLevel.warn);
      expect(line(server(size: 470 * 1024 * 1024), 'Database size').level, HealthLevel.bad);
      expect(line(server(monthly: 40000), 'Monthly users').level, HealthLevel.warn);
      expect(line(server(monthly: 46000), 'Monthly users').level, HealthLevel.bad);
    });

    test('a table with more dead rows than live ones, and a feed that fails, are told', () {
      final s = server(failingFeeds: 1, tables: [
        {'name': 'events', 'rows': 50, 'dead': 4000},
        {'name': 'profiles', 'rows': 50000, 'dead': 4000},
        {'name': 'tiny', 'rows': 0, 'dead': 10},
      ]);
      expect(s.health(now).where((l) => l.label == 'events').single.level, HealthLevel.warn);
      expect(s.health(now).where((l) => l.label == 'profiles'), isEmpty,
          reason: 'few dead rows against many live ones');
      expect(s.health(now).where((l) => l.label == 'tiny'), isEmpty, reason: 'too few to matter');
      expect(line(s, 'News feeds').detail, '1 failing: Mistwalkers news, timeout');
    });
  });
}

AdminHistory history({
  List<Map<String, dynamic>> snapshots = const [],
  List<Map<String, dynamic>> functions = const [],
  List<Map<String, dynamic>> keys = const [],
  List<Map<String, dynamic>> servers = const [],
  List<int> linksOk = const [],
  List<int> linksFailed = const [],
  List<int> botErrors = const [],
  Map<String, dynamic>? broken,
}) {
  List<Map<String, dynamic>> days(List<int> counts) => [
        for (var i = 0; i < counts.length; i++)
          {'day': '2026-09-${(i + 1).toString().padLeft(2, '0')}', 'count': counts[i]},
      ];
  return AdminHistory({
    'generated_at': '2026-10-01T12:00:00+00:00',
    'snapshots': snapshots,
    'functions': functions,
    'metric_keys': keys,
    'servers': servers,
    'series': {'links_ok': days(linksOk), 'links_failed': days(linksFailed), 'bot_errors': days(botErrors)},
    ...?broken,
  });
}

void historyTests() {
  final now = DateTime.utc(2026, 10, 1, 12);
  HealthLine line(AdminHistory h, String label) => h.health(now).firstWhere((l) => l.label == label);
  HealthLine fn(AdminHistory h, String label) => h.functionLines(now).firstWhere((l) => l.label == label);

  group('when the database will be full', () {
    ({DateTime day, int bytes}) at(int day, int mb) => (day: DateTime(2026, 9, day), bytes: mb * 1048576);

    test('is told from how it has grown, in days', () {
      // 10 MB a day, 200 MB now, 300 to go
      expect(projectDaysToLimit([at(1, 100), at(11, 200)], freeDatabaseBytes), 30);
      expect(projectDaysToLimit([at(1, 100), at(11, 200)], 210 * 1048576), 1);
    });

    test('is not told from too little, or from a database that does not grow, or says it is full', () {
      expect(projectDaysToLimit([at(1, 100)], freeDatabaseBytes), isNull);
      expect(projectDaysToLimit([at(1, 100), at(5, 140)], freeDatabaseBytes), isNull, reason: 'under a week');
      expect(projectDaysToLimit([at(1, 100), at(11, 100)], freeDatabaseBytes), isNull);
      expect(projectDaysToLimit([at(1, 200), at(11, 100)], freeDatabaseBytes), isNull, reason: 'it got smaller');
      expect(projectDaysToLimit([at(1, 400), at(11, 600)], freeDatabaseBytes), 0);
    });

    test('the last of a list', () {
      expect(tail([1, 2, 3, 4], 2), [3, 4]);
      expect(tail([1], 5), [1]);
    });
  });

  group('the history', () {
    test('is read as days, megabytes and what was counted most', () {
      final h = history(snapshots: [
        {'day': '2026-09-01', 'users': 10, 'db_bytes': 100 * 1048576},
        {'day': '2026-09-12', 'users': 40, 'db_bytes': 210 * 1048576},
      ], keys: [
        {'name': 'discord', 'key': 'command:/event create', 'total': 12},
        {'name': 'discord', 'key': 'command:/tyria status', 'total': 30},
        {'name': 'discord', 'key': 'command:/ping', 'total': 2},
        {'name': 'discord', 'key': 'component:rsvp', 'total': 99},
        {'name': 'gw2-link', 'key': 'error:401', 'total': 4},
      ]);
      expect(h.snapshotSeries('users').map((d) => d.count), [10, 40]);
      expect(h.databaseMegabytes.map((d) => d.count), [100, 210]);
      expect(h.daysToDatabaseLimit, 29);
      expect(h.top('discord', 'command:/').map((c) => c.key), ['tyria status', 'event create', 'ping'],
          reason: 'the most first, the prefix taken off');
      expect(h.top('discord', 'command:/', limit: 2), hasLength(2));
      expect(h.top('gw2-link', 'error:').single.key, '401');
      expect(h.top('discord', 'nothing:'), isEmpty);
    });

    test('survives an answer with parts missing or of another kind', () {
      const h = AdminHistory({'snapshots': 'nothing', 'series': 5});
      expect(h.list('snapshots'), isEmpty);
      expect(h.series('commands'), isEmpty);
      expect(h.snapshotSeries('users'), isEmpty);
      expect(h.daysToDatabaseLimit, isNull);
      expect(h.generatedAt, isNull);
    });
  });

  group('the functions', () {
    Map<String, dynamic> f(
            {String name = 'discord-sync',
            String? ok,
            String? err,
            String? why,
            int ms = 400,
            int runs = 100,
            int failures = 0}) =>
        {
          'name': name,
          'last_run_at': '2026-10-01T11:58:00+00:00',
          'last_ok_at': ok,
          'last_error_at': err,
          'last_error': why,
          'last_duration_ms': ms,
          'runs': runs,
          'failures': failures,
        };

    test('one that worked is fine, and says when and how long', () {
      final h = history(functions: [f(ok: '2026-10-01T11:58:00+00:00', failures: 3)]);
      expect(fn(h, 'discord-sync').level, HealthLevel.good);
      expect(fn(h, 'discord-sync').detail, 'Ran 2 min ago. 100 runs, 3 failed, last one took 0.4 s');
    });

    test('one whose last run failed is an alarm, with why, even if it worked before', () {
      final h = history(
          functions: [f(ok: '2026-10-01T09:00:00+00:00', err: '2026-10-01T11:30:00+00:00', why: 'boom', failures: 1)]);
      expect(fn(h, 'discord-sync').level, HealthLevel.bad);
      expect(fn(h, 'discord-sync').detail, startsWith('The last run failed 30 min ago: boom.'));
    });

    test('one that failed and then worked is fine again', () {
      final h = history(
          functions: [f(ok: '2026-10-01T11:58:00+00:00', err: '2026-10-01T09:00:00+00:00', why: 'boom', failures: 1)]);
      expect(fn(h, 'discord-sync').level, HealthLevel.good);
    });

    test('one that has never worked and failed is an alarm, a slow one a warning', () {
      expect(fn(history(functions: [f(err: '2026-10-01T11:00:00+00:00', why: 'x')]), 'discord-sync').level,
          HealthLevel.bad);
      final slow = fn(history(functions: [f(ok: '2026-10-01T11:58:00+00:00', ms: 31000)]), 'discord-sync');
      expect(slow.level, HealthLevel.warn);
      expect(slow.detail, startsWith('Slow: the last run took 31.0 s.'));
    });
  });

  group('what else is worth a look', () {
    test('servers that went wrong in the last day are told, older errors are not', () {
      final h = history(servers: [
        {
          'guild': 'Null Sector',
          'tag': 'NULL',
          'last_error': 'missing_permissions',
          'last_error_at': '2026-10-01T10:00:00+00:00'
        },
        {'guild': 'Old', 'tag': 'OLD', 'last_error': 'gone', 'last_error_at': '2026-09-20T10:00:00+00:00'},
      ]);
      expect(line(h, 'Null Sector').level, HealthLevel.warn);
      expect(line(h, 'Null Sector').detail, 'missing_permissions 2 h ago');
      expect(h.health(now).where((l) => l.label == 'Old'), isEmpty);
      expect(line(history(), 'Discord servers').level, HealthLevel.good);
    });

    test('linking is told by how much of it failed this week, once there is enough of it to say', () {
      expect(line(history(linksOk: [20], linksFailed: [2]), 'Linking game accounts').level, HealthLevel.good);
      expect(line(history(linksOk: [10], linksFailed: [5]), 'Linking game accounts').level, HealthLevel.warn);
      expect(line(history(linksOk: [4], linksFailed: [9]), 'Linking game accounts').level, HealthLevel.bad);
      expect(line(history(linksOk: [2], linksFailed: [3]), 'Linking game accounts').level, HealthLevel.good,
          reason: 'five tries say nothing');
      expect(line(history(), 'Linking game accounts').detail, 'None in the last 7 days');
    });

    test('the bot calls that broke today are a warning', () {
      expect(line(history(botErrors: [4, 0]), 'Bot calls').level, HealthLevel.good);
      final h = history(botErrors: [0, 3]);
      expect(line(h, 'Bot calls').level, HealthLevel.warn);
      expect(line(h, 'Bot calls').detail, '3 database errors today that were not a refusal');
    });

    test('a part that could not be read says why', () {
      final h = history(broken: {
        'guilds': {'error': 'permission denied'},
      });
      expect(h.problem('guilds'), 'permission denied');
      expect(line(h, 'Could not read guilds').detail, 'permission denied');
    });
  });
}

void versionTests() {
  final now = DateTime.utc(2026, 10, 1, 12);

  group('versions', () {
    test('are compared by number, not by letters', () {
      expect(compareVersions('0.80.0', '0.79.2'), greaterThan(0));
      expect(compareVersions('0.9.0', '0.10.0'), lessThan(0), reason: 'ten is more than nine');
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('1.2', '1.2.1'), lessThan(0));
      expect(compareVersions('other', '0.1.0'), lessThan(0), reason: 'what is not a number is the oldest');
      expect(compareVersions('0.1.0', 'other'), greaterThan(0));
      expect(compareVersions('other', 'other'), 0);
    });
  });

  group('the versions that were opened', () {
    AdminHistory opens(List<List<Object>> rows) => AdminHistory({
          'app_versions': [
            for (final r in rows) {'platform': r[0], 'version': r[1], 'opens_7d': r[2], 'opens_30d': r[3]},
          ],
        });

    test('come newest first, and the most opened of a version first', () {
      final h = opens([
        ['android', '0.79.0', 10, 40],
        ['web', '0.80.0', 3, 5],
        ['android', '0.80.0', 30, 31],
        ['android', 'other', 2, 2],
        ['android', '0.9.0', 1, 1],
      ]);
      expect(h.appVersions.map((v) => '${v.platform} ${v.version}'), [
        'android 0.80.0',
        'web 0.80.0',
        'android 0.79.0',
        'android 0.9.0',
        'android other',
      ]);
    });

    test('say how much of the week was of the newest, not counting what is not a number as the newest', () {
      final h = opens([
        ['android', '0.80.0', 30, 31],
        ['web', '0.80.0', 10, 12],
        ['android', '0.79.0', 40, 80],
        ['android', 'other', 20, 20],
      ]);
      expect(h.newestVersionShare, closeTo(0.4, 0.0001), reason: '40 of 100 opens');
      expect(opens([]).newestVersionShare, isNull);
      expect(opens([['android', '0.80.0', 0, 5]]).newestVersionShare, isNull, reason: 'none this week');
      expect(opens([['android', 'other', 4, 4]]).newestVersionShare, 0.0, reason: 'only what is not a number, so none of the newest');
    });

    test('survive an answer that is not a list', () {
      const h = AdminHistory({'app_versions': {'error': 'permission denied'}});
      expect(h.appVersions, isEmpty);
      expect(h.problem('app_versions'), 'permission denied');
      expect(h.newestVersionShare, isNull);
    });
  });

  group('the news feed', () {
    AdminHistory news({List<int> ok = const [], List<int> failed = const []}) {
      List<Map<String, dynamic>> days(List<int> c) => [
            for (var i = 0; i < c.length; i++) {'day': '2026-09-${(i + 1).toString().padLeft(2, '0')}', 'count': c[i]},
          ];
      return AdminHistory({
        'series': {'news_ok': days(ok), 'news_failed': days(failed)},
      });
    }

    HealthLine line(AdminHistory h) => h.health(now).firstWhere((l) => l.label == 'News feed');

    test('is told by how much of it failed this week, once there is enough of it to say', () {
      expect(line(news(ok: [90], failed: [5])).level, HealthLevel.good);
      expect(line(news(ok: [60], failed: [30])).level, HealthLevel.warn);
      expect(line(news(ok: [10], failed: [40])).level, HealthLevel.bad);
      expect(line(news(ok: [3], failed: [4])).level, HealthLevel.good, reason: 'seven requests say nothing');
      expect(line(news()).detail, 'No request in the last 7 days');
      expect(line(news(ok: [90], failed: [5])).detail, '5 of 95 requests failed in the last 7 days');
    });

    test('counts the last seven days only', () {
      final old = [for (var i = 0; i < 20; i++) 100];
      final h = news(ok: [...old, 50, 50, 50, 50, 50, 50, 50], failed: [...old.map((_) => 900), 0, 0, 0, 0, 0, 0, 0]);
      expect(line(h).level, HealthLevel.good, reason: 'the failures were weeks ago');
    });
  });
}
