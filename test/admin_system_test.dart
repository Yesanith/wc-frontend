import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tyria_codex/screens/admin/system_tab.dart';
import 'package:tyria_codex/state/admin.dart';
import 'package:tyria_codex/state/admin_system.dart';
import 'package:tyria_codex/state/settings.dart';
import 'package:tyria_codex/theme.dart';

void main() {
  final now = DateTime.now();
  String at(int minutesAgo) => now.subtract(Duration(minutes: minutesAgo)).toUtc().toIso8601String();

  Map<String, dynamic> sync(String fn,
          {int calls = 4,
          int ok = 4,
          int unauthorized = 0,
          int failed = 0,
          int timedOut = 0,
          int noAnswer = 0,
          int? status = 200}) =>
      {
        'fn': fn,
        'calls': calls,
        'ok': ok,
        'unauthorized': unauthorized,
        'failed': failed,
        'timed_out': timedOut,
        'no_answer': noAnswer,
        'last_call_at': at(1),
        'last_status': status,
        'last_answer': 'x',
      };

  AdminSystem system(Map<String, dynamic> over) => AdminSystem({'generated_at': at(0), ...over});

  group('what the sync functions answered', () {
    test('one that is refused by every call says why and what to do, and is the thing to see first', () {
      final lines = system({
        'sync': [sync('discord-sync', calls: 3, ok: 0, unauthorized: 3, status: 401), sync('tp-sync')]
      }).syncLines(now);
      final line = lines.firstWhere((l) => l.label == 'discord-sync');
      expect(line.level, HealthLevel.bad);
      expect(line.detail, contains('Refused 3 of 3 calls (401)'));
      expect(line.detail, contains('Deploy'));
    });

    test('one that is refused by some and not by others is a warning, with how many', () {
      final line = system({
        'sync': [sync('discord-sync', ok: 2, unauthorized: 2, status: 200), sync('tp-sync')]
      }).syncLines(now).firstWhere((l) => l.label == 'discord-sync');
      expect(line.level, HealthLevel.warn);
      expect(line.detail, contains('2 of 4 calls refused (401), 2 ok'));
    });

    test('one that failed or timed out is a warning, with what it was', () {
      final line = system({
        'sync': [sync('push-sync', ok: 1, failed: 2, timedOut: 1, status: 500), sync('tp-sync')]
      }).syncLines(now).firstWhere((l) => l.label == 'push-sync');
      expect(line.level, HealthLevel.warn);
      expect(line.detail, contains('2 failed, 1 timed out, 1 ok of 4'));
    });

    test('one with calls and no answer yet is a warning, and one that is all well is good with its last answer', () {
      final lines = system({
        'sync': [sync('push-sync', calls: 1, ok: 0, noAnswer: 1, status: null), sync('tp-sync', noAnswer: 1)]
      }).syncLines(now);
      expect(lines.firstWhere((l) => l.label == 'push-sync').level, HealthLevel.warn);
      expect(lines.firstWhere((l) => l.label == 'push-sync').detail, contains('No answer yet to 1 call'));
      final good = lines.firstWhere((l) => l.label == 'tp-sync');
      expect(good.level, HealthLevel.good);
      expect(good.detail, contains('4 of 4 ok'));
      expect(good.detail, contains('last answer 200'));
      expect(good.detail, contains('1 waiting'));
    });

    test('the trading post function that was not called in the last hour is said, since it is woken every ten minutes',
        () {
      final lines = system({
        'sync': [sync('discord-sync')]
      }).syncLines(now);
      final tp = lines.firstWhere((l) => l.label == 'tp-sync');
      expect(tp.level, HealthLevel.warn);
      expect(tp.detail, contains('every ten minutes'));
      expect(
          system({
            'sync': [sync('tp-sync')]
          }).syncLines(now).where((l) => l.label == 'tp-sync').length,
          1);
      expect(system({}).syncLines(now).single.label, 'tp-sync', reason: 'with nothing at all, that is what is said');
    });
  });

  group('the trading post', () {
    Map<String, dynamic> trading({int? readMinutesAgo = 5}) => {
          'trading_post': {
            'snapshot_at': readMinutesAgo == null ? null : at(readMinutesAgo),
            'snapshot_items': 28123,
            'snapshot_bytes': 1250000,
            'latest_items': 28123,
            'tracked': 40,
            'tracked_unread': 3,
            'asked_24h': 12,
            'history_points': 280,
            'history_oldest': '2026-09-25',
            'history_newest': '2026-10-02',
            'history_by_day': [
              {'day': '2026-10-01', 'points': 38},
              {'day': '2026-10-02', 'points': 40},
            ],
            'recently_asked': [
              {'item_id': 19721, 'asked_at': at(2)},
            ],
          },
        };

    test(
        'has a list that is the price now while it was read in the last twenty five minutes, a warning to an hour, and an alarm after',
        () {
      HealthLine list(int? minutes) => system(trading(readMinutesAgo: minutes)).tradingLines(now).first;
      expect(list(5).level, HealthLevel.good);
      expect(list(24).level, HealthLevel.good);
      expect(list(40).level, HealthLevel.warn);
      expect(list(120).level, HealthLevel.bad);
      expect(list(null).level, HealthLevel.warn);
      expect(list(null).detail, 'Not read yet');
    });

    test('says how many items, how long ago and how big the list is, and what is kept with a history', () {
      final lines = system(trading()).tradingLines(now);
      expect(lines.first.detail, contains('28123 items'));
      expect(lines.first.detail, contains('read 5 min ago'));
      expect(lines.first.detail, contains('1.2 MB'));
      expect(lines[2].detail, contains('40 items'));
      expect(lines[2].detail, contains('3 not read yet'));
      expect(lines[2].detail, contains('12 asked for in the last day'));
      expect(lines[3].detail, contains('280 points, from 2026-09-25 to 2026-10-02'));
    });

    test('has the points by day, and the items asked for last', () {
      final sys = system(trading());
      expect(sys.historyByDay.map((d) => d.count), [38, 40]);
      expect(sys.recentlyAsked.single.itemId, 19721);
      expect(sys.recentlyAsked.single.at, isNotNull);
    });

    test('has no points yet when there is no history, and is none of it when the server has nothing', () {
      final empty = system({
        'trading_post': {'snapshot_at': null, 'history_oldest': null}
      });
      expect(empty.tradingLines(now).last.detail, 'No points yet');
      expect(system({}).tradingLines(now).first.level, HealthLevel.warn);
      expect(system({}).historyByDay, isEmpty);
    });
  });

  group('the official server', () {
    Map<String, dynamic> official(
            {bool configured = true,
            String? error,
            bool invite = true,
            bool voice = false,
            int attempts = 0,
            int due = 3}) =>
        {
          'official': {
            'configured': configured,
            'guild_tail': '5678',
            'invite_set': invite,
            'roles': {'eu': '1111', 'na': '2222'},
            'categories': {'eu': true, 'na': true, 'active': true},
            'kinds_eu': ['fractal', 'meta', 'pvp', 'raid', 'strike', 'worldboss', 'wvw', 'other'],
            'kinds_na': ['raid'],
            'last_error': error,
            'last_error_at': error == null ? null : at(3),
            'messages': 14,
            'outbox': [
              {
                'title': 'EU raid',
                'region': 'eu',
                'attempts': attempts,
                'last_error': attempts > 0 ? 'missing_permissions' : null,
                'queued_at': at(9)
              },
            ],
            'active': [
              {'title': 'Fractals', 'region': 'eu', 'voice': voice, 'text': true, 'granted': 5},
            ],
            'role_sync': {'tracked': 120, 'dirty': 2, 'never': 4, 'due': due, 'cleanup': 1},
            'drafts': {'open': 2, 'expired': 1},
            'timezones': 31,
          },
        };

    test('says when it is not set up, and nothing else', () {
      final lines = system(official(configured: false)).officialLines(now);
      expect(lines.single.level, HealthLevel.warn);
      expect(lines.single.detail, contains('/official setup'));
    });

    test('is told by the last digits of its ids only, with an invite', () {
      final lines = system(official()).officialLines(now);
      expect(lines.first.detail, contains('…5678'));
      expect(lines.first.detail, contains('…1111'));
      expect(lines.first.detail, contains('invite set'));
      expect(lines.first.level, HealthLevel.good);
      expect(system(official(invite: false)).officialLines(now).first.level, HealthLevel.warn);
    });

    test('says the kinds of channel it has in each region, and warns when they are not all there', () {
      final line = system(official()).officialLines(now).firstWhere((l) => l.label == 'Channels of the kinds');
      expect(line.detail, 'Europe 8 of 8, North America 1 of 8');
      expect(line.level, HealthLevel.warn);
    });

    test('has its last problem, and an event going on that has no voice channel is a warning', () {
      final bad = system(official(error: 'Voice: refused')).officialLines(now);
      expect(bad.firstWhere((l) => l.label == 'Last problem').level, HealthLevel.bad);
      expect(bad.firstWhere((l) => l.label == 'Last problem').detail, contains('Voice: refused'));
      expect(
          system(official()).officialLines(now).firstWhere((l) => l.label == 'Last problem').level, HealthLevel.good);
      final events = system(official()).officialLines(now).firstWhere((l) => l.label == 'Events going on');
      expect(events.level, HealthLevel.warn);
      expect(events.detail, '1 with channels, 1 without a voice channel');
      expect(system(official(voice: true)).officialLines(now).firstWhere((l) => l.label == 'Events going on').level,
          HealthLevel.good);
    });

    test('has the posts that wait, with how many fail, and the roles that are due', () {
      final posts = system(official(attempts: 2)).officialLines(now).firstWhere((l) => l.label == 'Posts waiting');
      expect(posts.level, HealthLevel.warn);
      expect(posts.detail, '1 waiting, 1 failing, 14 messages kept');
      expect(
          system(official()).officialLines(now).firstWhere((l) => l.label == 'Posts waiting').level, HealthLevel.good);
      final roles = system(official()).officialLines(now).firstWhere((l) => l.label == 'Roles');
      expect(roles.detail, contains('120 players tracked'));
      expect(roles.detail, contains('3 due'));
      expect(
          system(official(due: 80)).officialLines(now).firstWhere((l) => l.label == 'Roles').level, HealthLevel.warn);
    });

    test('has the forms and the time zones', () {
      final line = system(official()).officialLines(now).firstWhere((l) => l.label == 'Forms of /event public');
      expect(line.detail, '2 open, 1 expired, 31 time zones remembered');
    });
  });

  group('the public events and the tables', () {
    final sys = system({
      'public_events': {
        'total': 12,
        'with_roles': 5,
        'going': 40,
        'maybe': 9,
        'organizers': 7,
        'banned': 1,
        'reports_waiting': 2,
        'by_status': [
          {'status': 'scheduled', 'n': 8},
          {'status': 'hidden', 'n': 1},
        ],
        'upcoming_by_region': [
          {'region': 'eu', 'n': 6},
        ],
        'by_activity_30d': [
          {'activity': 'raid', 'n': 4},
        ],
        'by_role': [
          {'role': 'dps', 'n': 20},
        ],
        'by_profession': [
          {'profession': 'Guardian', 'n': 9},
        ],
        'created_by_day': [
          {'day': '2026-10-02', 'n': 3},
        ],
        'signups_by_day': [
          {'day': '2026-10-02', 'n': 11},
        ],
      },
      'tables': [
        {'name': 'tp_snapshot', 'rows': 1, 'bytes': 2400000, 'newest': at(4)},
        {'name': 'open_events', 'rows': 12, 'bytes': 65536, 'newest': at(60)},
        {'name': 'metrics', 'rows': 5000, 'bytes': 900000, 'newest': null},
      ],
    });

    test('are in numbers: how many, how many are going, who makes them, and what waits for a look', () {
      final lines = sys.publicLines();
      expect(lines[0].detail, '12 made, 5 with roles');
      expect(lines[1].detail, '40 going, 9 maybe');
      expect(lines[2].detail, '7 players, 1 kept from making events');
      expect(lines[3].level, HealthLevel.warn);
      expect(lines[3].detail, '2 events wait for a look');
      expect(system({'public_events': {}}).publicLines().last.level, HealthLevel.good);
    });

    test('are broken down by state, region, kind, role and profession, and by day', () {
      expect(sys.byStatus.map((e) => (e.label, e.count)), [('scheduled', 8), ('hidden', 1)]);
      expect(sys.upcomingByRegion.single.label, 'eu');
      expect(sys.byActivity.single.count, 4);
      expect(sys.byRole.single.label, 'dps');
      expect(sys.byProfession.single.label, 'Guardian');
      expect(sys.createdByDay.single.count, 3);
      expect(sys.signupsByDay.single.count, 11);
    });

    test('have every table, with its rows, its size and when something was last put in it, and the sum of them', () {
      expect(sys.tables.length, 3);
      expect(sys.tables.first.name, 'tp_snapshot');
      expect(sys.tables[1].rows, 12);
      expect(sys.tables[1].newest, isNotNull);
      expect(sys.tables[2].newest, isNull, reason: 'a table with nothing to say when');
      expect(sys.totalRows, 5013);
      expect(sys.totalBytes, 2400000 + 65536 + 900000);
      expect(system({}).tables, isEmpty);
    });
  });

  group('the schedule of a job', () {
    test('is how often it runs, for the shapes the backend uses', () {
      expect(cronPeriod('20 seconds'), const Duration(seconds: 20));
      expect(cronPeriod('1 second'), const Duration(seconds: 1));
      expect(cronPeriod('*/10 * * * *'), const Duration(minutes: 10));
      expect(cronPeriod('5 * * * *'), const Duration(hours: 1));
      expect(cronPeriod('50 3 * * *'), const Duration(days: 1));
      for (final odd in [
        '0 seconds',
        '*/0 * * * *',
        '*/60 * * * *',
        '61 * * * *',
        '5 24 * * *',
        '0 0 1 * *',
        '* * * * 1',
        'nonsense',
        ''
      ]) {
        expect(cronPeriod(odd), isNull, reason: odd);
      }
    });

    test('is said in words', () {
      expect(cronEvery('20 seconds'), 'every 20 s');
      expect(cronEvery('*/10 * * * *'), 'every 10 min');
      expect(cronEvery('5 * * * *'), 'hourly at :05');
      expect(cronEvery('5 0 * * *'), 'daily at 00:05 UTC');
      expect(cronEvery('50 3 * * *'), 'daily at 03:50 UTC');
      expect(cronEvery('0 0 1 * *'), '0 0 1 * *', reason: 'as written when it is none of those');
    });

    test(
        'has a next run for a step of minutes, to the minute that is next of the hour, and the first of the next hour after the last',
        () {
      DateTime next(String s, int h, int m) => nextCronRun(s, DateTime.utc(2026, 10, 2, h, m, 30))!;
      expect(next('*/10 * * * *', 12, 3), DateTime.utc(2026, 10, 2, 12, 10));
      expect(next('*/10 * * * *', 12, 10), DateTime.utc(2026, 10, 2, 12, 20),
          reason: 'it ran at ten, the next is twenty');
      expect(next('*/10 * * * *', 12, 55), DateTime.utc(2026, 10, 2, 13));
      expect(next('*/7 * * * *', 12, 56), DateTime.utc(2026, 10, 2, 13),
          reason: 'a step of seven goes 0, 7, ... 56 and then the hour');
      expect(next('*/10 * * * *', 23, 55), DateTime.utc(2026, 10, 3, 0), reason: 'over the end of the day');
    });

    test(
        'has a next run for the time of an hour and of a day, today when it is to come and tomorrow when it has passed',
        () {
      DateTime next(String s, int h, int m) => nextCronRun(s, DateTime.utc(2026, 10, 2, h, m, 30))!;
      expect(next('5 * * * *', 12, 3), DateTime.utc(2026, 10, 2, 12, 5));
      expect(next('5 * * * *', 12, 5), DateTime.utc(2026, 10, 2, 13, 5));
      expect(next('50 3 * * *', 1, 0), DateTime.utc(2026, 10, 2, 3, 50));
      expect(next('50 3 * * *', 3, 50), DateTime.utc(2026, 10, 3, 3, 50));
      expect(next('50 3 * * *', 12, 0), DateTime.utc(2026, 10, 3, 3, 50));
      expect(next('5 0 * * *', 0, 1), DateTime.utc(2026, 10, 2, 0, 5),
          reason: 'five past midnight is still to come at one past');
      expect(next('5 0 * * *', 0, 6), DateTime.utc(2026, 10, 3, 0, 5), reason: 'and tomorrow\'s at six past');
    });

    test(
        'has none for a job that runs every so many seconds, which is always about to, and for the shapes it does not know',
        () {
      expect(nextCronRun('20 seconds', now), isNull);
      for (final odd in ['0 0 1 * *', 'nonsense', '', '*/70 * * * *', '5 25 * * *']) {
        expect(nextCronRun(odd, now), isNull, reason: odd);
      }
    });

    test('is in minutes and hours', () {
      expect(untilLabel(const Duration(seconds: 20)), 'in under a minute');
      expect(untilLabel(const Duration(minutes: 6)), 'in 6 min');
      expect(untilLabel(const Duration(hours: 3, minutes: 10)), 'in 3 h 10 min');
      expect(untilLabel(const Duration(days: 2, hours: 3)), 'in 2 d');
    });

    test('is overdue when the job has not run for much more than it says it does, and never for one that is not known',
        () {
      final t = DateTime.utc(2026, 10, 2, 12);
      expect(cronOverdue('*/10 * * * *', t.subtract(const Duration(minutes: 15)), t), isFalse);
      expect(cronOverdue('*/10 * * * *', t.subtract(const Duration(minutes: 30)), t), isTrue);
      expect(cronOverdue('20 seconds', t.subtract(const Duration(minutes: 2)), t), isFalse,
          reason: 'two minutes of grace');
      expect(cronOverdue('20 seconds', t.subtract(const Duration(minutes: 5)), t), isTrue);
      expect(cronOverdue('50 3 * * *', t.subtract(const Duration(hours: 30)), t), isFalse);
      expect(cronOverdue('50 3 * * *', t.subtract(const Duration(days: 3)), t), isTrue);
      expect(cronOverdue('0 0 1 * *', t.subtract(const Duration(days: 300)), t), isFalse);
    });

    test('is a line for each job, with its state', () {
      final jobs = [
        {
          'name': 'dispatch-tp-sync',
          'schedule': '*/10 * * * *',
          'active': true,
          'last_status': 'succeeded',
          'last_run': at(4)
        },
        {'name': 'late', 'schedule': '*/10 * * * *', 'active': true, 'last_status': 'succeeded', 'last_run': at(90)},
        {
          'name': 'broken',
          'schedule': '50 3 * * *',
          'active': true,
          'last_status': 'failed',
          'last_run': at(30),
          'last_message': 'boom'
        },
        {'name': 'fresh', 'schedule': '20 seconds', 'active': true, 'last_status': null, 'last_run': null},
        {'name': 'off', 'schedule': '5 0 * * *', 'active': false, 'last_status': 'succeeded', 'last_run': at(500)},
      ];
      final lines = cronLines(jobs, now);
      HealthLine line(String name) => lines.firstWhere((l) => l.label == name);
      expect(line('dispatch-tp-sync').level, HealthLevel.good);
      expect(line('dispatch-tp-sync').detail, startsWith('every 10 min, ran 4 min ago, next in '));
      expect(line('late').level, HealthLevel.bad);
      expect(line('late').detail, contains('overdue'));
      expect(line('broken').level, HealthLevel.bad);
      expect(line('broken').detail, contains('failed 30 min ago: boom'));
      expect(line('fresh').level, HealthLevel.warn);
      expect(line('fresh').detail, 'every 20 s, has not run yet');
      expect(line('off').level, HealthLevel.warn);
      expect(line('off').detail, 'daily at 00:05 UTC, switched off');
    });
  });

  group('the tab', () {
    testWidgets(
        'shows what the sync functions answered, the jobs, the official server, the public events and every table',
        (tester) async {
      tester.view.physicalSize = const Size(1800, 9000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // the words of the page come from the language, which is kept in the preferences
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final sys = system({
        'sync': [sync('discord-sync', calls: 3, ok: 0, unauthorized: 3, status: 401), sync('tp-sync')],
        'sync_calls_total': 7,
        'official': {'configured': false},
        'public_events': {'total': 2},
        'tables': [
          {'name': 'open_events', 'rows': 2, 'bytes': 8192, 'newest': at(5)},
          {'name': 'tp_latest', 'rows': 28000, 'bytes': 3000000, 'newest': null},
        ],
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          adminSystemProvider.overrideWith((ref) async => sys),
          adminDashboardProvider.overrideWith((ref) async => AdminDashboard({
                'cron': [
                  {
                    'name': 'dispatch-tp-sync',
                    'schedule': '*/10 * * * *',
                    'active': true,
                    'last_status': 'succeeded',
                    'last_run': at(4)
                  },
                ],
              })),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          // a test's font has every letter as wide as it is tall, a real one a little over half of that
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.6)),
            child: child!,
          ),
          home: const Scaffold(body: AdminSystemTab()),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Refused 3 of 3 calls (401)'), findsOneWidget, reason: 'the first thing to see');
      expect(find.textContaining('7 calls are kept'), findsOneWidget);
      expect(find.textContaining('every 10 min, ran 4 min ago'), findsOneWidget,
          reason: 'the job with when it runs next');
      expect(find.textContaining('Not set up. Run /official setup'), findsOneWidget);
      expect(find.textContaining('2 made'), findsOneWidget);
      expect(find.textContaining('2 tables, 28,002 rows'), findsOneWidget,
          reason: 'the rows of both tables: 2 and 28,000');
      expect(find.text('tp_latest'), findsOneWidget);
      expect(find.text('open_events'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
