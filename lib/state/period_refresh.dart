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
    final at = nextRefreshAt(now);
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

/// when to read the data that resets again: a few seconds after the next reset, and again a few and ten minutes after it,
/// since the api often still gives the previous day's for a while
DateTime nextRefreshAt(DateTime now) {
  final n = now.toUtc();
  const after = [Duration(seconds: 20), Duration(minutes: 3), Duration(minutes: 10)];
  final last = [lastDailyReset(n), lastWeeklyReset(n)];
  final candidates = [
    for (final reset in last)
      for (final d in after) reset.add(d),
    nextResetAfter(n).add(after.first),
  ].where((t) => t.isAfter(n)).toList()
    ..sort();
  return candidates.first;
}

final periodRefreshProvider = NotifierProvider<PeriodRefresh, int>(PeriodRefresh.new);
