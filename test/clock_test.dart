import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tyria_codex/data/metas.dart';
import 'package:tyria_codex/screens/events_screen.dart';
import 'package:tyria_codex/state/settings.dart';
import 'package:tyria_codex/widgets/clock.dart';

void main() {
  test('the next tick is at the start of the next second or minute', () {
    final t = DateTime.utc(2026, 9, 28, 10, 15, 42, 250);
    expect(untilNextTick(t, ClockStep.second), const Duration(milliseconds: 750));
    expect(untilNextTick(t, ClockStep.minute), const Duration(seconds: 17, milliseconds: 750));
    expect(clockFloor(t, ClockStep.minute), DateTime.utc(2026, 9, 28, 10, 15));
  });

  Future<List<int>> pumpClock(WidgetTester tester, ValueNotifier<bool> visible) async {
    final builds = <int>[];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, on, _) => TickerMode(
          enabled: on,
          child: ClockBuilder(builder: (context, now) {
            builds.add(now.second);
            return const SizedBox();
          }),
        ),
      ),
    ));
    return builds;
  }

  testWidgets('it rebuilds every second while visible', (tester) async {
    final visible = ValueNotifier(true);
    final builds = await pumpClock(tester, visible);
    final first = builds.length;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(builds.length - first, greaterThanOrEqualTo(2));
  });

  testWidgets('a hidden section stops its clock and catches up when shown', (tester) async {
    final visible = ValueNotifier(true);
    final builds = await pumpClock(tester, visible);
    visible.value = false;
    await tester.pump();
    final hidden = builds.length;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(builds.length, hidden, reason: 'no rebuilds while hidden');
    visible.value = true;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(builds.length, greaterThan(hidden));
  });

  testWidgets('a countdown row ticks and pins without its consumer rebuilding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final map = metaMaps.first;
    final o = Occurrence(map, map.events.first, DateTime.now().toUtc().add(const Duration(minutes: 5)));
    await tester.pumpWidget(metaRowApp(prefs, o));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

// a countdown row inside a consumer keeps working when only its clock ticks
Widget metaRowApp(SharedPreferences prefs, Occurrence o) => ProviderScope(
      overrides: [prefsProvider.overrideWithValue(prefs)],
      child: MaterialApp(home: Scaffold(body: MetaRow(occurrence: o, looted: false, pinnable: true))),
    );
