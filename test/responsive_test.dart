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
}
