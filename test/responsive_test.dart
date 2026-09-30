import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/widgets/responsive.dart';

/// counts how many times it is made, to see a page that was started over
class _Probe extends StatefulWidget {
  const _Probe();

  static var made = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.made++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand(key: Key('page'));
}

Widget _frame({double maxWidth = contentMaxWidth}) => Directionality(
      textDirection: TextDirection.ltr,
      child: ContentFrame(maxWidth: maxWidth, child: const _Probe()),
    );

void main() {
  group('the menu that stays open', () {
    test('is for a computer and a tablet held sideways', () {
      expect(useSideMenu(const Size(1920, 1080)), isTrue);
      expect(useSideMenu(const Size(1280, 800)), isTrue, reason: 'a tablet held sideways');
      expect(useSideMenu(const Size(1024, 768)), isTrue, reason: 'a small window');
      expect(useSideMenu(const Size(900, 480)), isTrue, reason: 'the limits themselves');
    });

    test('is not for a phone, held sideways or not, nor for a tablet held upright', () {
      expect(useSideMenu(const Size(393, 851)), isFalse);
      expect(useSideMenu(const Size(851, 393)), isFalse, reason: 'a phone held sideways is too low');
      expect(useSideMenu(const Size(800, 1280)), isFalse, reason: 'a tablet held upright');
      expect(useSideMenu(const Size(899, 900)), isFalse);
      expect(useSideMenu(const Size(1280, 479)), isFalse);
    });
  });

  group('a page kept to a width', () {
    testWidgets('sits in the middle of a window wider than its limit, as tall as the window', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_frame());
      final page = tester.getRect(find.byKey(const Key('page')));
      expect(page.width, contentMaxWidth);
      expect(page.height, 900);
      expect(page.center.dx, 800);
      expect(page.top, 0);
    });

    testWidgets('gets the whole window while it is narrower, exactly as it would without the frame', (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_frame());
      final page = tester.getRect(find.byKey(const Key('page')));
      expect(page, const Rect.fromLTWH(0, 0, 700, 900));
    });

    testWidgets('has no limit when it is given none, like the map', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_frame(maxWidth: double.infinity));
      expect(tester.getRect(find.byKey(const Key('page'))).width, 1600);
    });

    testWidgets('is not started over when the window is resized past the limit', (tester) async {
      _Probe.made = 0;
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(700, 900));
      await tester.pumpWidget(_frame());
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      await tester.pump();
      expect(tester.getRect(find.byKey(const Key('page'))).width, contentMaxWidth);
      await tester.binding.setSurfaceSize(const Size(500, 900));
      await tester.pump();
      expect(tester.getRect(find.byKey(const Key('page'))).width, 500);
      expect(_Probe.made, 1, reason: 'one page, kept while the window changed');
    });
  });

  group('a grid that gets more columns instead of bigger tiles', () {
    test('keeps what a phone always had', () {
      // eight item slots across a phone, three currencies, two cards
      expect(adaptiveColumns(328, minColumns: 8, maxTile: 60, spacing: 6), 8);
      expect(adaptiveColumns(360, minColumns: 8, maxTile: 60, spacing: 6), 8);
      expect(adaptiveColumns(328, minColumns: 3, maxTile: 150, spacing: 8), 3);
      expect(adaptiveColumns(328, minColumns: 2, maxTile: 330, spacing: 8), 2);
    });

    test('has more where there is room, and no tile wider than the limit', () {
      final columns = adaptiveColumns(1460, minColumns: 8, maxTile: 60, spacing: 6);
      expect(columns, greaterThan(8));
      expect((1460 - 6 * (columns - 1)) / columns, lessThanOrEqualTo(60));
      expect(adaptiveColumns(1100, minColumns: 2, maxTile: 330, spacing: 8), 4);
    });

    testWidgets('lays the tiles out that way', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<List<double>> widths(double window) async {
        await tester.binding.setSurfaceSize(Size(window, 800));
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: GridView(
            gridDelegate: const AdaptiveGridDelegate(minColumns: 3, maxTile: 120),
            children: [for (var i = 0; i < 30; i++) SizedBox(key: Key('t$i'))],
          ),
        ));
        return [for (var i = 0; i < 30; i++) tester.getSize(find.byKey(Key('t$i'))).width];
      }

      final narrow = await widths(300);
      expect(narrow.toSet(), {100.0}, reason: 'three across, as before');
      final wide = await widths(1200);
      expect(wide.toSet(), {120.0}, reason: 'ten across, the size of a tile kept');
    });
  });

  group('the parts of a page in columns', () {
    Widget page(List<Widget> primary, List<Widget> secondary) => Directionality(
          textDirection: TextDirection.ltr,
          child: SingleChildScrollView(child: SplitColumns(primary: primary, secondary: secondary)),
        );
    const a = SizedBox(key: Key('a'), height: 50);
    const b = SizedBox(key: Key('b'), height: 50);

    testWidgets('stand one under the other while narrow, in the order given', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(600, 800));
      await tester.pumpWidget(page([a], [b]));
      expect(tester.getTopLeft(find.byKey(const Key('a'))).dx, tester.getTopLeft(find.byKey(const Key('b'))).dx);
      expect(tester.getTopLeft(find.byKey(const Key('a'))).dy, lessThan(tester.getTopLeft(find.byKey(const Key('b'))).dy));
      expect(tester.getSize(find.byKey(const Key('a'))).width, 600);
    });

    testWidgets('stand side by side when there is room, the first wider', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(page([a], [b]));
      final left = tester.getRect(find.byKey(const Key('a')));
      final right = tester.getRect(find.byKey(const Key('b')));
      expect(left.top, right.top);
      expect(left.right, lessThan(right.left));
      expect(left.width, greaterThan(right.width));
      // 3 to 2, and a gap between them
      expect(left.width / right.width, closeTo(1.5, 0.01));
    });

    testWidgets('give the whole width to the first when the second has nothing', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(page([a], const []));
      expect(tester.getSize(find.byKey(const Key('a'))).width, 1200);
    });
  });
}
