import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/data/metas.dart';

void main() {
  // three maps: an event of 15 minutes every hour on the hour, one of 15 at a quarter past, one of 30 at ten past
  final a = MetaMap('a', 'A', Expansion.core, [
    MetaEvent('A', [for (var h = 0; h < 24; h++) h * 60])
  ]);
  final b = MetaMap('b', 'B', Expansion.core, [
    MetaEvent('B', [for (var h = 0; h < 24; h++) h * 60 + 15])
  ]);
  final c = MetaMap('c', 'C', Expansion.core, [
    MetaEvent('C', [for (var h = 0; h < 24; h++) h * 60 + 10], minutes: 30)
  ]);
  final now = DateTime.utc(2026, 11, 27, 12, 0);

  test('one after another, the earliest to end first, with time to travel', () {
    final train = planTrain(now, const Duration(hours: 1), maps: [a, b, c]);
    // A 12:00-12:15, then B can't start at 12:15 (2 minutes to travel), C overlaps: the hour has A only, B at 13:15 is outside
    expect(train.map((o) => o.event.name), ['A']);
  });

  test('without time to travel the next one is taken', () {
    final train = planTrain(now, const Duration(hours: 1), maps: [a, b, c], gap: Duration.zero);
    expect(train.map((o) => o.event.name), ['A', 'B']);
  });

  test('nothing overlaps, and everything ends within the window', () {
    final train = planTrain(now, const Duration(hours: 3), maps: [a, b, c]);
    for (var i = 1; i < train.length; i++) {
      expect(train[i].start.isBefore(train[i - 1].end), isFalse);
    }
    expect(train.every((o) => !o.end.isAfter(now.add(const Duration(hours: 3)))), isTrue);
    expect(train.length, 3, reason: 'A at each hour');
  });

  test('what is left out is left out', () {
    final train = planTrain(now, const Duration(hours: 1),
        maps: [a, b, c], where: (o) => o.event.name != 'A', gap: Duration.zero);
    // B (12:15-12:30) and C (12:10-12:40) overlap: the one that ends first is taken
    expect(train.map((o) => o.event.name), ['B']);
  });
}
