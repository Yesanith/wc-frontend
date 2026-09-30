import 'package:flutter_test/flutter_test.dart';
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
      expect(AdminServer(const {'server': 5}).count('server', 'size_bytes'), 0, reason: 'a part of another kind is nothing');
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
      expect(lines.where((l) => l.level != HealthLevel.good), isEmpty, reason: lines.map((l) => '${l.label}: ${l.detail}').join('; '));
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
      expect(line(server(running: [
        {'seconds': 8},
      ]), 'Queries').level, HealthLevel.warn);
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
      expect(s.health(now).where((l) => l.label == 'profiles'), isEmpty, reason: 'few dead rows against many live ones');
      expect(s.health(now).where((l) => l.label == 'tiny'), isEmpty, reason: 'too few to matter');
      expect(line(s, 'News feeds').detail, '1 failing: Mistwalkers news, timeout');
    });
  });
}
