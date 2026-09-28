import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'periodic.dart';

/// the wall clock in utc, ticking once a second for the countdowns
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now().toUtc();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now().toUtc());
});

String _two(int v) => v.toString().padLeft(2, '0');

/// a countdown with its two largest units: 2d 04h, 3h 05m, 12:07
String countdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  if (d.inDays > 0) return '${d.inDays}d ${_two(d.inHours % 24)}h';
  if (d.inHours > 0) return '${d.inHours}h ${_two(d.inMinutes % 60)}m';
  return '${_two(d.inMinutes)}:${_two(d.inSeconds % 60)}';
}

/// how far through the day, from midnight utc
double dayProgress(DateTime now) {
  final u = now.toUtc();
  return (u.hour * 3600 + u.minute * 60 + u.second) / 86400;
}

/// how far through the week, from monday's reset
double weekProgress(DateTime now) {
  final left = nextWeeklyReset(now.toUtc()).difference(now.toUtc()).inSeconds;
  return 1 - left / const Duration(days: 7).inSeconds;
}
