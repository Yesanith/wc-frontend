import 'package:flutter_test/flutter_test.dart';
import 'package:wondrous_compass/state/crafting.dart';

CraftNode node(
  int id, {
  int perRun = 1,
  int outputCount = 1,
  List<CraftNode> children = const [],
}) =>
    CraftNode(
      itemId: id,
      item: {'name': 'Item $id'},
      perRun: perRun,
      outputCount: outputCount,
      children: children,
      disciplines: const [],
    );

void main() {
  group('planFor', () {
    test('a leaf just carries the requested count', () {
      final plan = planFor(node(1), 7);
      expect(plan.count, 7);
      expect(plan.isLeaf, isTrue);
    });

    test('scales ingredients by how many runs the recipe needs', () {
      // one run makes 2 and costs 3 of item 2
      final root = node(1, outputCount: 2, children: [node(2, perRun: 3)]);
      final plan = planFor(root, 4);
      expect(plan.children.single.count, 6);
    });

    test('rounds runs up, so a partial craft still buys a whole run', () {
      final root = node(1, outputCount: 2, children: [node(2, perRun: 3)]);
      // 5 wanted -> 3 runs -> 9 ingredients
      expect(planFor(root, 5).children.single.count, 9);
    });

    test('treats a non positive output as one per run', () {
      final root = node(1, outputCount: 0, children: [node(2, perRun: 2)]);
      expect(planFor(root, 3).children.single.count, 6);
    });

    test('scales through nested recipes', () {
      final root = node(1, outputCount: 1, children: [
        node(2, perRun: 2, outputCount: 1, children: [node(3, perRun: 5)]),
      ]);
      final plan = planFor(root, 2);
      expect(plan.children.single.count, 4);
      expect(plan.children.single.children.single.count, 20);
    });
  });

  group('craftLeaves', () {
    test('collects the bottom of the tree and skips the root', () {
      final root = node(1, children: [node(2, perRun: 3), node(3, perRun: 1)]);
      expect(craftLeaves(planFor(root, 1)), {2: 3, 3: 1});
    });

    test('sums an ingredient that appears in two branches', () {
      final root = node(1, children: [
        node(2, perRun: 1, children: [node(9, perRun: 2)]),
        node(3, perRun: 1, children: [node(9, perRun: 5)]),
      ]);
      expect(craftLeaves(planFor(root, 1)), {9: 7});
    });

    test('a root with no recipe has no leaves', () {
      expect(craftLeaves(planFor(node(1), 3)), isEmpty);
    });
  });

  group('planWithStock', () {
    // item 1 is crafted from two of gift 2, each gift from 5 of ore 3
    CraftNode tree() => node(1, children: [
          node(2, perRun: 2, children: [node(3, perRun: 5)]),
        ]);

    test('without stock it is the plain plan', () {
      final plan = planWithStock(tree(), 1, const {});
      expect(craftLeaves(plan), {3: 10});
    });

    test('an owned intermediate covers its branch entirely', () {
      final plan = planWithStock(tree(), 1, const {2: 2});
      final gift = plan.children.single;
      expect(gift.count, 2);
      expect(gift.isLeaf, isTrue);
      // the ore is no longer needed, the gifts stand in for it
      expect(craftLeaves(plan), {2: 2});
    });

    test('a partly owned intermediate only crafts the rest', () {
      final plan = planWithStock(tree(), 1, const {2: 1});
      expect(craftLeaves(plan), {3: 5});
    });

    test('stock is handed out once, not to every branch that asks', () {
      // two branches both want one of gift 2, the bank holds one
      final root = node(1, children: [
        node(4, children: [
          node(2, children: [node(3, perRun: 5)])
        ]),
        node(5, children: [
          node(2, children: [node(3, perRun: 5)])
        ]),
      ]);
      final plan = planWithStock(root, 1, const {2: 1});
      expect(craftLeaves(plan), {2: 1, 3: 5});
    });

    test('the root is crafted even when some are in the bank', () {
      final plan = planWithStock(tree(), 1, const {1: 3});
      expect(craftLeaves(plan), {3: 10});
    });

    test('raw materials keep their full count', () {
      final plan = planWithStock(tree(), 1, const {3: 4});
      expect(craftLeaves(plan), {3: 10});
    });
  });
}
