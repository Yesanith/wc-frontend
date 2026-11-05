import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/api/gw2_api.dart';
import 'package:wondrous_compass/util.dart';

void main() {
  test('the daily reset is midnight utc', () {
    expect(lastDailyReset(DateTime.utc(2026, 9, 29, 13, 5)), DateTime.utc(2026, 9, 29));
    expect(lastDailyReset(DateTime.utc(2026, 9, 29)), DateTime.utc(2026, 9, 29));
  });

  test('the weekly reset is monday 07:30 utc', () {
    // tuesday: the day before at 07:30
    expect(lastWeeklyReset(DateTime.utc(2026, 9, 29, 12)), DateTime.utc(2026, 9, 28, 7, 30));
    // monday before 07:30 still belongs to the previous week
    expect(lastWeeklyReset(DateTime.utc(2026, 9, 28, 7, 29)), DateTime.utc(2026, 9, 21, 7, 30));
    expect(lastWeeklyReset(DateTime.utc(2026, 9, 28, 7, 30)), DateTime.utc(2026, 9, 28, 7, 30));
  });

  test('the next reset is whichever comes first', () {
    // sunday evening: the daily one at midnight
    expect(nextResetAfter(DateTime.utc(2026, 9, 27, 22)), DateTime.utc(2026, 9, 28));
    // monday 03:00: the weekly one at 07:30 comes before the next midnight
    expect(nextResetAfter(DateTime.utc(2026, 9, 28, 3)), DateTime.utc(2026, 9, 28, 7, 30));
  });

  test('a cached copy may not reach back past the last reset', () {
    final now = DateTime.utc(2026, 9, 29, 0, 10);
    // ten minutes after midnight, a copy from 23:55 is from yesterday
    expect(copyMaxAge(lastDailyReset(now), now), const Duration(minutes: 10));
    // without a reset the usual week
    expect(copyMaxAge(null, now), const Duration(days: 7));
    // a reset long ago is capped at a week too
    expect(copyMaxAge(DateTime.utc(2026, 1, 1), now), const Duration(days: 7));
  });
}
