import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/data/metas.dart';
import 'package:wondrous_compass/services/boss_alerts.dart';

const _maps = <MetaMap>[
  MetaMap('m1', 'Sunken Coast', Expansion.core, [
    MetaEvent('Tequatl', [60, 180, 1439], kind: MetaKind.hardBoss),
    MetaEvent('Other', [30]),
  ]),
  MetaMap('m2', 'Verdant Brink', Expansion.hot, [
    MetaEvent('Night bell', [3, 900]),
  ]),
];

String _body(MetaMap map) => 'soon · ${map.name}';

String _key(int map, int event) => eventKey(_maps[map], _maps[map].events[event]);

void main() {
  test('every start time of a pinned event gets an alert lead minutes before it', () {
    final plan = planBossAlerts(pins: {_key(0, 0)}, lead: 10, body: _body, maps: _maps);
    expect(plan.alerts.map((a) => a.minuteOfDay), [50, 170, 1429]);
    expect(plan.alerts.every((a) => a.title == 'Tequatl'), isTrue);
    expect(plan.alerts.first.body, 'soon · Sunken Coast');
    expect(plan.skipped, isEmpty);
  });

  test('an event that starts just after midnight is announced on the evening before', () {
    final plan = planBossAlerts(pins: {_key(1, 0)}, lead: 15, body: _body, maps: _maps);
    // 00:03 minus 15 minutes is 23:48
    expect(plan.alerts.map((a) => a.minuteOfDay), [885, 1428]);
  });

  test('nothing pinned, no alerts; unknown pins are ignored', () {
    expect(planBossAlerts(pins: {}, lead: 10, body: _body, maps: _maps).alerts, isEmpty);
    final plan = planBossAlerts(pins: {'nope/nothing'}, lead: 10, body: _body, maps: _maps);
    expect(plan.alerts, isEmpty);
    expect(plan.skipped, isEmpty);
  });

  test('alerts come sorted by time of day, then name', () {
    final plan = planBossAlerts(
      pins: {
        for (var m = 0; m < _maps.length; m++)
          for (var e = 0; e < _maps[m].events.length; e++) _key(m, e)
      },
      lead: 10,
      body: _body,
      maps: _maps,
    );
    final minutes = plan.alerts.map((a) => a.minuteOfDay).toList();
    expect(minutes, [...minutes]..sort());
    expect(plan.alerts.length, 3 + 1 + 2);
  });

  test('ids are stable and never clash', () {
    expect(bossAlertId('a/b', 60), bossAlertId('a/b', 60));
    expect(bossAlertId('a/b', 60), isNot(bossAlertId('a/b', 61)));
    expect(bossAlertId('a/b', 60), isNot(bossAlertId('a/c', 60)));
    expect(bossAlertId('anything', 5), inInclusiveRange(0, 0x7fffffff));
  });

  test('past the limit the events pinned last go without, whole, and are named', () {
    // 3 + 1 + 2 starts: a limit of 4 fits the first event and the single one
    final order = [_key(0, 0), _key(0, 1), _key(1, 0)];
    final plan = planBossAlerts(pins: order, lead: 10, body: _body, maps: _maps, limit: 4);
    expect(plan.alerts.length, 4);
    expect(plan.skipped, [_key(1, 0)]);
    // pinned in another order, another event is the one left out
    final other =
        planBossAlerts(pins: [_key(1, 0), _key(0, 0), _key(0, 1)], lead: 10, body: _body, maps: _maps, limit: 4);
    expect(other.skipped, [_key(0, 0)]);
    expect(other.alerts.map((a) => a.title).toSet(), {'Night bell', 'Other'});
    // never a part of an event
    final tight = planBossAlerts(pins: [_key(0, 0)], lead: 10, body: _body, maps: _maps, limit: 2);
    expect(tight.alerts, isEmpty);
    expect(tight.skipped, [_key(0, 0)]);
  });

  test('the real schedule: the limit keeps every plan within what Android allows', () {
    final all = [
      for (final m in metaMaps)
        for (final e in m.events) eventKey(m, e),
    ];
    var starts = 0;
    for (final m in metaMaps) {
      for (final e in m.events) {
        starts += e.times.length;
      }
    }
    // pinning everything really does not fit
    expect(starts, greaterThan(maxBossAlerts));
    final plan = planBossAlerts(pins: all, lead: 10, body: (m) => m.name);
    expect(plan.alerts.length, lessThanOrEqualTo(maxBossAlerts));
    expect(plan.alerts.length, greaterThan(maxBossAlerts - 30), reason: 'the room is used, not wasted');
    expect(plan.skipped, isNotEmpty);
    expect(plan.alerts.map((a) => a.id).toSet().length, plan.alerts.length, reason: 'ids are unique');
    // what a few pinned events cost is far below it
    final few = planBossAlerts(pins: all.take(10), lead: 10, body: (m) => m.name);
    expect(few.skipped, isEmpty);
  });

  test('the next alert is today when the time is ahead, tomorrow when it passed', () {
    final now = DateTime.utc(2026, 9, 29, 12, 0);
    expect(nextAlertAt(now, 13 * 60), DateTime.utc(2026, 9, 29, 13));
    expect(nextAlertAt(now, 11 * 60), DateTime.utc(2026, 9, 30, 11));
    // right now counts as passed, the plugin refuses a moment in the past
    expect(nextAlertAt(now, 12 * 60), DateTime.utc(2026, 9, 30, 12));
    // a moment a few seconds away is too close to schedule as today
    expect(nextAlertAt(DateTime.utc(2026, 9, 29, 11, 59, 55), 12 * 60), DateTime.utc(2026, 9, 30, 12));
    // a phone in another time zone gets the same answer
    expect(nextAlertAt(DateTime.parse('2026-09-29T15:00:00+03:00'), 13 * 60), DateTime.utc(2026, 9, 29, 13));
    // across a month and a year end
    expect(nextAlertAt(DateTime.utc(2026, 12, 31, 23, 50), 30), DateTime.utc(2027, 1, 1, 0, 30));
  });

  test('the signature changes with the plan, the timing mode and the wording', () {
    final pins = {_key(0, 0)};
    final a = planBossAlerts(pins: pins, lead: 10, body: _body, maps: _maps).alerts;
    final same = planBossAlerts(pins: pins, lead: 10, body: _body, maps: _maps).alerts;
    expect(alertsSignature(a, exact: true), alertsSignature(same, exact: true));
    expect(alertsSignature(a, exact: true), isNot(alertsSignature(a, exact: false)));
    final other = planBossAlerts(pins: pins, lead: 15, body: _body, maps: _maps).alerts;
    expect(alertsSignature(a, exact: true), isNot(alertsSignature(other, exact: true)));
    final worded = planBossAlerts(pins: pins, lead: 10, body: (m) => 'in ${m.name}', maps: _maps).alerts;
    expect(alertsSignature(a, exact: true), isNot(alertsSignature(worded, exact: true)));
  });

  test('only the alerts payload opens the events', () {
    expect(isBossAlertPayload('world_events'), isTrue);
    expect(isBossAlertPayload('event'), isFalse);
    expect(isBossAlertPayload(null), isFalse);
  });

  group('the reminders of the resets', () {
    List<BossAlert> plan({bool daily = true, bool weekly = true}) => planResetAlerts(
          daily: daily,
          weekly: weekly,
          dailyTitle: 'daily',
          dailyBody: 'daily body',
          weeklyTitle: 'weekly',
          weeklyBody: 'weekly body',
        );

    test('come an hour before: 23:00 utc every day, and 06:30 utc on Monday', () {
      final alerts = plan();
      expect(alerts, hasLength(2));
      expect(alerts[0].id, dailyResetAlertId);
      expect(alerts[0].minuteOfDay, 23 * 60);
      expect(alerts[0].weekday, isNull);
      expect(alerts[1].id, weeklyResetAlertId);
      expect(alerts[1].minuteOfDay, 6 * 60 + 30);
      expect(alerts[1].weekday, DateTime.monday);
    });

    test('are only the ones asked for', () {
      expect(plan(daily: false, weekly: false), isEmpty);
      expect(plan(weekly: false).single.id, dailyResetAlertId);
      expect(plan(daily: false).single.id, weeklyResetAlertId);
    });

    test('have ids apart from each other and from those of the events', () {
      final events = planBossAlerts(pins: [
        for (final m in metaMaps)
          for (final e in m.events) eventKey(m, e)
      ], lead: 10, body: (_) => '', limit: 100000);
      final ids = {for (final a in events.alerts) a.id};
      expect(ids.contains(dailyResetAlertId), isFalse);
      expect(ids.contains(weeklyResetAlertId), isFalse);
      expect(dailyResetAlertId, isNot(weeklyResetAlertId));
    });

    test('a weekly alert is set for the next time that day and time come round', () {
      // Tuesday 6 October 2026, 12:00 utc: the next Monday is the 12th
      final tuesday = DateTime.utc(2026, 10, 6, 12);
      expect(nextAlertAt(tuesday, 6 * 60 + 30, weekday: DateTime.monday), DateTime.utc(2026, 10, 12, 6, 30));
      // Monday 5 October before the time: that very day
      expect(nextAlertAt(DateTime.utc(2026, 10, 5, 5), 6 * 60 + 30, weekday: DateTime.monday),
          DateTime.utc(2026, 10, 5, 6, 30));
      // Monday after the time: a week on
      expect(nextAlertAt(DateTime.utc(2026, 10, 5, 7), 6 * 60 + 30, weekday: DateTime.monday),
          DateTime.utc(2026, 10, 12, 6, 30));
      // a Sunday evening
      expect(nextAlertAt(DateTime.utc(2026, 10, 11, 22), 6 * 60 + 30, weekday: DateTime.monday),
          DateTime.utc(2026, 10, 12, 6, 30));
    });

    test('change the signature of what is scheduled', () {
      final a = alertsSignature(plan(), exact: true);
      expect(alertsSignature(plan(weekly: false), exact: true), isNot(a));
      expect(alertsSignature(plan(), exact: true), a);
    });
  });
}
