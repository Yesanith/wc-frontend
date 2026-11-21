import '../l10n/strings.dart';

/// 90 min, 2 h, 2 h 30 min
/// how long an event lasts, in the words of the app's language: 45 dk, 2 sa, 1 sa 30 dk
String openEventDuration(S s, int minutes) {
  if (minutes < 60) return s.t('minutes_short', {'n': minutes});
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final hours = '$h ${s.t('hours_short')}';
  return m == 0 ? hours : '$hours ${s.t('minutes_short', {'n': m})}';
}

String openEventLanguageName(S s, String code) {
  if (code == 'any') return s.t('oe_any_language');
  for (final l in AppLang.values) {
    if (l.code == code) return l.nativeName;
  }
  return code;
}
