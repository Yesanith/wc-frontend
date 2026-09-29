import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/data/metas.dart';
import 'package:tyria_codex/services/boss_alerts.dart';

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

void main() {
  test('every start time of a pinned event gets an alert lead minutes before it', () {
    final alerts = planBossAlerts(
      pins: {eventKey(_maps[0], _maps[0].events[0])},
      lead: 10,
      body: _body,
      maps: _maps,
    );
    expect(alerts.map((a) => a.minuteOfDay), [50, 170, 1429]);
    expect(alerts.every((a) => a.title == 'Tequatl'), isTrue);
    expect(alerts.first.body, 'soon · Sunken Coast');
  });

  test('an event that starts just after midnight is announced on the evening before', () {
    final alerts = planBossAlerts(
      pins: {eventKey(_maps[1], _maps[1].events[0])},
      lead: 15,
      body: _body,
      maps: _maps,
    );
    // 00:03 minus 15 minutes is 23:48
    expect(alerts.map((a) => a.minuteOfDay), [885, 1428]);
  });

  test('nothing pinned, no alerts; unknown pins are ignored', () {
    expect(planBossAlerts(pins: {}, lead: 10, body: _body, maps: _maps), isEmpty);
    expect(planBossAlerts(pins: {'nope/nothing'}, lead: 10, body: _body, maps: _maps), isEmpty);
  });

  test('alerts come sorted by time of day, then name', () {
    final alerts = planBossAlerts(
      pins: {for (final m in _maps) for (final e in m.events) eventKey(m, e)},
      lead: 10,
      body: _body,
      maps: _maps,
    );
    final minutes = alerts.map((a) => a.minuteOfDay).toList();
    expect(minutes, [...minutes]..sort());
    expect(alerts.length, 3 + 1 + 2);
  });

  test('ids are stable, and unique across every pinned event of the real schedule', () {
    expect(bossAlertId('a/b', 60), bossAlertId('a/b', 60));
    expect(bossAlertId('a/b', 60), isNot(bossAlertId('a/b', 61)));
    expect(bossAlertId('a/b', 60), isNot(bossAlertId('a/c', 60)));
    expect(bossAlertId('anything', 5), inInclusiveRange(0, 0x7fffffff));

    final all = {for (final m in metaMaps) for (final e in m.events) eventKey(m, e)};
    final alerts = planBossAlerts(pins: all, lead: 10, body: (m) => m.name);
    expect(alerts.map((a) => a.id).toSet().length, alerts.length);
    var starts = 0;
    for (final m in metaMaps) {
      for (final e in m.events) {
        starts += e.times.length;
      }
    }
    expect(alerts.length, starts);
    // the alarm system holds a few hundred alerts, the whole schedule must fit
    expect(alerts.length, lessThan(400));
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
    final pins = {eventKey(_maps[0], _maps[0].events[0])};
    final a = planBossAlerts(pins: pins, lead: 10, body: _body, maps: _maps);
    final same = planBossAlerts(pins: pins, lead: 10, body: _body, maps: _maps);
    expect(alertsSignature(a, exact: true), alertsSignature(same, exact: true));
    expect(alertsSignature(a, exact: true), isNot(alertsSignature(a, exact: false)));
    final other = planBossAlerts(pins: pins, lead: 15, body: _body, maps: _maps);
    expect(alertsSignature(a, exact: true), isNot(alertsSignature(other, exact: true)));
    final worded = planBossAlerts(pins: pins, lead: 10, body: (m) => 'in ${m.name}', maps: _maps);
    expect(alertsSignature(a, exact: true), isNot(alertsSignature(worded, exact: true)));
  });

  test('only the alerts payload opens the events', () {
    expect(isBossAlertPayload('world_events'), isTrue);
    expect(isBossAlertPayload('event'), isFalse);
    expect(isBossAlertPayload(null), isFalse);
  });
}
