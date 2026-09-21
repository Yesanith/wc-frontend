import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/crafting.dart';

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
}
