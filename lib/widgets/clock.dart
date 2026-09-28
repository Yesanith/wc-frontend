import 'dart:async';

import 'package:flutter/widgets.dart';

enum ClockStep { second, minute }

/// rebuilds [builder] with the current time in utc, once a second or once a
/// minute, on the tick. each countdown owns its timer, and the timer stops
/// while the widget sits in a hidden section of the menu (TickerMode off),
/// so pages nobody looks at do not keep rebuilding in the background
class ClockBuilder extends StatefulWidget {
  const ClockBuilder({super.key, this.step = ClockStep.second, required this.builder});

  final ClockStep step;
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<ClockBuilder> createState() => _ClockBuilderState();
}

/// [t] cut down to the start of its second or minute
DateTime clockFloor(DateTime t, ClockStep step) => step == ClockStep.second
    ? t.copyWith(millisecond: 0, microsecond: 0)
    : t.copyWith(second: 0, millisecond: 0, microsecond: 0);

/// how long until the next second or minute begins
Duration untilNextTick(DateTime t, ClockStep step) {
  final floor = clockFloor(t, step);
  final next = floor.add(step == ClockStep.second ? const Duration(seconds: 1) : const Duration(minutes: 1));
  return next.difference(t);
}

class _ClockBuilderState extends State<ClockBuilder> {
  Timer? _timer;
  late DateTime _now = clockFloor(DateTime.now().toUtc(), widget.step);
  bool _running = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _running) return;
    _running = visible;
    if (visible) {
      // coming back into view: catch up at once, then follow the ticks
      _now = clockFloor(DateTime.now().toUtc(), widget.step);
      _schedule();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void didUpdateWidget(ClockBuilder old) {
    super.didUpdateWidget(old);
    if (old.step != widget.step && _running) {
      _timer?.cancel();
      _schedule();
    }
  }

  void _schedule() {
    final at = DateTime.now().toUtc();
    _timer = Timer(untilNextTick(at, widget.step), () {
      if (!mounted || !_running) return;
      setState(() => _now = clockFloor(DateTime.now().toUtc(), widget.step));
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
