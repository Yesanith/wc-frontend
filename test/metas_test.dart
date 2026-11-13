import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:wondrous_compass/data/metas.dart';
import 'package:wondrous_compass/data/waypoints.dart';
import 'package:wondrous_compass/screens/events_screen.dart';
import 'package:wondrous_compass/screens/item_detail_screen.dart';
import 'package:wondrous_compass/state/clock.dart';

void main() {
  timersAndPrices();

  test('every start time is inside the day and every map id is unique', () {
    final ids = <String>{};
    for (final m in metaMaps) {
      expect(ids.add(m.id), isTrue, reason: m.id);
      expect(m.events, isNotEmpty);
      for (final e in m.events) {
        expect(e.times, isNotEmpty, reason: e.name);
        for (final t in e.times) {
          expect(t, inInclusiveRange(0, 1439), reason: e.name);
        }
        expect(e.minutes, greaterThan(0));
      }
    }
  });

  test('every event has a waypoint whose chat code is a waypoint link', () {
    for (final m in metaMaps) {
      for (final e in m.events) {
        final w = waypointFor(m, e);
        expect(w, isNotNull, reason: '${m.id}/${e.name}');
        expect(w!.name, endsWith('Waypoint'), reason: w.name);
        final match = RegExp(r'^\[&([A-Za-z0-9+/]+=*)\]$').firstMatch(w.code);
        expect(match, isNotNull, reason: w.code);
        final bytes = base64.decode(match!.group(1)!);
        // a link to a point of interest is type 4 and its id in four bytes after it
        expect(bytes, hasLength(5), reason: w.code);
        expect(bytes.first, 4, reason: w.code);
      }
    }
  });

  test('the fractal incursion is one hour in four on each of its maps, one after the other, from midnight', () {
    final map = metaMaps.firstWhere((m) => m.id == 'incursion');
    final names = [for (final e in map.events) e.name];
    expect(names, ['Kessex Hills', 'Diessa Plateau', 'Brisban Wildlands', 'Snowden Drifts']);
    final from = DateTime.utc(2026, 11, 14);
    final runs = occurrences(from, from.add(const Duration(hours: 8)), maps: [map]);
    expect([
      for (final o in runs) '${o.start.hour}:${o.event.name}'
    ], [
      '0:Kessex Hills',
      '1:Diessa Plateau',
      '2:Brisban Wildlands',
      '3:Snowden Drifts',
      '4:Kessex Hills',
      '5:Diessa Plateau',
      '6:Brisban Wildlands',
      '7:Snowden Drifts',
    ]);
    expect(waypointFor(map, map.events[1])!.code, '[&BN0AAAA=]');
    expect(map.events.first.wiki, fractalIncursionPage);
  });

  test('core bosses keep their classic rotation', () {
    final behemoth = metaMaps.firstWhere((m) => m.id == 'queensdale').events.single;
    expect(behemoth.times.first, 105);
    expect(behemoth.times, hasLength(12));
    expect(behemoth.bossId, 'shadow_behemoth');
  });

  test('occurrences overlap the window and come sorted', () {
    final from = DateTime.utc(2026, 9, 27, 23, 0);
    final to = from.add(const Duration(hours: 3));
    final list = occurrences(from, to);
    expect(list, isNotEmpty);
    for (var i = 1; i < list.length; i++) {
      expect(list[i].start.isBefore(list[i - 1].start), isFalse);
    }
    for (final o in list) {
      expect(o.end.isAfter(from), isTrue);
      expect(o.start.isBefore(to), isTrue);
    }
    // runs past midnight belong to the next day
    expect(list.any((o) => o.start.day == 28), isTrue);
  });

  test('a running event is listed first and is active', () {
    // shadow behemoth spawns at 01:45 utc
    final now = DateTime.utc(2026, 9, 27, 1, 50);
    final list = upNext(now, count: 50, where: (o) => o.map.id == 'queensdale');
    expect(list.first.start, DateTime.utc(2026, 9, 27, 1, 45));
    expect(list.first.activeAt(now), isTrue);
    expect(list[1].activeAt(now), isFalse);
  });
}

void timersAndPrices() {
  test('a looted boss counts only until the daily reset', () {
    final map = metaMaps.firstWhere((m) => m.id == 'queensdale');
    final now = DateTime.utc(2026, 9, 27, 20);
    final today = Occurrence(map, map.events.single, DateTime.utc(2026, 9, 27, 21, 45));
    final tomorrow = Occurrence(map, map.events.single, DateTime.utc(2026, 9, 28, 1, 45));
    expect(lootedRun(today, {'shadow_behemoth'}, now), isTrue);
    expect(lootedRun(tomorrow, {'shadow_behemoth'}, now), isFalse);
    expect(lootedRun(today, const {}, now), isFalse);
  });

  test('pins use the boss id or the map and event name', () {
    final queensdale = metaMaps.firstWhere((m) => m.id == 'queensdale');
    final drytop = metaMaps.firstWhere((m) => m.id == 'drytop');
    expect(eventKey(queensdale, queensdale.events.single), 'shadow_behemoth');
    expect(eventKey(drytop, drytop.events.first), 'drytop/Crash Site');
  });

  test('trading post fees and the reset clocks', () {
    expect(afterTradingFees(100), 85);
    expect(afterTradingFees(1000), 850);
    expect(countdown(const Duration(days: 2, hours: 4)), '2d 04h');
    expect(countdown(const Duration(hours: 3, minutes: 5)), '3h 05m');
    expect(countdown(const Duration(minutes: 12, seconds: 7)), '12:07');
    expect(weekProgress(DateTime.utc(2026, 9, 28, 7, 30)), closeTo(0, 1e-9));
    expect(weekProgress(DateTime.utc(2026, 10, 1, 19, 30)), closeTo(0.5, 1e-9));
    expect(dayProgress(DateTime.utc(2026, 1, 1, 12)), closeTo(0.5, 1e-9));
  });
}
