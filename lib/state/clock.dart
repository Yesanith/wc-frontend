import '../l10n/strings.dart';
import 'periodic.dart';
import '../util.dart';

/// a countdown with its two largest units: 2d 04h, 3h 05m, 12:07
String countdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  if (d.inDays > 0) return '${d.inDays}d ${pad2(d.inHours % 24)}h';
  if (d.inHours > 0) return '${d.inHours}h ${pad2(d.inMinutes % 60)}m';
  return '${pad2(d.inMinutes)}:${pad2(d.inSeconds % 60)}';
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

/// the next time a character's creation date comes round, which is when the
/// game hands out the birthday gift
DateTime nextBirthday(DateTime created, DateTime now) {
  final c = created.toUtc();
  final u = now.toUtc();
  var next = DateTime.utc(u.year, c.month, c.day, c.hour, c.minute);
  if (!next.isAfter(u)) next = DateTime.utc(u.year + 1, c.month, c.day, c.hour, c.minute);
  return next;
}

/// full years since the character was made
int yearsSince(DateTime created, DateTime now) {
  final c = created.toUtc();
  final u = now.toUtc();
  var years = u.year - c.year;
  if (u.month < c.month || (u.month == c.month && u.day < c.day)) years--;
  return years < 0 ? 0 : years;
}

String _name(S s, String key, int index) {
  final names = s.t(key).split(',');
  return index >= 0 && index < names.length ? names[index].trim() : '';
}

/// a date in words in the language of the app, "Friday, November 13, 2026" or "13 Kasım 2026 Cuma": the names of the days
/// and of the months and the order of the parts are strings of each language, the system's own would be English
String fullDateText(S s, DateTime d) => s.t('date_full', {
      'wd': _name(s, 'weekdays', d.weekday - 1),
      'd': d.day,
      'm': _name(s, 'months', d.month - 1),
      'y': d.year,
    });

/// the same without the day of the week
String shortDateText(S s, DateTime d) => s.t('date_short', {
      'd': d.day,
      'm': _name(s, 'months', d.month - 1),
      'y': d.year,
    });
