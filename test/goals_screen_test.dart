import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tyria_codex/screens/goals_screen.dart';
import 'package:tyria_codex/state/account.dart';
import 'package:tyria_codex/state/crafting.dart';
import 'package:tyria_codex/state/goals.dart';
import 'package:tyria_codex/state/items.dart';
import 'package:tyria_codex/state/reference.dart';
import 'package:tyria_codex/state/settings.dart';
import 'package:tyria_codex/theme.dart';

CraftNode node(int id, {int perRun = 1, List<CraftNode> children = const []}) => CraftNode(
      itemId: id,
      item: {'name': 'Item $id'},
      perRun: perRun,
      outputCount: 1,
      children: children,
      disciplines: const [],
    );

void main() {
  Future<ProviderContainer> show(
    WidgetTester tester, {
    required List<String> goals,
    Map<int, int> owned = const {},
  }) async {
    SharedPreferences.setMockInitialValues({'goals': goals});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          itemProvider.overrideWith((ref, id) async => {'name': 'Item $id'}),
          quaggansProvider.overrideWith((ref) async => const <String>[]),
          accountTotalsProvider.overrideWith((ref) async => owned),
          goalPricesProvider.overrideWith((ref) async => const {5: 100}),
          // every goal is an item made of 3 of item 5
          goalTreesProvider.overrideWith((ref) async {
            return [
              for (final g in ref.watch(goalsProvider)) (g, node(g.itemId, children: [node(5, perRun: 3)])),
            ];
          }),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(theme: buildTheme(), home: const GoalsScreen());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('says what to do when there are no goals', (tester) async {
    await show(tester, goals: const []);
    expect(find.text('My goals'), findsOneWidget);
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
    expect(find.text('Shopping list'), findsNothing);
  });

  testWidgets('lists the goals and the materials they take', (tester) async {
    await show(tester, goals: const ['10:2']);
    expect(find.text('Item 10'), findsOneWidget);
    // 2 of the goal, 3 of the material each
    expect(find.text('Shopping list'), findsOneWidget);
    expect(find.text('Item 5'), findsOneWidget);
    expect(find.text('0 / 6'), findsOneWidget);
    expect(find.text('Missing materials cost'), findsOneWidget);
  });

  testWidgets('says so when everything is in hand', (tester) async {
    await show(tester, goals: const ['10:1'], owned: const {5: 3});
    expect(find.text('You have everything for your goals.'), findsOneWidget);
    expect(find.text('Missing materials cost'), findsNothing);
  });

  testWidgets('a goal is taken off with its cross', (tester) async {
    final container = await show(tester, goals: const ['10:1', '20:1']);
    expect(container.read(goalsProvider), hasLength(2));
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(container.read(goalsProvider).map((g) => g.itemId), [20]);
  });

  testWidgets('the plus and the minus change how many', (tester) async {
    final container = await show(tester, goals: const ['10:2']);
    await tester.tap(find.byTooltip('+'));
    await tester.pumpAndSettle();
    expect(container.read(goalsProvider).single.quantity, 3);
    await tester.tap(find.byTooltip('-'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('-'));
    await tester.pumpAndSettle();
    expect(container.read(goalsProvider).single.quantity, 1);
    // never below one
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove_circle_outline)).onPressed, isNull);
  });
}
