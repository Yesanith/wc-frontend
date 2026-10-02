import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/services/item_index.dart';
import 'package:tyria_codex/state/navigation.dart';
import 'package:tyria_codex/theme.dart';
import 'package:tyria_codex/widgets/site_search.dart';

void main() {
  final index = ItemIndex([
    IndexedItem(1, 'Greatsword of Fire'),
    IndexedItem(2, 'Great Mace'),
    IndexedItem(3, 'Mighty Greatbow'),
    IndexedItem(4, 'Greater Rune'),
    IndexedItem(5, 'Dagger'),
    IndexedItem(6, 'Trading Post Voucher'),
  ]);
  final labels = {for (final sec in AppSection.values) sec: 'S-${sec.name}'};
  const wiki = 'Search the wiki for “{q}”';

  List<SearchHit> hits(String q, {Map<AppSection, String>? withLabels, int itemLimit = 6, int sectionLimit = 3}) =>
      searchHits(q, index: index, labels: withLabels ?? labels, wikiLabel: wiki, itemLimit: itemLimit, sectionLimit: sectionLimit);

  group('what a search finds', () {
    test('is nothing for less than two letters: it would be every item there is', () {
      expect(hits(''), isEmpty);
      expect(hits(' '), isEmpty);
      expect(hits('g'), isEmpty);
      expect(hits(' g '), isEmpty);
    });

    test('has the items whose name has it, the ones that begin with it first, and the wiki last', () {
      final found = hits('great');
      // the ones that begin with it in the order of the index, then the one that only has it
      expect(found.where((h) => h.kind == SearchKind.item).map((h) => h.label), [
        'Greatsword of Fire',
        'Great Mace',
        'Greater Rune',
        'Mighty Greatbow',
      ]);
      expect(found.last.kind, SearchKind.wiki);
      expect(found.last.label, 'Search the wiki for “great”');
      expect(found.last.query, 'great');
    });

    test('has the wiki even when nothing else is found, so a search is never a dead end', () {
      final found = hits('zzzz');
      expect(found.length, 1);
      expect(found.single.kind, SearchKind.wiki);
      expect(found.single.label, 'Search the wiki for “zzzz”');
    });

    test('has the pages whose name has it, before the items', () {
      final found = hits('trad');
      expect(found.first.kind, SearchKind.section);
      expect(found.first.section, AppSection.trading);
      expect(found.first.label, 'S-trading');
      expect(found.map((h) => h.kind), [SearchKind.section, SearchKind.item, SearchKind.wiki], reason: 'a page, an item, the wiki');
      expect(found[1].label, 'Trading Post Voucher');
    });

    test('has the pages that begin with it before the ones that only have it, and no more than a few', () {
      final named = {
        AppSection.wvw: 'World vs World',
        AppSection.maps: 'World map',
        AppSection.bosses: 'World bosses',
        AppSection.news: 'Newsworld',
        AppSection.daily: 'Daily',
      };
      final found = hits('world', withLabels: named);
      final pages = found.where((h) => h.kind == SearchKind.section).toList();
      expect(pages.length, 3, reason: 'no more than a few');
      expect(pages.map((h) => h.section), [AppSection.bosses, AppSection.maps, AppSection.wvw], reason: 'in the order of the menu, those that begin with it');
      expect(found.any((h) => h.label == 'Newsworld'), isFalse);
    });

    test('has no more items than it is asked for, and none that is not in the index', () {
      expect(hits('great', itemLimit: 2).where((h) => h.kind == SearchKind.item).length, 2);
      expect(hits('great', itemLimit: 0).where((h) => h.kind == SearchKind.item), isEmpty);
      expect(searchHits('great', index: ItemIndex.empty, labels: labels, wikiLabel: wiki).map((h) => h.kind), [SearchKind.wiki]);
    });

    test('is the same for capitals, and takes what was typed as it was typed for the wiki', () {
      expect(hits('GREATSWORD').any((h) => h.kind == SearchKind.item && h.itemId == 1), isTrue);
      expect(hits('  Great Mace  ').last.query, 'Great Mace');
    });

    test('says which item it is by its id, and which page by the page', () {
      expect(hits('dagger').firstWhere((h) => h.kind == SearchKind.item).itemId, 5);
      expect(hits('S-daily').first.section, AppSection.daily);
    });
  });

  group('the box of the search', () {
    Future<List<SearchHit>> show(WidgetTester tester, {List<SearchHit>? chosen}) async {
      final picked = chosen ?? <SearchHit>[];
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [itemIndexProvider.overrideWith((ref) async => index)],
        child: MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(40),
              child: Align(
                alignment: Alignment.topLeft,
                child: SiteSearch(
                  labels: labels,
                  placeholder: 'Search items and pages',
                  wikiLabel: wiki,
                  pageLabel: 'Page',
                  itemLabel: 'Item',
                  onSelect: picked.add,
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      return picked;
    }

    testWidgets('has a place to type, with what it is for, and shows nothing until something is typed', (tester) async {
      await show(tester);
      expect(find.text('Search items and pages'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('opens what it found under it as something is typed, the items, the pages and the wiki', (tester) async {
      await show(tester);
      await tester.enterText(find.byType(TextField), 'great');
      await tester.pumpAndSettle();
      expect(find.text('Greatsword of Fire'), findsOneWidget);
      expect(find.text('Great Mace'), findsOneWidget);
      expect(find.text('Search the wiki for “great”'), findsOneWidget);
      expect(find.text('Item'), findsWidgets, reason: 'under an item it says it is one');
      expect(find.text('Dagger'), findsNothing);
    });

    testWidgets('goes to what is tapped, and is empty again', (tester) async {
      final picked = await show(tester);
      await tester.enterText(find.byType(TextField), 'dagger');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dagger'));
      await tester.pumpAndSettle();
      expect(picked.single.kind, SearchKind.item);
      expect(picked.single.itemId, 5);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
      expect(find.byType(ListTile), findsNothing, reason: 'the results are shut');
    });

    testWidgets('goes to a page, and to the wiki with what was typed', (tester) async {
      final picked = await show(tester);
      await tester.enterText(find.byType(TextField), 'S-wik');
      await tester.pumpAndSettle();
      await tester.tap(find.text('S-wiki'));
      await tester.pumpAndSettle();
      expect(picked.single.section, AppSection.wiki);
      await tester.enterText(find.byType(TextField), 'gree');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search the wiki for “gree”'));
      await tester.pumpAndSettle();
      expect(picked.last.kind, SearchKind.wiki);
      expect(picked.last.query, 'gree');
    });

    testWidgets('is chosen from with the keys: down to the first, enter to go to it', (tester) async {
      final picked = await show(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'dagger');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(picked.single.itemId, 5, reason: 'the first of what was found is the one that is chosen');
    });
  });
}
