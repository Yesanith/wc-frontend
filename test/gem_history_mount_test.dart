import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/collections.dart';
import 'package:tyria_codex/state/gem_history.dart';

void main() {
  group('gem history', () {
    test('reads the recorded points', () {
      final points = parseGemHistory('{"points":[[1800000000,300000,200000],["bad"],[1800003600,310000,205000]]}');
      expect(points.length, 2);
      expect(points.first.at, DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000, isUtc: true));
      expect(points.last.buy, 310000);
      expect(parseGemHistory('[]'), isEmpty);
    });

    test('the cost of 100 gems follows from gems per 100 gold', () {
      // 100 gold buys 250 gems, so a gem costs 0.4 gold and 100 gems 40 gold
      expect(buyFor100Gems(250), 400000);
      expect(buyFor100Gems(0), 0);
    });

    test('merging keeps one point per hour inside the window', () {
      final now = DateTime.utc(2026, 9, 28, 12);
      final shared = [
        GemPoint(now.subtract(const Duration(days: 40)), 1, 1),
        GemPoint(DateTime.utc(2026, 9, 28, 10, 5), 300000, 200000),
      ];
      final local = [
        GemPoint(DateTime.utc(2026, 9, 28, 10, 40), 301000, 201000),
        GemPoint(DateTime.utc(2026, 9, 28, 11, 10), 302000, 202000),
      ];
      final merged = mergeGemPoints(shared, local, now: now);
      expect(merged.map((p) => p.buy), [301000, 302000]);
    });
  });

  group('mount of a skin', () {
    const names = {'raptor': 'Raptor', 'B3461B6A-FBB5-4777-8C0B-A44597FC7D23': 'Raptor'};

    test('reads the guid newer schemas send', () {
      expect(mountOf({'mount_guid': 'b3461b6a-fbb5-4777-8c0b-a44597fc7d23'}, names), 'Raptor');
    });

    test('falls back to the old mount key', () {
      expect(mountOf({'mount': 'raptor'}, names), 'Raptor');
      expect(mountOf({'mount': 'skyscale'}, names), 'Skyscale');
      expect(mountOf({'name': 'no mount'}, names), isNull);
    });
  });
}
