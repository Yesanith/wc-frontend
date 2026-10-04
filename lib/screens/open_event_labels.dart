import '../l10n/strings.dart';

/// 90 min, 2 h, 2 h 30 min
String openEventDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String openEventLanguageName(S s, String code) {
  if (code == 'any') return s.t('oe_any_language');
  for (final l in AppLang.values) {
    if (l.code == code) return l.nativeName;
  }
  return code;
}
