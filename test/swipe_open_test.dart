import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/widgets/swipe_open.dart';

void main() {
  Future<List<int>> pump(WidgetTester tester) async {
    final opened = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: SwipeToOpen(
        onOpen: () => opened.add(1),
        child: Column(
          children: [
            const SizedBox(height: 200, width: 400, child: Center(child: Text('page'))),
            SizedBox(
              height: 60,
              child: ListView(
                key: const Key('row'),
                scrollDirection: Axis.horizontal,
                children: [for (var i = 0; i < 30; i++) SizedBox(width: 80, child: Text('$i'))],
              ),
            ),
          ],
        ),
      ),
    ));
    return opened;
  }

  testWidgets('a swipe to the right on the page opens the menu', (tester) async {
    final opened = await pump(tester);
    await tester.drag(find.text('page'), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(opened, [1]);
  });

  testWidgets('a swipe to the left, or a short one, does nothing', (tester) async {
    final opened = await pump(tester);
    await tester.drag(find.text('page'), const Offset(-150, 0));
    await tester.pumpAndSettle();
    await tester.timedDrag(find.text('page'), const Offset(30, 0), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets('a row that scrolls sideways keeps its drag', (tester) async {
    final opened = await pump(tester);
    await tester.drag(find.byKey(const Key('row')), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('row')), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets('switched off, a page that pans in every direction keeps sideways drags', (tester) async {
    final opened = <int>[];
    var panned = 0.0;
    await tester.pumpWidget(MaterialApp(
      home: SwipeToOpen(
        enabled: false,
        onOpen: () => opened.add(1),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleUpdate: (d) => panned += d.focalPointDelta.dx,
          child: const SizedBox.expand(),
        ),
      ),
    ));
    await tester.dragFrom(const Offset(100, 300), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(panned, greaterThan(100));
  });
}
