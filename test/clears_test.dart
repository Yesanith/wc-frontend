import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/clears.dart';

void main() {
  test('the counts of each account are read, kinds the server left out are 0', () {
    final all = parseClearCounts([
      {
        'account_id': 'a',
        'account_name': 'Leo.1234',
        'status': 'on',
        'since': '2026-11-27T10:00:00Z',
        'expires_at': '2026-12-27T10:00:00Z',
        'total': {'raid': 12, 'meta': 30},
        'week': {'raid': 3},
      },
      {'account_name': 'no id'},
    ]);
    expect(all, hasLength(1));
    expect(all.first.total['raid'], 12);
    expect(all.first.total['fractal'], 0);
    expect(all.first.week['meta'], 0);
    expect(clearsOf(all, 'leo.1234'), same(all.first));
    expect(clearsOf(all, 'Mira.5678'), isNull);
  });

  test('a subtoken is renewed when it runs out soon or was turned down, not when the count was stopped', () {
    final now = DateTime.utc(2026, 11, 27);
    ClearCounts c(String status, DateTime? expires) => ClearCounts(
        accountId: 'a', accountName: 'x', status: status, total: const {}, week: const {}, expiresAt: expires);
    expect(c('on', now.add(const Duration(days: 25))).renewalDue(now), isFalse);
    expect(c('on', now.add(const Duration(days: 5))).renewalDue(now), isTrue);
    expect(c('refused', null).renewalDue(now), isTrue);
    expect(c('off', null).renewalDue(now), isFalse);
  });

  test('the legendaries of the armory: kinds and all of them', () {
    final l = legendaryCount([
      {'id': 1, 'count': 2},
      {'id': 2, 'count': 1},
      {'id': 3},
    ]);
    expect(l.kinds, 3);
    expect(l.total, 4);
  });

  test('the progression is what the key needs', () {
    expect(canCountClears(['account', 'progression']), isTrue);
    expect(canCountClears(['account']), isFalse);
  });
}
