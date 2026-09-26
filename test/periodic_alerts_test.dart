import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/alerts.dart';
import 'package:tyria_codex/state/periodic.dart';
import 'package:tyria_codex/state/wealth.dart';

void main() {
  group('resets', () {
    test('daily reset is the next utc midnight', () {
      expect(nextDailyReset(DateTime.utc(2026, 9, 25, 23, 59)), DateTime.utc(2026, 9, 26));
      expect(nextDailyReset(DateTime.utc(2026, 12, 31, 8)), DateTime.utc(2027, 1, 1));
    });

    test('weekly reset is the next monday 07:30 utc', () {
      // 2026-09-25 is a friday
      expect(nextWeeklyReset(DateTime.utc(2026, 9, 25, 12)), DateTime.utc(2026, 9, 28, 7, 30));
      // monday before the reset: the same day
      expect(nextWeeklyReset(DateTime.utc(2026, 9, 28, 7)), DateTime.utc(2026, 9, 28, 7, 30));
      // monday after the reset: next week
      expect(nextWeeklyReset(DateTime.utc(2026, 9, 28, 8)), DateTime.utc(2026, 10, 5, 7, 30));
    });

    test('time left reads like a clock', () {
      final now = DateTime.utc(2026, 9, 25, 10);
      expect(timeUntil(DateTime.utc(2026, 9, 25, 10, 45), now: now), '45m');
      expect(timeUntil(DateTime.utc(2026, 9, 25, 15, 12), now: now), '5h 12m');
      expect(timeUntil(DateTime.utc(2026, 9, 28, 7, 30), now: now), '2d 21h');
      expect(timeUntil(DateTime.utc(2026, 9, 25, 9), now: now), '0m');
    });
  });

  test('daily entries follow expansion access', () {
    const access = {'GuildWars2', 'HeartOfThorns'};
    expect(entryApplies({'id': 1}, access), isTrue);
    expect(entryApplies({'required_access': {'product': 'HeartOfThorns', 'condition': 'HasAccess'}}, access), isTrue);
    expect(entryApplies({'required_access': {'product': 'PathOfFire', 'condition': 'HasAccess'}}, access), isFalse);
    expect(entryApplies({'required_access': {'product': 'PathOfFire', 'condition': 'NoAccess'}}, access), isTrue);
  });

  group('price alerts', () {
    test('fire on either side', () {
      const alert = PriceAlert(sellBelow: 10000, buyAbove: 20000);
      expect(alert.triggeredBy(sell: 9000, buy: 0), isTrue);
      expect(alert.triggeredBy(sell: 15000, buy: 21000), isTrue);
      expect(alert.triggeredBy(sell: 15000, buy: 19000), isFalse);
    });

    test('an empty listing never counts as cheap', () {
      expect(const PriceAlert(sellBelow: 10000).triggeredBy(sell: 0, buy: 0), isFalse);
    });

    test('gold input converts both ways', () {
      expect(goldToCopper('1.5'), 15000);
      expect(goldToCopper('0,25'), 2500);
      expect(goldToCopper(''), isNull);
      expect(goldToCopper('-3'), isNull);
      expect(copperToGold(15000), '1.5');
      expect(copperToGold(1000000), '100');
      expect(copperToGold(123), '0.0123');
    });
  });

  test('wealth change looks back the given number of days', () {
    const points = [
      WealthPoint('2026-09-01', 1000, 0, 0),
      WealthPoint('2026-09-18', 5000, 0, 0),
      WealthPoint('2026-09-25', 8000, 0, 0),
    ];
    expect(changeOver(points, 7, (p) => p.coins), 3000);
    expect(changeOver(points, 30, (p) => p.coins), 7000);
    expect(changeOver(points.sublist(2), 7, (p) => p.coins), isNull);
  });
}
