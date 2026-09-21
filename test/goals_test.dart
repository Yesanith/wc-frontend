import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/goals.dart';
import 'package:tyria_codex/state/settings.dart';

void main() {
  final goals = [
    const Goal('g1', 'Twilight', [GoalItem(1, 10), GoalItem(2, 5)]),
    const Goal('g2', 'Sunrise', [GoalItem(3, 2)]),
  ];

  group('missingForGoal', () {
    test('subtracts what the account already owns', () {
      expect(missingForGoal(goals, 'g1', {1: 4}), {1: 6, 2: 5});
    });

    test('drops items that are already covered', () {
      expect(missingForGoal(goals, 'g1', {1: 10, 2: 3}), {2: 2});
    });

    test('counts a surplus as covered rather than negative', () {
      expect(missingForGoal(goals, 'g2', {3: 99}), isEmpty);
    });

    test('a complete goal has nothing missing', () {
      expect(missingForGoal(goals, 'g1', {1: 10, 2: 5}), isEmpty);
    });

    test('an unknown goal id yields nothing', () {
      expect(missingForGoal(goals, 'nope', {1: 0}), isEmpty);
    });

    test('a goal without items yields nothing', () {
      expect(missingForGoal([const Goal('g3', 'Empty', [])], 'g3', const {}), isEmpty);
    });
  });
}
