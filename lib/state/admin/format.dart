part of '../admin.dart';

/// the limits of the free plan this backend runs on, so the usage can be told as a share of them. the plan
/// is chosen on the Supabase dashboard, which shows the rest (traffic, storage, function calls)
const freeDatabaseBytes = 500 * 1024 * 1024;
const freeMonthlyUsers = 50000;

enum HealthLevel { good, warn, bad }

/// how full something is: a good way to go while it is under 70 percent, a warning to 90, an alarm from there
HealthLevel levelOfUse(double fraction) =>
    fraction >= 0.9 ? HealthLevel.bad : (fraction >= 0.7 ? HealthLevel.warn : HealthLevel.good);

/// 3 d 4 h, 5 h 20 min, 12 min
String uptime(DateTime since, DateTime now) {
  final d = now.difference(since);
  if (d.inDays > 0) return '${d.inDays} d ${d.inHours % 24} h';
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  return '${d.inMinutes} min';
}

/// one thing to keep an eye on, and whether it is all right
class HealthLine {
  const HealthLine(this.label, this.detail, this.level);

  final String label;
  final String detail;
  final HealthLevel level;
}

/// 3 minutes ago, 5 h ago, 2 d ago
String ago(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// what the code a feed recorded for its last failure means, for whoever has to put it right. a code that is not known is shown as it is
String feedProblemText(String code) => switch (code) {
      'missing_permissions' =>
        'the bot may not post in the channel of this feed: it needs View Channel, Send Messages and Embed Links there (missing_permissions)',
      'channel_gone' => 'the channel of this feed is gone, or the bot cannot see it (channel_gone)',
      'rate_limited' => 'Discord is limiting how fast the bot may post (rate_limited)',
      'source_unreachable' => 'the source of the feed, the game site or its API, did not answer (source_unreachable)',
      'roles_failed' => 'the bot could not change the roles (roles_failed)',
      'threads_failed' => 'the bot could not make or write in the thread (threads_failed)',
      'events_failed' => 'the bot could not make the Discord event (events_failed)',
      _ => code,
    };

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0 ? '$bytes B' : '${value.toStringAsFixed(1)} ${units[unit]}';
}

List<({String day, int count})> _days(dynamic v) =>
    [for (final r in _maps(v)) (day: '${r['day']}', count: asInt(r['count']))];
