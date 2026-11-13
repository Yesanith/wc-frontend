import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/account.dart';
import 'package:wondrous_compass/state/period_refresh.dart';
import 'package:wondrous_compass/widgets/stale_note.dart';

void main() {
  group('the account in the api', () {
    final now = DateTime.utc(2026, 11, 9, 9, 8); // a monday, after both resets

    test('is from before the daily reset when the game last sent it the evening before', () {
      final updated = accountUpdatedAt({'last_modified': '2026-11-08T21:56:00Z'});
      expect(updated, DateTime.utc(2026, 11, 8, 21, 56));
      expect(updatedBeforeReset(updated, weekly: false, now: now), isTrue);
      expect(updatedBeforeReset(updated, weekly: true, now: now), isTrue);
    });

    test('is current once the game sent it after the reset', () {
      final updated = accountUpdatedAt({'last_modified': '2026-11-09T08:00:00Z'});
      expect(updatedBeforeReset(updated, weekly: false, now: now), isFalse);
      expect(updatedBeforeReset(updated, weekly: true, now: now), isFalse);
    });

    test('is between the resets when sent after the daily one and before the weekly one', () {
      final updated = accountUpdatedAt({'last_modified': '2026-11-09T03:00:00Z'});
      expect(updatedBeforeReset(updated, weekly: false, now: now), isFalse);
      expect(updatedBeforeReset(updated, weekly: true, now: now), isTrue);
    });

    test('says nothing without a date', () {
      expect(accountUpdatedAt(null), isNull);
      expect(updatedBeforeReset(accountUpdatedAt({}), weekly: false, now: now), isFalse);
    });
  });

  group('the data that resets is read again', () {
    test('twenty seconds, three and ten minutes after the daily reset', () {
      expect(nextRefreshAt(DateTime.utc(2026, 11, 9, 0, 0, 5)), DateTime.utc(2026, 11, 9, 0, 0, 20));
      expect(nextRefreshAt(DateTime.utc(2026, 11, 9, 0, 1)), DateTime.utc(2026, 11, 9, 0, 3));
      expect(nextRefreshAt(DateTime.utc(2026, 11, 9, 0, 5)), DateTime.utc(2026, 11, 9, 0, 10));
    });

    test('and after the weekly one, then at the next reset', () {
      expect(nextRefreshAt(DateTime.utc(2026, 11, 9, 7, 31)), DateTime.utc(2026, 11, 9, 7, 33));
      expect(nextRefreshAt(DateTime.utc(2026, 11, 9, 9)), DateTime.utc(2026, 11, 10, 0, 0, 20));
    });
  });

  group('the vault waits for the login', () {
    ProviderContainer withAccount(String lastModified) {
      final c = ProviderContainer(overrides: [
        accountProvider.overrideWith((ref) async => {'name': 'Leo.1234', 'last_modified': lastModified}),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('while the game has not sent the account since the reset, and never for the special track', () async {
      final c = withAccount(DateTime.now().toUtc().subtract(const Duration(days: 8)).toIso8601String());
      await c.read(accountProvider.future);
      expect(c.read(vaultStaleProvider('daily')), isTrue);
      expect(c.read(vaultStaleProvider('weekly')), isTrue);
      expect(c.read(vaultStaleProvider('special')), isFalse);
    });

    test('not once it has', () async {
      final c = withAccount(DateTime.now().toUtc().toIso8601String());
      await c.read(accountProvider.future);
      expect(c.read(vaultStaleProvider('daily')), isFalse);
      expect(c.read(vaultStaleProvider('weekly')), isFalse);
    });
  });
}
