import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tyria_codex/state/settings.dart';
import 'package:tyria_codex/widgets/ui_zoom.dart';

void main() {
  group('how much larger everything is on a wide screen', () {
    test('nothing up to 1600 pixels, so a phone and a laptop are as they were', () {
      for (final w in [360.0, 800.0, 1280.0, 1440.0, 1600.0]) {
        expect(autoZoom(w), 1.0, reason: '$w');
      }
    });

    test('half as much again on a 2K screen, and growing from there, never more than twice', () {
      expect(autoZoom(1920), closeTo(1.167, 0.001));
      expect(autoZoom(2560), closeTo(1.5, 0.001));
      expect(autoZoom(3440), closeTo(1.96, 0.01), reason: 'an ultrawide');
      expect(autoZoom(3840), 2.0, reason: 'a 4K screen at its own size');
      expect(autoZoom(7680), 2.0);
    });

    test('a size that was chosen is used, and the automatic one when none was', () {
      expect(uiZoomFor(2560, null), closeTo(1.5, 0.001));
      expect(uiZoomFor(2560, 1.0), 1.0);
      expect(uiZoomFor(2560, 1.75), 1.75);
    });

    test('never so much that a window is left with less than 360 pixels to lay out in', () {
      expect(uiZoomFor(500, 2.0), closeTo(500 / 360, 0.001));
      expect(uiZoomFor(360, 2.0), 1.0);
      expect(uiZoomFor(300, 2.0), 1.0, reason: 'and never smaller than it is');
    });
  });

  group('the size that was chosen', () {
    test('is read back, anything that is not one of the sizes is automatic', () {
      expect(parseUiScale('1.5'), 1.5);
      expect(parseUiScale('2.0'), 2.0);
      expect(parseUiScale('auto'), isNull);
      expect(parseUiScale(null), isNull);
      expect(parseUiScale('3.0'), isNull);
      expect(parseUiScale('0.5'), isNull);
      expect(parseUiScale('big'), isNull);
    });

    test('every size on offer is one that is read back', () {
      for (final size in uiScaleChoices) {
        expect(parseUiScale(size == null ? 'auto' : '$size'), size);
      }
    });
  });

  group('the zoom as a widget', () {
    Future<void> screen(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('lays the interface out as a smaller screen and fills the real one', (tester) async {
      await screen(tester, const Size(2400, 1200));
      Size? seen;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => UiZoom(scale: 1.5, child: child!),
        home: Builder(builder: (context) {
          seen = MediaQuery.sizeOf(context);
          return const Scaffold(body: Center(child: Text('middle')));
        }),
      ));
      expect(seen, const Size(1600, 800));
      // what is in the middle of the smaller screen is in the middle of the real one
      expect(tester.getCenter(find.text('middle')).dx, closeTo(1200, 1));
      expect(tester.getCenter(find.text('middle')).dy, closeTo(600, 1));
      // and it is drawn that much larger
      expect(tester.getBottomRight(find.byType(Scaffold)).dx, closeTo(2400, 1));
      expect(tester.getSize(find.byType(Scaffold)).width, 1600, reason: 'laid out as the smaller screen');
    });

    testWidgets('a press lands on what is under the pointer, and a size of 1 changes nothing', (tester) async {
      await screen(tester, const Size(2400, 1200));
      var pressed = 0;
      Widget app(double scale) => MaterialApp(
            builder: (context, child) => UiZoom(scale: scale, child: child!),
            home: Scaffold(body: Center(child: ElevatedButton(onPressed: () => pressed++, child: const Text('go')))),
          );
      await tester.pumpWidget(app(1.5));
      await tester.tapAt(tester.getCenter(find.text('go')));
      await tester.pump();
      expect(pressed, 1);
      // a corner of the screen is not the button
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(pressed, 1);
      // what is on the screen, not what it was laid out as
      double drawn(Finder f) => tester.getBottomRight(f).dx - tester.getTopLeft(f).dx;
      await tester.pumpWidget(app(1.0));
      final plain = drawn(find.byType(ElevatedButton));
      await tester.pumpWidget(app(1.5));
      final larger = drawn(find.byType(ElevatedButton));
      expect(larger, closeTo(plain * 1.5, 1), reason: 'the button is that much larger');
    });
  });
}
