import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util.dart';

/// ticks at every daily and weekly reset, and when the app comes back after a
/// while in the background. providers of data that resets (the wizard's
/// vault, daily crafts, raids) watch it and fetch again, so a screen left
/// open across a reset does not keep showing the previous day
class PeriodRefresh extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    _schedule();
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now().toUtc();
    // a few seconds late, so the api has moved on as well
    final at = nextResetAfter(now).add(const Duration(seconds: 20));
    _timer = Timer(at.difference(now), () {
      state++;
      _schedule();
    });
  }

  /// the app is back in the foreground
  void resumed() {
    _schedule();
    state++;
  }
}

final periodRefreshProvider = NotifierProvider<PeriodRefresh, int>(PeriodRefresh.new);
