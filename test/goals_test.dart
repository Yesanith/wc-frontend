import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tyria_codex/state/crafting.dart';
import 'package:tyria_codex/state/goals.dart';
import 'package:tyria_codex/state/settings.dart';

CraftNode node(int id, {int perRun = 1, int outputCount = 1, List<CraftNode> children = const []}) => CraftNode(
      itemId: id,
      item: {'name': 'Item $id'},
      perRun: perRun,
      outputCount: outputCount,
      children: children,
      disciplines: const [],
    );

Future<ProviderContainer> container([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('the list of goals', () {
    test('is kept on the device and read back', () async {
      final first = await container();
      await first.read(goalsProvider.notifier).add(10, 2);
      await first.read(goalsProvider.notifier).add(20, 1);
      final prefs = first.read(prefsProvider);
      expect(prefs.getStringList('goals'), ['10:2', '20:1']);

      final again = await container({
        'goals': ['10:2', '20:1']
      });
      expect(again.read(goalsProvider).map((g) => (g.itemId, g.quantity)), [(10, 2), (20, 1)]);
    });

    test('an item added twice asks for that many more', () async {
      final c = await container();
      await c.read(goalsProvider.notifier).add(10, 2);
      await c.read(goalsProvider.notifier).add(10, 3);
      expect(c.read(goalsProvider).single.quantity, 5);
    });

    test('keeps a quantity between one and the largest', () async {
      final c = await container();
      final goals = c.read(goalsProvider.notifier);
      await goals.add(10, 1);
      await goals.setQuantity(10, 0);
      expect(c.read(goalsProvider).single.quantity, 1);
      await goals.setQuantity(10, 100000);
      expect(c.read(goalsProvider).single.quantity, maxGoalQuantity);
    });

    test('removes and clears', () async {
      final c = await container();
      final goals = c.read(goalsProvider.notifier);
      await goals.add(10, 1);
      await goals.add(20, 1);
      await goals.remove(10);
      expect(c.read(goalsProvider).map((g) => g.itemId), [20]);
      await goals.clear();
      expect(c.read(goalsProvider), isEmpty);
    });

    test('stops at the most goals', () async {
      final c = await container();
      final goals = c.read(goalsProvider.notifier);
      for (var i = 1; i <= maxGoals + 5; i++) {
        await goals.add(i, 1);
      }
      expect(c.read(goalsProvider), hasLength(maxGoals));
    });

    test('ignores what it cannot read, and a repeated item', () async {
      final c = await container({
        'goals': ['10:2', 'nonsense', '0:3', '5:-1', '10:9', '7:4'],
      });
      expect(c.read(goalsProvider).map((g) => (g.itemId, g.quantity)), [(10, 2), (7, 4)]);
    });
  });

  group('planGoals', () {
    test('hands the stock out once across goals', () {
      // two goals each need one item 2, which is a craftable piece of item 3 and 4
      final piece = node(2, children: [node(9, perRun: 5)]);
      final a = node(1, children: [piece]);
      final b = node(3, children: [piece]);
      // one piece in the bank covers the first goal only
      final plans = planGoals([(a, 1), (b, 1)], {2: 1});
      expect(plans[0].children.single.isLeaf, isTrue, reason: 'covered by the stock');
      expect(plans[1].children.single.children.single.count, 5, reason: 'the second has to craft it');
    });
  });

  group('buildShoppingList', () {
    test('adds the same material of two goals together', () {
      final a = node(1, children: [node(5, perRun: 3)]);
      final b = node(2, children: [node(5, perRun: 2), node(6, perRun: 1)]);
      final plans = planGoals([(a, 2), (b, 1)], const {});
      final list = buildShoppingList(plans, const {}, const {});
      final need = {for (final r in list.rows) r.itemId: r.need};
      expect(need, {5: 8, 6: 1});
    });

    test('says what is missing and what it costs', () {
      final a = node(1, children: [node(5, perRun: 10), node(6, perRun: 4)]);
      final plans = planGoals([(a, 1)], const {5: 4, 6: 4});
      final list = buildShoppingList(plans, const {5: 4, 6: 4}, const {5: 100, 6: 50});
      final five = list.rows.firstWhere((r) => r.itemId == 5);
      expect(five.missing, 6);
      expect(five.missingCost, 600);
      expect(list.missingCost, 600);
      // owned and counted: 4 of item 5 (400) and the 4 of item 6 that are all that is needed (200)
      expect(list.ownedValue, 600);
    });

    test('puts what is missing first, the dearest first, and what is done last', () {
      final a = node(1, children: [node(5, perRun: 1), node(6, perRun: 5), node(7, perRun: 2)]);
      final plans = planGoals([(a, 1)], const {});
      final list = buildShoppingList(plans, const {5: 1}, const {5: 10, 6: 100, 7: 100});
      expect(list.rows.map((r) => r.itemId), [6, 7, 5]);
    });

    test('counts materials with no price, and is complete when all are in hand', () {
      final a = node(1, children: [node(5, perRun: 2)]);
      final plans = planGoals([(a, 1)], const {});
      expect(buildShoppingList(plans, const {}, const {}).unpriced, 1);
      final done = buildShoppingList(plans, const {5: 2}, const {});
      expect(done.complete, isTrue);
      expect(done.unpriced, 0);
    });
  });
}
