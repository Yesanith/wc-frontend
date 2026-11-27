import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/crafting.dart';
import 'package:wondrous_compass/state/legendary_proximity.dart';

CraftNode leaf(int id, int perRun) =>
    CraftNode(itemId: id, item: null, perRun: perRun, outputCount: 1, children: const [], disciplines: const []);

void main() {
  // a legendary of two gifts: one made of 100 of item 2 and 50 of item 3, the other of 1 item 4 the trading post does not sell
  final root = CraftNode(
    itemId: 1,
    item: null,
    perRun: 1,
    outputCount: 1,
    disciplines: const [],
    children: [
      CraftNode(
        itemId: 10,
        item: null,
        perRun: 1,
        outputCount: 1,
        disciplines: const [],
        children: [leaf(2, 100), leaf(3, 50)],
      ),
      leaf(4, 1),
    ],
  );
  const prices = {2: 100, 3: 1000};

  test('what is still to buy, what it is worth in all, and what the trading post does not sell', () {
    final d = distanceTo(root, {2: 60}, prices);
    expect(d.missingCost, 40 * 100 + 50 * 1000);
    expect(d.totalValue, 100 * 100 + 50 * 1000);
    expect(d.unpricedMissing, 1);
    expect(d.progress, closeTo(6000 / 60000, 1e-9));
  });

  test('a part the account already has takes its materials out of the reckoning', () {
    final d = distanceTo(root, {10: 1, 4: 1}, prices);
    expect(d.missingCost, 0);
    expect(d.unpricedMissing, 0);
    expect(d.progress, 1, reason: 'all of it is in hand');
  });
}
