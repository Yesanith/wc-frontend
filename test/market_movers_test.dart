import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/market_movers.dart';

void main() {
  test('what rose and what fell, read from the answer of the server', () {
    final m = parseMarketMovers({
      'days': 1,
      'updated_at': '2026-11-27T12:00:00Z',
      'risers': [
        {'item_id': 11, 'sell': 1200, 'before': 1000, 'change': 0.2},
      ],
      'fallers': [
        {'item_id': 12, 'sell': 500, 'before': 1000, 'change': -0.5},
        {'item_id': 0, 'sell': 1, 'before': 1, 'change': 0},
      ],
    });
    expect(m.risers.single.itemId, 11);
    expect(m.risers.single.change, 0.2);
    expect(m.fallers.single.before, 1000, reason: 'a row without an item is left out');
    expect(m.updatedAt, DateTime.utc(2026, 11, 27, 12));
  });

  test('an answer that is not one is nothing', () {
    expect(parseMarketMovers(null).isEmpty, isTrue);
    expect(parseMarketMovers({'risers': 'x'}).isEmpty, isTrue);
  });
}
